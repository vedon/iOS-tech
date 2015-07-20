
编译就是把高级语言变成计算机可以识别的二进制语言，利用编译程序从源语言编写的源程序产生目标程序的过程。
汇编大多是指汇编语言，汇编程序。把汇编语言翻译成机器语言的过程称为汇编。在汇编语言中，用助记符(Memoni)代替操作码，用地址符号(Symbol)或标号(Label)代替地址码。这样用符号代替机器语言的二进制码，就把机器语言变成了汇编语言。于是汇编语言亦称为符号语言。用汇编语言编写的程序，机器不能直接识别，要由一种程序将汇编语言翻译成机器语言，这种起翻译作用的程序叫汇编程序，汇编程序是系统软件中语言处理的系统软件。



#解析WebCore Mach-O 文件中的汇编代码
基于ARM64 和 ARMV7S 来解析汇编代码。


##ARM64
```
000000018f74ebe8	stp	x20, x19, [sp, #-32]!
000000018f74ebec	stp	x29, x30, [sp, #16]
000000018f74ebf0	add	x29, sp, #16
000000018f74ebf4	adrp	x19, 27226 ; 0x18f755000
000000018f74ebf8	add	x19, x19, #4000
000000018f74ebfc	ldrb	 w8, [x19]
000000018f74ec00	cmp	 w8, #1
000000018f74ec04	b.ne	0x18f74ec10
000000018f74ec08	ldr	x0, [x19, #8]
000000018f74ec0c	b	0x18f74ec30

```


```
关键的代码为：
000000018f74ebf4	adrp	x19, 27226 ; 0x18f755000
000000018f74ebf8	add	x19, x19, #4000
000000018f74ec08	ldr	x0, [x19, #8]

```

1. adrp x19, 27226。其中adrp  xd, label， 意味着   xd = (label << 12 + pc)& ~0xfff ， 而运算时 pc 值为当前代码执行地址（例子中为0x18f756e2c)。 
2. add      x19, x19, #352。 其中add  xd, xd, #num， 意味着   xd = xd + num
3. ldr x0, [x19, #8]。 即 x0 = x19 + 8， 而 x0 就是  WebCore::pageCache() 的返回值了。

于是 x0 =  (((27226 << 12) + pc )& ~0xfff) + 352 + 8


**在ARM64实际运行中，得到的汇编代码是**

```
Address: 195246be8 	 stp       	x20, x19, [sp, #-0x20]!
Address: 195246bec 	 stp       	x29, x30, [sp, #0x10]
Address: 195246bf0 	 add       	x29, sp, #0x10
Address: 195246bf4 	 adrp      	x19, #0x19bca0000
Address: 195246bf8 	 add       	x19, x19, #0xfa0
Address: 195246bfc 	 ldrb      	w8, [x19]
Address: 195246c00 	 cmp       	w8, #1

```

这个时候，我们发现：

在Mach-O 没有加载到内存时候与加载到内存时这，下面这句汇编代码是不一样的，这里需要做一些简单的运算

0x18f74ebf4	 adrp			x19, 27226 ; 0x18f755000


0x195246bf4 	 adrp      	x19, #0x19bca0000


**(0x195246bf4 + (27226 << 12)) & -4096 = 0x19bca0000 ;**

**(0x19bca0000 - (0x195246bf4 & -4096)) >> 12 = 27226;**

x0 =  ((((0x19bca0000 - (0x195246bf4 & -4096))) + 0x195246bf4)& ~0xfff) + 4000 + 8;

即

x0 =  0x19bca0000 + 4000 + 8;
##ARMV7S
```
2cc79dc4	    b590	push	{r4, r7, lr}
2cc79dc6	f24f6484	movw	r4, #0xf684
2cc79dca	    af01	add	r7, sp, #0x4
2cc79dcc	f2c044bc	movt	r4, #0x4bc
2cc79dd0	    447c	add	r4, pc
2cc79dd2	    7820	ldrb	r0, [r4]
2cc79dd4	    2801	cmp	r0, #0x1
2cc79dd6	    d106	bne	0x2cc79de6
2cc79dd8	f24f6070	movw	r0, #0xf670
2cc79ddc	f2c040bc	movt	r0, #0x4bc
2cc79de0	    4478	add	r0, pc
2cc79de2	    6800	ldr	r0, [r0]
2cc79de4	    bd90	pop	{r4, r7, pc}
2cc79de6	    2014	movs	r0, #0x14
2cc79de8	f257c8d8	blx	0x2d6d0f9c @ symbol stub for: __ZN13TParseContext16lValueErrorCheckERK10TSourceLocPKcP12TIntermTyped
2cc79dec	f24f6156	movw	r1, #0xf656
2cc79df0	efc00050	vmov.i32	q8, #0x0
2cc79df4	f2c041bc	movt	r1, #0x4bc
2cc79df8	    2200	movs	r2, #0x0
2cc79dfa	    4479	add	r1, pc
```
```
关键的代码为：
2cc79dd8    f24f6070    movw    r0, #0xf670
2cc79ddc    f2c040bc    movt    r0, #0x4bc
2cc79de0        4478    add r0, pc
2cc79de2        6800    ldr r0, [r0]

```
pc 当前的地址为 2cc79de0

r0 = (#0x4bc << 16)|(#0xf670) = 0x4bcf670

r0 = r0 + pc = 0x31849450;


##指令常识
> * STP Xt1, Xt2, addr
Store Pair Registers (extended): stores two doublewords from Xt1 and Xt2 to memory addressed by
addr.

> * ADRP Xd, label
符号扩展一个21位的offset, 向左移动12位,PC的值的低12位 清零， 然后  把 这两者相加， 结果写入到Xd寄存器

> * LDRB Wt, addr
LDRB指令用于从存储器中将一个8位的字节数据传送到目的寄存器中，同时将寄存器的高24位清零

> * cmp r0, #0
> > CMP{条件} 操作数1，操作数2
CMP指令用于把一个寄存器的内容和另一个寄存器的内容或立即数进行比较，同时更新CPSR中条件标志位的值。该指令进行一次减法运算，但不存储结果，只更改条件标志位。标志位表示的是操作数1与操作数2的关系(大、小、相等)，例如，当操作数1大于操作操作数2，则此后的有GT 后缀的指令将可以执行。
指令示例：
CMP R1，R0 ；将寄存器R1的值与寄存器R0的值相减，并根据结果设置CPSR的标志位
CMP R1，＃100 ；将寄存器R1的值与立即数100相减，并根据结果设置CPSR的标志位


> * 一旦遇到一个 B 指令，ARM 处理器将立即跳转到给定的目标地址，从那里继续执行。注意存储在跳转指令中的实际值是相对当前PC 值的一个偏移量，而不是一个绝对地址，它的值由汇编器来计算（参考寻址方式中的相对寻址）。它是 24 位有符号数，左移两位后有符号扩展为 32 位，表示的有效偏移为 26 位(前后32MB 的地址空间)
> 

> *  PUSH
Push Multiple Registers stores a subset (or possibly all) of the general-purpose registers R0-R12 and the LR
to the stack.

> * MOVW可以把一个16-bit常数加载到寄存器中，并用0填充高比特位；另一条指令MOVT可以把一个16-bit常数加载到寄存器高16比特中。例如：movw	r0, #0xf670 和movt	r0, #0x4bc ,实际上是 r0 = (#0x4bc << 16)|(#0xf670) = 0x4bcf670.

> * str r0, [sp, #8]的作用是：将寄存器r0中的内容存储到栈指针(加8)指向的内存地址.

> * ldr r0, [sp, #8]的作用是“将栈指针加8后指向的地址内容加载到r0寄存器中”。

> * add指令可以是两个参数,也可以是三个参数.如果指定三个参数,那么第一个参数就被当做目标寄存器,剩下的两个则为源寄存器.因此,这里的指令可以写成这样:add r0, r0, r1。

> * 执行bx指令会回到调用函数的地方.这里的寄存器lr是链接寄存器(link register)，该存储器存储着将要执行的下一条指令

> * pc 程序计数器

> * LR 链接寄存器

> * SP 堆栈指针

> * r0到r15。每个寄存器为32bit（arm64 r0 ~ r30寄存器有两种使用模式，64位时称为x0 ~ x30，32位时称为w0 ~ w30。）。调用约定规定了这些寄存器的特定用途。如下：
> > * r0 – r3：存储传递给函数的参数值。
> > * r4 – r11：存储函数的局部变量。
> > * r12：是内部过程调用暂时寄存器（intra-procedure-call scratch register）。
> > * r13：存储栈指针(sp)。在计算机中，栈非常重要。这个寄存器保存着栈顶的指针。这里可以看到更多关于栈的信息：Wikipedia。
> > * r14：链接寄存器(link register)。存储着当被调用函数返回时，将要执行的下一条指令的地址。
> > * r15：用作程序计数器(program counter)。存储着当前执行指令的地址。每条执行被执行后，该计数器会进行自增(+1)。

寻址方式：
> * 立即数寻址
> * 寄存器寻址
> * 寄存器间接寻址
> * 基址寻址
> * 寄存器移位寻址
> * 堆栈寻址
> * 多寄存器寻址
> * 块拷贝寻址
> * 相对寻址

[查看更多](http://lli_njupt.0fees.net/ar01s03.html)




参考链接：
https://www.element14.com/community/servlet/JiveServlet/previewBody/41836-102-1-229511/ARM.Reference_Manual.pdf

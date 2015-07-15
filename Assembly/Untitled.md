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
> * STP Xt1, Xt2, addr
Store Pair Registers (extended): stores two doublewords from Xt1 and Xt2 to memory addressed by
addr.

> * ADRP Xd, label
符号扩展一个21位的offset, 向左移动12位,PC的值的低12位 清零， 然后  把 这两者相加， 结果写入到Xd寄存器

> * LDRB Wt, addr
LDRB指令用于从存储器中将一个8位的字节数据传送到目的寄存器中，同时将寄存器的高24位清零

> * cmp r0, #0
status = ro - 0
beq 1f ; 如果r0==0那么向前跳转到B处执行
bne 1b 

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

```
__ZN7WebCore9pageCacheEv:
000000018f756e20 stp x20, x19, [sp, #-32]!
000000018f756e24 stp fp, lr, [sp, #16]
000000018f756e28 add fp, sp, #16
000000018f756e2c adrp x19, 27226 ; 0x18f75d000
000000018f756e30 add x19, x19, #352
000000018f756e34 ldrb w8, [x19]
000000018f756e38 cmp w8, #1
000000018f756e3c b.ne 0x18f756e48
000000018f756e40 ldr x0, [x19, #8]
 
关键的代码为：
000000018f756e2c adrp x19, 27226 ; 0x18f75d000
000000018f756e30 add x19, x19, #352
000000018f756e40 ldr x0, [x19, #8]

```
1. adrp x19, 27226。其中adrp  xd, label， 意味着   xd = (label << 12 + pc)& ~0xfff ， 而运算时 pc 值为当前代码执行地址（例子中为0x18f756e2c)。 
2. add      x19, x19, #352。 其中add  xd, xd, #num， 意味着   xd = xd + num
3. ldr x0, [x19, #8]。 即 x0 = x19 + 8， 而 x0 就是  WebCore::pageCache() 的返回值了。

于是 x0 =  (((27226 << 12) + pc )& ~0xfff) + 352 + 8

参考链接：
https://www.element14.com/community/servlet/JiveServlet/previewBody/41836-102-1-229511/ARM.Reference_Manual.pdf

#Mach-O

[Mach-O](https://zh.wikipedia.org/wiki/Mach-O)为Mach Object文件格式的缩写，它是一种用于可执行文件，目标代码，动态库，内核转储的文件格式。作为a.out格式的替代，Mach-O提供了更强的扩展性，并提升了符号表中信息的访问速度。

##Mach-O 文件结构
[![](./mach_o_segments.gif)](http://www.cilinder.be/docs/next/NeXTStep/3.3/nd/DevTools/14_MachO/MachO.htmld/index.html)



![](./Screen Shot 2015-07-09 at 2.28.52 PM.png)

> * __TEXT segment 包含了被执行的代码。它被以只读和可执行的方式映射
> * __DATA segment 以可读写和不可执行的方式映射
> * __LINKEDIT 包含了动态连接器的使用的原始数据，例如：symbol table ,string table等。
> 
__DATA segment 与 __TEXT  的偏移是固定的，仅接着__TEXT 数据之后。

详情可查看[Mach-O 文件结构](https://developer.apple.com/library/mac/documentation/DeveloperTools/Conceptual/MachORuntime/index.html#//apple_ref/doc/uid/20001298-96661)。
##查看Mach-O 文件信息
查看Mach-O 文件，可以使用otool ,nm 工具。p.s 如果安装了Xcode ，就默认安装了这两个工具。
我们打开terminal ,然后cd 到/System/Library/Frameworks/AppKit.framework 目录下

> * 查看AppKit 的Mach header 信息:	
otool -h AppKit
![](./Screen Shot 2015-07-09 at 2.59.53 PM.png)
> * 查看 AppKit 的load commands信息:	
otool -l AppKit
![](./Screen Shot 2015-07-09 at 3.00.23 PM.png)
> * 查看所有动态加载的库：
otool -L AppKit
![](./Screen Shot 2015-07-09 at 3.01.55 PM.png)
> * 查看Mach-O 文件所有的符号：
nm -a AppKit
![](/Users/vedon/Documents/iOS-tech/Mach-O File/Screen Shot 2015-07-09 at 2.55.01 PM.png)
第一列是符号的地址，第二是符号的类型，第三列是符号名。在符号的类型里面，T 表示该符号在__TEXT 段，t 也表示该符号在__TEXT 段，但是对外是不可见的。U 表示该符号没定义，会在程序运行的时候在另外一个库中加载。


看这些太痛苦了，不如来点objc 的。使用[class-dump](https://github.com/nygard/class-dump),把 class-dump 拉到/usr/local/bin 目录下，这样在terminal 就可以使用了，使用class-dump 可以查看库的头文件。

> * class-dump AppKit
> ![](/Users/vedon/Documents/iOS-tech/Mach-O File/Screen Shot 2015-07-09 at 3.13.44 PM.png)
> 

不看一下汇编代码，都显示不出自己高大上，otool -tV  加Mach-O 文件，可以查看里面的汇编代码。（p.s  小心刷屏）

![](/Users/vedon/Documents/iOS-tech/Mach-O File/Screen Shot 2015-07-09 at 3.21.57 PM.png)
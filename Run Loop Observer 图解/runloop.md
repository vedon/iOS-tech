##RunLoopRun 源码解析

了解一下runloop ,对于实际的开发上是大有裨益的。[源码](https://github.com/vedon/CF/blob/master/CFRunLoop.c)在github 上都有，大家可以自行查阅。

Runloop 的主要工作流程，简单来说就是下图。
![](./Screen Shot 2015-09-22 at 11.28.41 PM.png)

在断点的堆栈里面看得最多的就是下面函数的了，它们是什么？



```
static void __CFRUNLOOP_IS_CALLING_OUT_TO_AN_OBSERVER_CALLBACK_FUNCTION__();
static void __CFRUNLOOP_IS_CALLING_OUT_TO_A_BLOCK__();
static void __CFRUNLOOP_IS_SERVICING_THE_MAIN_DISPATCH_QUEUE__();
static void __CFRUNLOOP_IS_CALLING_OUT_TO_A_TIMER_CALLBACK_FUNCTION__();
static void __CFRUNLOOP_IS_CALLING_OUT_TO_A_SOURCE0_PERFORM_FUNCTION__();
static void __CFRUNLOOP_IS_CALLING_OUT_TO_A_SOURCE1_PERFORM_FUNCTION__();

```

***

####首先看第一个函数,它让外部观察Runloop 的运行状态成为可能，[你可以注册一个observer ，通过它观察runloop 的行为](#jump)。

```
static void __CFRUNLOOP_IS_CALLING_OUT_TO_AN_OBSERVER_CALLBACK_FUNCTION__(
    CFRunLoopObserverCallBack func,
    CFRunLoopObserverRef observer,
    CFRunLoopActivity activity,
    void *info);

```

CoreAnimation就有这么一个观察者，下面的堆栈是从Instruments 里面看到的。当一个UIView 的DrawRect被调用时，在网上查了一下相关的资料，可以确定的是这个UIView 就被标记为待处理，并被提交到一个全局的容器去。当Oberver监听的事件到来时，回调执行函数中会遍历所有待处理的UIView/CAlayer 以执行实际的绘制和调整，并更新 UI 界面。

![](./1.png)

```
CA::Transaction::observer_callback(__CFRunLoopObserver*, unsigned long, void*) ()
CA::Transaction::commit() ()
CA::Context::commit_transaction(CA::Transaction*) ()
CA::Layer::layout_and_display_if_needed();
CA::Layer::layout_if_needed();
[CALayer layoutSublayers];
[UIView layoutSubviews];
CA::Layer::display_if_needed();
[CALayer display];
[UIView drawRect];
```

除此之外，autoreleasePool 也是通过观察者的方式来实现的。

```
1,即将进入runloop 的时候，push 一个pool，此时观察者的优先级是最高的，保证在其他回调前创建好pool.

2,准备进入睡眠的时候 pop 一个pool。此时观察者的优先级是最低的，保证在所有回调结束之后执行。

```

**ps: 可以下载源码编译一下，打断点，你会有求知若渴的感觉！**

***

####CFRunLoopPerformBlock()  就是我们平时说的，hey,麻烦在下一个runloop 执行block,thx.

```
static void __CFRUNLOOP_IS_CALLING_OUT_TO_A_BLOCK__(
        void (^block)(void));

```

***

####GCD中dispatch到main queue的block会被dispatch到main loop执行。GCD  会创建多个没有runloop的线程，当任务执行完的时候，把上下文切换到主线程，继续执行？（FixMe）

```
static void __CFRUNLOOP_IS_SERVICING_THE_MAIN_DISPATCH_QUEUE__(
    void *msg); 
```
***

####NSObject PerformSelector:AfterDelay: ,NSTimer 会通过这个函数回调。

```
static void __CFRUNLOOP_IS_CALLING_OUT_TO_A_TIMER_CALLBACK_FUNCTION__(
    CFRunLoopTimerCallBack func,
    CFRunLoopTimerRef timer,
    void *info);
```

***

####Source0 处理App 内部事件，e.g. 以下的方法就回创建一个Source 0 事件。

```
- (void)performSelector:(SEL)aSelector
               onThread:(NSThread *)thr
             withObject:(id)arg
          waitUntilDone:(BOOL)wait
                  modes:(NSArray *)array;
``` 

```
static void __CFRUNLOOP_IS_CALLING_OUT_TO_A_SOURCE0_PERFORM_FUNCTION__(
    void (*perform)(void *),
    void *info);
```

***
####Source1 处理内核事件。 e.g. NSMach port（通过内核和其他线程通信，接收、分发系统事件）

```
static void __CFRUNLOOP_IS_CALLING_OUT_TO_A_SOURCE1_PERFORM_FUNCTION__(
    void *(*perform)(void *msg, CFIndex size, CFAllocatorRef allocator, void *info),
    mach_msg_header_t *msg, CFIndex size, mach_msg_header_t **reply,
    void (*perform)(void *),
    void *info);
```


除了__CFRUNLOOP_IS_CALLING_OUT_TO_AN_OBSERVER_CALLBACK_FUNCTION__ 观察者回调函数外，其他5 个函数，我们来看一下它们的执行顺序。？[直接看结果](#result)

```
//
//  ViewController.m
//  RunLoopAction
//
//  Created by vedon on 2/8/2016.
//  Copyright © 2016 vedon. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    /**
     *  Observer
     */
    [self createRunLoopObserverWithObserverType:kCFRunLoopEntry];
    [self createRunLoopObserverWithObserverType:kCFRunLoopBeforeTimers];
    [self createRunLoopObserverWithObserverType:kCFRunLoopBeforeSources];
    [self createRunLoopObserverWithObserverType:kCFRunLoopBeforeWaiting];
    [self createRunLoopObserverWithObserverType:kCFRunLoopAfterWaiting];
    
    
    /**
     *  Runloop block
     *
     */
    CFRunLoopRef mainRunloop = CFRunLoopGetMain();
    CFRunLoopPerformBlock(mainRunloop, kCFRunLoopCommonModes, ^{
        
        NSLog(@"__CFRUNLOOP_IS_CALLING_OUT_TO_A_BLOCK__  CFRunLoopPerformBlock");
        
    });
    
    /**
     *  Source 0 event
     *
     */
    [self performSelector:@selector(source0Event) onThread:[NSThread mainThread] withObject:nil waitUntilDone:NO];
    
    
    /**
     *  Source 1 event
     */
    [self addButtonToMainView];
    
    
    
    //Exec order : FIFO
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"__CFRUNLOOP_IS_SERVICING_THE_MAIN_DISPATCH_QUEUE__  GCD dispatch_after");
    });
    
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"__CFRUNLOOP_IS_SERVICING_THE_MAIN_DISPATCH_QUEUE__  GCD dispatch_async");
    });
    
    
    /**
     *  Timer
     */
    [NSTimer scheduledTimerWithTimeInterval:0 target:self selector:@selector(timerAction) userInfo:nil repeats:NO];
    
    
    /**
     *  Dispatch_once will be executed before the runloop run
     */
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSLog(@"dispatch_once");
    });
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)source0Event
{
    NSLog(@"__CFRUNLOOP_IS_CALLING_OUT_TO_A_SOURCE0_PERFORM_FUNCTION__  Source0");
}

- (void)timerAction
{
    NSLog(@"__CFRUNLOOP_IS_CALLING_OUT_TO_A_TIMER_CALLBACK_FUNCTION__  NSTimer");
}

- (void)addButtonToMainView
{
    UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 80, 50)];
    [button addTarget:self action:@selector(source1Event) forControlEvents:UIControlEventTouchUpInside];
    button.backgroundColor = [UIColor lightGrayColor];
    
    [self.view addSubview:button];
    
}

- (void)source1Event
{
    NSLog(@"__CFRUNLOOP_IS_CALLING_OUT_TO_A_SOURCE1_PERFORM_FUNCTION__  Source1");
}


- (void)createRunLoopObserverWithObserverType:(CFOptionFlags)flag
{
    CFRunLoopRef runLoop = CFRunLoopGetCurrent();
    CFStringRef runLoopMode = kCFRunLoopDefaultMode;
    CFRunLoopObserverRef observer = CFRunLoopObserverCreateWithHandler
    (kCFAllocatorDefault, flag, true, 0, ^(CFRunLoopObserverRef observer, CFRunLoopActivity _activity) {
        
        switch (_activity) {
            case kCFRunLoopEntry:
            {
                NSLog(@"即将进入Loop");
            }
                break;
            case kCFRunLoopBeforeTimers:
            {
                NSLog(@"即将处理 Timer");
                break;
            }
            case kCFRunLoopBeforeSources:
                NSLog(@"即将处理 Source");
                break;
            case kCFRunLoopBeforeWaiting:
                NSLog(@"即将进入休眠");
                ;
                break;
            case kCFRunLoopAfterWaiting:
                NSLog(@"刚从休眠中唤醒");
                break;
            case kCFRunLoopExit:
                NSLog(@"即将退出Loop");
                break;
            default:
                break;
        }
    });
    CFRunLoopAddObserver(runLoop, observer, runLoopMode);
}

@end

```

<span id="result">运行结果</span>

```
2016-08-02 16:36:21.129 RunLoopAction[4232:342167] dispatch_once
2016-08-02 16:36:21.140 RunLoopAction[4232:342167] 即将进入Loop
2016-08-02 16:36:21.141 RunLoopAction[4232:342167] 即将处理 Timer
2016-08-02 16:36:21.141 RunLoopAction[4232:342167] 即将处理 Source
2016-08-02 16:36:21.142 RunLoopAction[4232:342167] __CFRUNLOOP_IS_CALLING_OUT_TO_A_BLOCK__  CFRunLoopPerformBlock
2016-08-02 16:36:21.142 RunLoopAction[4232:342167] __CFRUNLOOP_IS_CALLING_OUT_TO_A_SOURCE0_PERFORM_FUNCTION__  Source0
2016-08-02 16:36:21.143 RunLoopAction[4232:342167] __CFRUNLOOP_IS_CALLING_OUT_TO_A_TIMER_CALLBACK_FUNCTION__  NSTimer
2016-08-02 16:36:21.143 RunLoopAction[4232:342167] 即将处理 Timer
2016-08-02 16:36:21.144 RunLoopAction[4232:342167] 即将处理 Source
2016-08-02 16:36:21.144 RunLoopAction[4232:342167] __CFRUNLOOP_IS_SERVICING_THE_MAIN_DISPATCH_QUEUE__  GCD dispatch_after
2016-08-02 16:36:21.145 RunLoopAction[4232:342167] __CFRUNLOOP_IS_SERVICING_THE_MAIN_DISPATCH_QUEUE__  GCD dispatch_async
2016-08-02 16:36:21.146 RunLoopAction[4232:342167] 即将处理 Timer
2016-08-02 16:36:21.146 RunLoopAction[4232:342167] 即将处理 Source
2016-08-02 16:36:21.147 RunLoopAction[4232:342167] 即将处理 Timer
2016-08-02 16:36:21.147 RunLoopAction[4232:342167] 即将处理 Source
2016-08-02 16:36:21.148 RunLoopAction[4232:342167] 即将处理 Timer
2016-08-02 16:36:21.148 RunLoopAction[4232:342167] 即将处理 Source
2016-08-02 16:36:21.148 RunLoopAction[4232:342167] 即将处理 Timer
2016-08-02 16:36:21.149 RunLoopAction[4232:342167] 即将处理 Source
2016-08-02 16:36:21.149 RunLoopAction[4232:342167] 即将进入休眠
```

从运行log 可以看出，dispatch_once 在runloop 还没有进入的时候已经执行了。接着执行的顺序就是：

```
__CFRUNLOOP_IS_CALLING_OUT_TO_A_BLOCK__
__CFRUNLOOP_IS_CALLING_OUT_TO_A_SOURCE0_PERFORM_FUNCTION__
__CFRUNLOOP_IS_CALLING_OUT_TO_A_TIMER_CALLBACK_FUNCTION__


__CFRUNLOOP_IS_SERVICING_THE_MAIN_DISPATCH_QUEUE__
```
执行顺序和源码表述的一样。

```
__CFRunLoopDoBlocks
__CFRunLoopDoSources0
__CFRunLoopDoTimers


__CFRUNLOOP_IS_SERVICING_THE_MAIN_DISPATCH_QUEUE__
```


```
static int32_t __CFRunLoopRun(CFRunLoopRef rl, CFRunLoopModeRef rlm, CFTimeInterval seconds, Boolean stopAfterHandle, CFRunLoopModeRef previousMode) {
    
    //1.判断一下RunLoop 是否停止了，停止则启动runloop.
    
    //2.启动一个source 来检测runloop 是否超时，超时则唤醒runloop.
    
    //标志是否有需要在GCD 执行的操作
    Boolean didDispatchPortLastTime = true;
    int32_t retVal = 0;
    do {
        //3.通知 Observers: RunLoop 即将触发 Timer 回调
        if (rlm->_observerMask & kCFRunLoopBeforeTimers) __CFRunLoopDoObservers(rl, rlm, kCFRunLoopBeforeTimers);
        
        //4.通知 Observers: RunLoop 即将触发 Source0 (非port) 回调。
        if (rlm->_observerMask & kCFRunLoopBeforeSources) __CFRunLoopDoObservers(rl, rlm, kCFRunLoopBeforeSources);
        
        //执行哪些加入到当前runloop的block. e.g :CFRunLoopPerformBlock(<#CFRunLoopRef rl#>, <#CFTypeRef mode#>, <#^(void)block#>)
        __CFRunLoopDoBlocks(rl, rlm);
        
        
        //5.RunLoop 触发 Source0 (非port) 回调。
        Boolean sourceHandledThisLoop = __CFRunLoopDoSources0(rl, rlm, stopAfterHandle);
        if (sourceHandledThisLoop) {
        //6.执行哪些加入到当前runloop的block. 
            __CFRunLoopDoBlocks(rl, rlm);
        }
        
        Boolean poll = sourceHandledThisLoop || (0ULL == timeout_context->termTSR);
        
        //7.判断当前的port 不为空，而且没有触发过dispatchPort 里面的事件，如果有 Source1 (基于port) 处于 ready 状态，直接处理这个 Source1 然后跳转去处理消息。
        
        if (MACH_PORT_NULL != dispatchPort && !didDispatchPortLastTime) {
            msg = (mach_msg_header_t *)msg_buffer;
            if (__CFRunLoopServiceMachPort(dispatchPort, &msg, sizeof(msg_buffer), &livePort, 0, &voucherState, NULL)) {
                goto handle_msg;
            }
        }
        didDispatchPortLastTime = false;
               
        //8.通知 Observers: RunLoop 的线程即将进入休眠(sleep)。
        if (!poll && (rlm->_observerMask & kCFRunLoopBeforeWaiting)) __CFRunLoopDoObservers(rl, rlm, kCFRunLoopBeforeWaiting);
       
        
        /*
         9.调用 mach_msg 等待接受 mach_port 的消息。线程将进入休眠, 直到被下面某一个事件唤醒
        1)一个基于 port 的Source 的事件。
        2)一个 Timer 到时间了
        3) RunLoop 自身的超时时间到了
        4)被其他什么调用者手动唤醒
        */
        __CFRunLoopServiceMachPort(waitSet, &msg, sizeof(msg_buffer), &livePort, poll ? 0 : TIMEOUT_INFINITY, &voucherState, &voucherCopy);
        
        
        //10. 通知 Observers: RunLoop 的线程刚刚被唤醒了。
        __CFRunLoopUnsetSleeping(rl);
        if (!poll && (rlm->_observerMask & kCFRunLoopAfterWaiting)) __CFRunLoopDoObservers(rl, rlm, kCFRunLoopAfterWaiting);
        
        handle_msg:;
        
        //11.处理消息
        __CFRunLoopSetIgnoreWakeUps(rl);
        if (MACH_PORT_NULL == livePort) {
            CFRUNLOOP_WAKEUP_FOR_NOTHING();
            // handle nothing
        } else if (livePort == rl->_wakeUpPort) {
            CFRUNLOOP_WAKEUP_FOR_WAKEUP();
            // do nothing on Mac OS
        }
        else if (rlm->_timerPort != MACH_PORT_NULL && livePort == rlm->_timerPort) {
            
            //如果一个 Timer 到时间了，触发这个Timer的回调。
            CFRUNLOOP_WAKEUP_FOR_TIMER();
            if (!__CFRunLoopDoTimers(rl, rlm, mach_absolute_time())) {
                __CFArmNextTimerInMode(rlm, rl);
            }
        }
        else if (livePort == dispatchPort) {
            
            // 如果有dispatch到main_queue的block，执行block。
            CFRUNLOOP_WAKEUP_FOR_DISPATCH();
            __CFRUNLOOP_IS_SERVICING_THE_MAIN_DISPATCH_QUEUE__(msg);
            _CFSetTSD(__CFTSDKeyIsInGCDMainQ, (void *)0, NULL);
            sourceHandledThisLoop = true;
            didDispatchPortLastTime = true;
        } else {
            CFRUNLOOP_WAKEUP_FOR_SOURCE();
         
            //如果一个 Source1发出事件了，处理这个事件
            CFRunLoopSourceRef rls = __CFRunLoopModeFindSourceForMachPort(rl, rlm, livePort);
            if (rls) {
                sourceHandledThisLoop = __CFRunLoopDoSource1(rl, rlm, rls, msg, msg->msgh_size, &reply) || sourceHandledThisLoop;
            }
            
        }
        //12.执行哪些加入到当前runloop的block. 
        __CFRunLoopDoBlocks(rl, rlm);
        if (sourceHandledThisLoop && stopAfterHandle) {
            
            //进入loop时参数说处理完事件就返回
            retVal = kCFRunLoopRunHandledSource;
        } else if (timeout_context->termTSR < mach_absolute_time()) {
            
            //Runloop 超时le
            retVal = kCFRunLoopRunTimedOut;
        } else if (__CFRunLoopIsStopped(rl)) {
            //被外部干掉了
            retVal = kCFRunLoopRunStopped;
        } else if (rlm->_stopped) {
            //被外部干掉了
            retVal = kCFRunLoopRunStopped;
        } else if (__CFRunLoopModeIsEmpty(rl, rlm, previousMode)) {
            
            // source/timer/observer一个都没有了
            retVal = kCFRunLoopRunFinished;
        }
        
    } while (0 == retVal);
    
    if (timeout_timer) {
        dispatch_source_cancel(timeout_timer);
        dispatch_release(timeout_timer);
    } else {
        free(timeout_context);
    }
    
    //13.通知观察者，runloop 要退出了。
    return retVal;
}
```

 
##Example

简单从一个点击时间开始分析。

> *系统注册了一个基于port 的source ，回调函数为__IOHIDEventSystemClientQueueCallback。通过测试，无论你点击屏幕，甚至是你晃动手机，都是触发这个回调。

> *经查资料知道这首先由 IOKit.framework 生成一个 IOHIDEvent 事件并由 SpringBoard 接收，随后用 mach port 转发给需要的App进程。随后苹果注册的那个 Source1 就会触发回调，并调用 _UIApplicationHandleEventQueue() 进行应用内部的分发。

> *_UIApplicationHandleEventQueue() 会把 IOHIDEvent 处理并包装成 UIEvent 进行处理或分发，其中包括识别 UIGesture/处理屏幕旋转/发送给 UIWindow 等。

下面是一些点击button 的调用log
点击一个button

```
__CFRunLoopDoObservers (刚从休眠中唤醒)
__CFRunLoopDoSource1
__CFRUNLOOP_IS_CALLING_OUT_TO_A_SOURCE1_PERFORM_FUNCTION__
__IOHIDEventSystemClientQueueCallback
__CFRunLoopDoBlocks
__CFRunLoopDoObservers (即将处理 Timer)
__CFRunLoopDoObservers (即将处理 Source)
__CFRunLoopDoBlocks
__CFRunLoopDoSource0 (__CFRUNLOOP_IS_CALLING_OUT_TO_A_SOURCE0_PERFORM_FUNCTION__)
_UIApplicationHandleEventQueue
__CFRunLoopDoBlocks
__CFRunLoopDoBlocks
```

接着说说GCD
实际上 RunLoop 底层也会用到 GCD 的东西，比如 RunLoop 是用 dispatch_source_t 实现的 Timer。但同时 GCD 提供的某些接口也用到了 RunLoop， 例如 dispatch_async()。

调用的log:

```
__CFRunLoopDoObservers (即将处理 Timer)
__CFRunLoopDoObservers (即将处理 Source)
__CFRunLoopDoBlocks
__CFRunLoopDoObservers (即将进入休眠)
__CFRunLoopDoObservers (刚从休眠中唤醒)
__CFRUNLOOP_IS_SERVICING_THE_MAIN_DISPATCH_QUEUE__
```

当调用 dispatch_async(dispatch_get_main_queue(), block) 时，libDispatch 会向主线程的 RunLoop 发送消息，RunLoop会被唤醒，并从消息中取得这个 block，并在回调 __CFRUNLOOP_IS_SERVICING_THE_MAIN_DISPATCH_QUEUE__() 里执行这个 block。但这个逻辑仅限于 dispatch 到主线程，dispatch 到其他线程仍然是由 libDispatch 处理的。

从这里可以看到，每一次执行完工作后，主线程都会进入休眠，等待唤醒。这个时候，可以把一些必须要在主线程执行的，而又不需要马上显示出来的工作在这个时候触发。这个时机，可以通过runloop 的observer 来实现。


<span id="jump">创建观察者</span>

```
- (void)createRunLoopObserverWithObserverType:(CFOptionFlags)flag
{
    CFRunLoopRef runLoop = CFRunLoopGetCurrent();
    CFStringRef runLoopMode = kCFRunLoopDefaultMode;
    CFRunLoopObserverRef observer = CFRunLoopObserverCreateWithHandler
    (kCFAllocatorDefault, flag, true, 0, ^(CFRunLoopObserverRef observer, CFRunLoopActivity _activity) {
        
        switch (_activity) {
            case kCFRunLoopEntry:
            {
                NSLog(@"即将进入Loop");
            }
                break;
            case kCFRunLoopBeforeTimers:
                NSLog(@"即将处理 Timer");
                break;
            case kCFRunLoopBeforeSources:
                NSLog(@"即将处理 Source");
                break;
            case kCFRunLoopBeforeWaiting:
                NSLog(@"即将进入休眠");
                ;
                break;
            case kCFRunLoopAfterWaiting:
                NSLog(@"刚从休眠中唤醒");
                break;
            case kCFRunLoopExit:
                NSLog(@"即将退出Loop");
                break;
            default:
                break;
        }
    });
    CFRunLoopAddObserver(runLoop, observer, runLoopMode);
}
```

flag 传入kCFRunLoopBeforeWaiting。执行操作的时候使用

```
[self performSelector:@selector(performAction) onThread:[NSThread mainThread] withObject:nil waitUntilDone:NO modes:@[NSDefaultRunLoopMode]];
```

传入一个source 0 事件到当前runloop ，把它唤醒。设置NSDefaultRunLoopMode ，让用户在操作tableView 的时候，runloop 切换到 UITrackingMode ，暂停传入的source 0 事件。这样，至少可以提升一下用户体验。

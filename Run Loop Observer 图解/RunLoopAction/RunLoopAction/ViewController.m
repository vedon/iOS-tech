//
//  ViewController.m
//  RunLoopAction
//
//  Created by vedon on 2/8/2016.
//  Copyright © 2016 vedon. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()
@property (strong,nonatomic) dispatch_queue_t uiQueue;
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
    
    
    
    
    //**********************************************************
    NSLog(@"addImageViewToMainView");
    self.uiQueue = dispatch_queue_create("com.uiQueue", NULL);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self addImageViewToMainView];
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


- (void)addImageViewToMainView
{
    UIImageView *imageView1 = [[UIImageView alloc] initWithFrame:CGRectMake(100, 100, 100, 100)];
    dispatch_async(self.uiQueue, ^{
        imageView1.image  = [UIImage imageNamed:@"Demo"];
    });

    
    [self.view addSubview:imageView1];
}

@end

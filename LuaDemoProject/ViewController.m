//
//  ViewController.m
//  LuaDemoProject
//
//  Created by stuliu's iMac on 14-10-20.
//  Copyright (c) 2014年 stuliu's iMac. All rights reserved.
//

#import "ViewController.h"
#import "LuaWaxEngine.h"

#import <AVFoundation/AVFoundation.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.navigationItem.title = @"lua插件测试";
    
    UIButton *downloadBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    downloadBtn.frame = CGRectMake(20, 160, 100, 40);
    downloadBtn.backgroundColor = [UIColor grayColor];
    downloadBtn.titleLabel.textColor = [UIColor blackColor];
    downloadBtn.titleLabel.font = [UIFont systemFontOfSize:15];
    [downloadBtn setTitle:@"运行test.lua" forState:UIControlStateNormal];
    downloadBtn.titleLabel.textColor = [UIColor blackColor];
    [downloadBtn addTarget:self action:@selector(runTestLua:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:downloadBtn];

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark Button-Actions

+ (void)testPrint:(NSString*)str {
    NSLog(@"%@", str);
}

- (void)testPrint:(NSString*)str {
    NSLog(@"%@", str);
}

- (BOOL)runLuaFile:(NSString*)filePath {
    if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        return NO;
    }
    static LuaWaxEngine * _luaWaxEngine = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _luaWaxEngine = [[LuaWaxEngine alloc] initWithScriptFile:filePath];
#if defined(__arm64__) || defined(__x86_64__)
        _luaWaxEngine.stdlibPath = [[NSBundle mainBundle] pathForResource:@"PluginStdLib64" ofType:nil];
#else
        _luaWaxEngine.stdlibPath = [[NSBundle mainBundle] pathForResource:@"PluginStdLib" ofType:nil];
#endif
    });
    
    NSTimeInterval start = [[NSDate date] timeIntervalSince1970];
    NSLog(@"--------start lua plugin, tick: %f", start);
    [_luaWaxEngine runFile:filePath WithContext:nil];
    
    return YES;
}

- (void)runTestLua:(id)sender {
    //脚本测试
    Class cls = NSClassFromString(@"TestView");
    if (!cls) {
        [self runLuaFile:[[NSBundle mainBundle] pathForResource:@"test" ofType:@"lua"]];
        cls = NSClassFromString(@"TestView");
    }
    UIView *testView = [[[cls alloc] initWithFrame:self.view.bounds] autorelease];
    [testView setFrame:self.view.bounds];
    testView.backgroundColor = [UIColor grayColor];
    [self.view addSubview:testView];
}




@end

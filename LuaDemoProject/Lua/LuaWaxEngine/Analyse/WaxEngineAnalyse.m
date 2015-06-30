//
//  WaxEngineAnalyse.m
//  WaxTest
//
//  Created by xuepingwu on 14-9-26.
//  Copyright (c) 2014年 bos. All rights reserved.
//

#import "WaxEngineAnalyse.h"
//#import "RDMEventTaskManager.h"
//#import "RDMEvent.h"

@interface WaxEngineAnalyse()
{
    NSTimeInterval _startPrepareTime;
    NSTimeInterval _startExecuteUserScriptTime;
    NSTimeInterval _endExecuteUserScriptTime;
    NSTimeInterval _viewWillAppearTime;
    NSTimeInterval _viewDidAppearTime;
    WaxErrorCode _errCode;
}
@end

@implementation WaxEngineAnalyse
@synthesize startLoadUserScriptTime,luaFilePath;

- (void)startPrepareForUserScript
{
    _errCode = WaxErrorCode_None;
    _startPrepareTime = [[NSDate date] timeIntervalSince1970];
}

- (void)startLoadUserScript
{
    self.startLoadUserScriptTime = [[NSDate date] timeIntervalSince1970];
}

- (void)startExecuteUserScript
{
    _startExecuteUserScriptTime = [[NSDate date] timeIntervalSince1970];
}

- (void)endExecuteUserScript
{
    _endExecuteUserScriptTime = [[NSDate date] timeIntervalSince1970];
}

- (void)viewWillAppear
{
    _viewWillAppearTime = [[NSDate date] timeIntervalSince1970];
}

- (void)viewDidAppear
{
     _viewDidAppearTime = [[NSDate date] timeIntervalSince1970];
    [self analyseAndReport];
}

-(void)errorOccured:(WaxErrorCode)error errMsg:(NSString *)errMsg;
{
    if (error != WaxErrorCode_None) {
        _errCode = error;
        //上报错误事件至灯塔
        NSMutableDictionary *paramDict = [NSMutableDictionary dictionary];
        if (self.luaFilePath) {
            [paramDict setObject:self.luaFilePath forKey:@"luaFilePath"];
        }
        [paramDict setObject:@(error) forKey:@"WaxErrorCode"];
        if (errMsg && [errMsg length] > 0) {
            [paramDict setObject:errMsg forKey:@"param_FailCode"];
        }
         NSLog(@"WAX ERR:%@",[paramDict description]);
//        [[RDMEventTaskManager instance] doReport:RDM_EVENT_WAX_LUA_EXECUTE_ERROR isSucceed:NO elapse:0 size:0 params:paramDict reportImmediately:YES];
    }
}

- (void)analyseAndReport
{
    if (_errCode != WaxErrorCode_None)  return;
    NSString *prepareForUserLuaTime    = [NSString stringWithFormat:@"%.5f",self.startLoadUserScriptTime - _startPrepareTime];//执行用户脚本准备时间
    NSString *loadToExecuteUserLuaTime = [NSString stringWithFormat:@"%.5f",_startExecuteUserScriptTime - self.startLoadUserScriptTime];//加载到执行用户脚本的时间
    NSString *totalExecuteUserLuaTime  = [NSString stringWithFormat:@"%.5f",_endExecuteUserScriptTime - _startExecuteUserScriptTime];//用户脚本执行总时间
    NSString *prepareToViewWillAppearTime  = [NSString stringWithFormat:@"%.5f",_viewWillAppearTime - _startPrepareTime];//从最开始到界面即将显示出来的时间
    NSString *prepareToViewDidAppearTime  = [NSString stringWithFormat:@"%.5f",_viewDidAppearTime - _startPrepareTime];//从最开始到界面显示出来的时间
    NSMutableDictionary *paramDict = [NSMutableDictionary dictionary];
    if (self.luaFilePath) {
        [paramDict setObject:self.luaFilePath forKey:@"luaFilePath"];
    }
    [paramDict setObject:[NSNumber numberWithFloat:[prepareForUserLuaTime floatValue]] forKey:@"prepareForUserLuaTime"];
    [paramDict setObject:[NSNumber numberWithFloat:[loadToExecuteUserLuaTime floatValue]] forKey:@"loadToExecuteUserLuaTime"];
    [paramDict setObject:[NSNumber numberWithFloat:[totalExecuteUserLuaTime floatValue]] forKey:@"totalExecuteUserLuaTime"];
    [paramDict setObject:[NSNumber numberWithFloat:[prepareToViewWillAppearTime floatValue]] forKey:@"prepareToViewWillAppearTime"];
    [paramDict setObject:[NSNumber numberWithFloat:[prepareToViewDidAppearTime floatValue]] forKey:@"prepareToViewDidAppearTime"];
    NSLog(@"WAX SUCCESS:%@",[paramDict description]);
    //上报至灯塔
//    [[RDMEventTaskManager instance] doReport:RDM_EVENT_WAX_LUA_EXECUTE_SUCCESS isSucceed:YES elapse:0 size:0 params:paramDict reportImmediately:YES];
}

+(id)GetInstance {
    static WaxEngineAnalyse *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[WaxEngineAnalyse alloc] init];
    });
    
    return _sharedInstance;
}

-(void)dealloc {
    [luaFilePath release];
    [super dealloc];
}

@end

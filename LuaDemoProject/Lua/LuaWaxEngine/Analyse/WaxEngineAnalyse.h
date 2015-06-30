//
//  WaxEngineAnalyse.h
//  WaxTest
//
//  Created by xuepingwu on 14-9-26.
//  Copyright (c) 2014年 bos. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum
{
    WaxErrorCode_None = 0,
    WaxErrorCode_UserLuaNotFound,           //  1、用户脚本没找到
    WaxErrorCode_StdLuaNotFound,            //  2、标准库脚本没找到
    WaxErrorCode_StdLuaExecuteErr,          //  3、标准库执行出错
    WaxErrorCode_UserLuaExecuteErr,         //  4、用户脚本执行出错
    WaxErrorCode_LuaDownloadFail            //  5、脚本下载出错
} WaxErrorCode;

@interface WaxEngineAnalyse : NSObject
{
    NSTimeInterval startLoadUserScriptTime;
    NSString *luaFilePath;
}

@property(nonatomic,assign) NSTimeInterval startLoadUserScriptTime;
@property(nonatomic,retain) NSString *luaFilePath;
//加载用户脚本准备工作开始
- (void)startPrepareForUserScript;
//加载用户脚本准备工作结束，开始load用户脚本
- (void)startLoadUserScript;
//load完用户脚本，开始执行用户脚本
- (void)startExecuteUserScript;
//用户脚本执行结束
- (void)endExecuteUserScript;
//视图将显示出来
- (void)viewWillAppear;
//视图全部显示出来
- (void)viewDidAppear;
//错误原因上报
-(void)errorOccured:(WaxErrorCode)error errMsg:(NSString *)errMsg;
//分析数据并上报服务器
- (void)analyseAndReport;

+(WaxEngineAnalyse*) GetInstance;

@end

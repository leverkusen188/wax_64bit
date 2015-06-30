//
//  WaxLuaEngine.h
//  EmbedCocos2dxLua
//
//  Created by czh0766 on 14-3-27.
//
//

#import <Foundation/Foundation.h>

@interface LuaWaxSharedEnv : NSObject

+ (instancetype)sharedWaxEnv;

/**
 *	@brief	保存当前wax环境是否已经创建
 */
@property (atomic, assign) BOOL isWaxStarted;

/**
 *	@brief	注销wax运行环境
 *
 */
- (void)stopWax;

@end

@interface LuaWaxEngine : NSObject {

    NSString* _filepath;
    
}

@property (copy,nonatomic) NSString* stdlibPath;

+ (void)cleanMemory;

/**
 *	@brief	创建一个lua执行者来运行一个脚本
 *
 *	@param 	filepath 	指定要执行的脚本
 *
 *	@return	lua的一个执行者
 */
-(id) initWithScriptFile:(NSString*)filepath;

-(void) runInView:(UIView*)view;

/**
 *	@brief	运行执行者指定的脚本，可以通过ctx传入需要的环境变量，例如navigationControl。
 *
 *	@param 	ctx 	额外的环境变量
 *
 */
-(void) runWithContext:(NSDictionary*)ctx;

-(void) runFile:(NSString*)filepath WithContext:(NSDictionary*)ctx;

//OC中不要使用这两个接口了，用上面那个stopWax
-(void) destroy;
-(void) destroyAfterMoment;

@end

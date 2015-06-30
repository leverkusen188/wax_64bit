//
//  LuaGCEngine.h
//  WaxTest
//
//  Created by chaodong on 14-8-12.
//  Copyright (c) 2014年 bos. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "wax.h"

@interface LuaGCEngine : NSObject

+(LuaGCEngine*) GetInstance;
- (void)cleanMemory;
-(void)start;
-(void)pause;
-(void)stop;


@end

#ifdef  __cplusplus
extern "C" {
#endif
    
    int luaopen_luagc(lua_State *L);
    
#ifdef  __cplusplus
}
#endif
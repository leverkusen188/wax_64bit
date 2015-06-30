//
//  LuaGCEngine.m
//  WaxTest
//
//  Created by chaodong on 14-8-12.
//  Copyright (c) 2014年 bos. All rights reserved.
//

#import "LuaGCEngine.h"
#import "LuaWaxEngine.h"

#import "lua.h"
#import "lauxlib.h"

#import "wax.h"
#import "wax_helpers.h"
#import "wax_gc.h"


const int cleantimes = 3;
const double stepinterval = 0.1;

@implementation LuaGCEngine

-(void)cleanMemoryByStep{
    
    lua_State *L = wax_currentLuaState();
    BEGIN_STACK_MODIFY(L)
    [wax_gc cleanupUnusedObject];
    lua_gc(L, LUA_GCCOLLECT, 0);
    END_STACK_MODIFY(L, 0);
    
    static int count = 0;
    count++;
    __unsafe_unretained typeof(self)  wself = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(stepinterval * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                       
                       if(count< cleantimes+1){
                           
                           [wself cleanMemoryByStep];
                       }else{
                           
                           count=0;
                       }
                   });
    
}

- (void)cleanMemory {
    if ([LuaWaxSharedEnv sharedWaxEnv].isWaxStarted)
    {
        
        
#if 1
        //必需步进释放，否则下面的else那里也只能按对像从属的层次,释放最外层
        [self cleanMemoryByStep];
        
#else
        lua_State *L = wax_currentLuaState();
        BEGIN_STACK_MODIFY(L)
        [wax_gc cleanupUnusedObject];
        lua_gc(L, LUA_GCCOLLECT, 0);
        
        [wax_gc cleanupUnusedObject];
        lua_gc(L, LUA_GCCOLLECT, 0);
        
        [wax_gc cleanupUnusedObject];
        lua_gc(L, LUA_GCCOLLECT, 0);
        
        
        END_STACK_MODIFY(L, 0);
#endif
    }
}


-(void)start{
    
    [wax_gc start];
}
-(void)pause{
    
    [wax_gc pause];
}
-(void)stop{
    
    [wax_gc stop];
}

+(id)GetInstance {
    static LuaGCEngine *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[LuaGCEngine alloc] init];
    });
    
    return _sharedInstance;
}
@end

#define METATABLE_NAME "luagc"

static int lua_CleanMemory(lua_State *L) {
    BEGIN_STACK_MODIFY(L)
    [wax_gc cleanupUnusedObject];
    lua_gc(L, LUA_GCCOLLECT, 0);
    END_STACK_MODIFY(L, 0);
    
    return 1;
}

static const struct luaL_Reg metaFunctions[] = {
    {NULL, NULL}
};

static const struct luaL_Reg functions[] = {
    {"cleanMemory", lua_CleanMemory},
    {NULL, NULL}
};

int luaopen_luagc(lua_State *L) {
    BEGIN_STACK_MODIFY(L);
    
    luaL_newmetatable(L, METATABLE_NAME);
    luaL_register(L, NULL, metaFunctions);
    luaL_register(L, METATABLE_NAME, functions);
    
    END_STACK_MODIFY(L, 0)
    
    return 1;
}
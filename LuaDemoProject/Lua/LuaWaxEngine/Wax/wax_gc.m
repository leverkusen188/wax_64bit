//
//  wax_garbage_collection.m
//  WaxTests
//
//  Created by Corey Johnson on 2/23/10.
//  Copyright 2010 Probably Interactive. All rights reserved.
//

#import "wax_gc.h"

#import "lua.h"
#import "lauxlib.h"

#import "wax.h"
#import "wax_instance.h"
#import "wax_helpers.h"

#define WAX_GC_TIMEOUT 1

@implementation wax_gc

static NSTimer* timer = nil;

+ (void)start {
    [timer invalidate];
    timer = [NSTimer scheduledTimerWithTimeInterval:WAX_GC_TIMEOUT target:self selector:@selector(cleanupUnusedObject) userInfo:nil repeats:YES];
}

+ (void)stop {
    [timer invalidate];
    timer = nil;
    
    [self cleanupUnusedObject];
}

+ (void)cleanupUnusedObject {
    lua_State *L = wax_currentLuaState();
    BEGIN_STACK_MODIFY(L)
    
    wax_instance_pushStrongUserdataTable(L);
    
    lua_pushnil(L);  // first key
    while (lua_next(L, -2)) {
        if (isVaildUserData(L,-1))
        {
            wax_instance_userdata *instanceUserdata = (wax_instance_userdata *)lua_touserdata(L, -1);;
            lua_pop(L, 1); // pops the value, keeps the key
            
            if (!instanceUserdata->isClass && !instanceUserdata->isSuper && [instanceUserdata->instance retainCount] <= 1) {
                lua_pushvalue(L, -1);
                lua_pushnil(L);
                lua_rawset(L, -4); // Clear it!
            }
        } else {
            lua_pop(L, 1);
        }
    }

        
    END_STACK_MODIFY(L, 0);
}

BOOL isVaildUserData(lua_State *L, int index) {
    BEGIN_STACK_MODIFY(L)
    void *p = lua_touserdata(L, index);
    if (p != NULL) {  /* value is a userdata? */
        if (lua_getmetatable(L, index)) {  /* does it have a metatable? */
            lua_getfield(L, LUA_REGISTRYINDEX, WAX_INSTANCE_METATABLE_NAME);  /* get correct metatable */
            if (lua_rawequal(L, -1, -2)) {  /* does it have the correct mt? */
                lua_pop(L, 2);  /* remove both metatables */
                END_STACK_MODIFY(L, 0);
                return YES;
            }
        }
    }
    END_STACK_MODIFY(L, 0);
    return NO;
}
@end

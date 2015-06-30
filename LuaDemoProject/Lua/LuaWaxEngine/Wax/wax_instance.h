/*
 *  wax_instance.h
 *  Lua
 *
 *  Created by ProbablyInteractive on 5/18/09.
 *  Copyright 2009 Probably Interactive. All rights reserved.
 *
 */

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>

#import "lua.h"

typedef struct WaxArgument
{
    struct WaxArgument *next;
    void *data;
}WaxArgument;

typedef struct WaxArguments
{
    struct WaxArgument *first;
}WaxArguments;

void addArgument(WaxArguments *list, void* argument);
WaxArguments * NewArgumentList();
void freeArguments(WaxArguments * list);

#define WAX_INSTANCE_METATABLE_NAME "wax.instance"

typedef struct _wax_instance_userdata {
    id instance;
    BOOL isClass;
    Class isSuper; // isSuper not only stores whether the class is a super, but it also contains the value of the next superClass.
    BOOL actAsSuper; // It only acts like a super once, when it is called for the first time.
    BOOL waxRetain; // need release instance when gc,
} wax_instance_userdata;

int luaopen_wax_instance(lua_State *L);

wax_instance_userdata *wax_instance_create(lua_State *L, id instance, BOOL isClass);
wax_instance_userdata *wax_instance_createSuper(lua_State *L, wax_instance_userdata *instanceUserdata);
void wax_instance_pushUserdataTable(lua_State *L);
void wax_instance_pushStrongUserdataTable(lua_State *L);

/*增加四个方法用于self变量存储，通过strong->weak引用模式间接打破lua<->oc引用循环
 *LuaGCEngine中还有一个清空StrongSelfVarsUserdataTable的函数请在执行脚本前调用
 *同时我将一次手动GC的执行小gc次数改为3次防止遗漏gc垃圾数据*/
//
//void wax_instance_pushSelfVars(lua_State *L, const char *tableName, bool isWeakTable);
//void wax_instance_pushSelfVarsTable(lua_State *L, const char *tableName, bool isWeakTable);
//void wax_instance_pushStrongSelfVarsTable(lua_State *L);
//void wax_instance_pushStrongSelfVars(lua_State *L);


BOOL wax_instance_pushFunction(lua_State *L, id self, SEL selector);
void wax_instance_pushUserdata(lua_State *L, id object);
BOOL wax_instance_isWaxClass(id instance);

void wax_pop(lua_State *L,int n);

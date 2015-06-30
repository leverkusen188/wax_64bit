//  Created by ProbablyInteractive.
//  Copyright 2009 Probably Interactive. All rights reserved.

#import <Foundation/Foundation.h>
#import "lua.h"

#define WAX_VERSION 0.93

#ifdef  __cplusplus
extern "C" {
#endif

void wax_setup();
void wax_addSearchPath(const char* path);
void wax_start(char *initScript, const char* stdlibPath, lua_CFunction extensionFunctions, ...);
void wax_runScript(const char *scriptFile);
void wax_startWithServer();
int wax_executeScriptFile(const char* filename);
void wax_end();

lua_State *wax_currentLuaState();

void luaopen_wax(lua_State *L);
    
#ifdef  __cplusplus
}
#endif

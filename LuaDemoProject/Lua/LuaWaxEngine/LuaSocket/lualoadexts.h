//
//  lualoadexts.h
//  TestLua
//
//  Created by ice on 5/6/14.
//
//
#ifdef LUA_SOCKET_DEBUG //added by xiaoma
#ifndef TestLua_lualoadexts_h
#define TestLua_lualoadexts_h
 
#include "lauxlib.h"
 
 
/* Offset of the field in the structure. */
#define	fldoff(name, field) \
((int)&(((struct name *)0)->field))
 
/* Size of the field in the structure. */
#define	fldsiz(name, field) \
(sizeof(((struct name *)0)->field))
 
/* Address of the structure from a field. */
#define	strbase(name, addr, field) \
((struct name *)((char *)(addr) - fldoff(name, field)))
 
 
void luax_loadexts(lua_State *L);
 
#endif

#endif
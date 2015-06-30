//
//  luaOptms.cpp
//  LuaOptms
//
//  Created by jerryyguo on 14-9-18.
//  Copyright (c) 2014年 tencent. All rights reserved.
//


#include <stdio.h>
#include <time.h>
#include <sys/types.h>
#include <sys/timeb.h>
//#include <tchar.h>

#include <string>
#include <list>
#if defined __GNUC__ || defined __APPLE__
#include <ext/hash_map>
#else
#include <hash_map>
#endif

#include <algorithm>

#ifdef __cplusplus
extern "C" {
#endif
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#ifdef __cplusplus
}
#endif

#ifdef _USE_FCL
#define luaL_register(L, name, reg)  luaL_openlib((L), (name), (reg), 0)
#define luaL_Reg   luaL_reg
#endif

#include <vector>
using std::vector;

struct ProfStat;

struct FuncInfo {
	const void*  pv;
	std::string  name;
	int          namewhat;
	long         callTotal;
	long         callTimes;
};

enum enNameWhat{
	what_unknown,
	what_ccode,
	what_mainchunk,
	what_global,
	what_local,
	what_upvalue,
	what_method,
	what_field,
	what_tailcall,
};

//static const char* s_namewhat_ch = ".glumf";


static const char* s_namewhat_disp[] = {
	"<unknown>",
	"<C code>",
	"<main chunk>",
	"global",
	"local",
	"upvalue",
	"method",
	"field",
	"<tail call>",
	NULL,
};

typedef struct CallInfo CallInfo;

typedef  __gnu_cxx::hash_map<const void*, CallInfo*>  CallMap;

struct CallInfo
{
	const void*  pv;
	std::string  name;
	int          namewhat;
	long         callTotal;
	long         callTimes;
	long         callStart;
	CallInfo*    parent;
	CallMap      children;
};

struct CallInfoTotalGreater
{
public:
	bool operator () (const CallInfo* a, const CallInfo* b)
	{
		return a->callTotal > b->callTotal;
	}
};

typedef  __gnu_cxx::hash_map<const void*, FuncInfo*>  FuncInfoMap;
//typedef  std::list<CallInfo*>   CallStack;
//typedef  stdext::hash_map<const void*, ProfStat*>  ProfStatMap;



static FuncInfoMap  s_funcs;
static CallInfo     s_root_call;
static CallInfo*    s_current_call;
static long         s_call_deeps;

static void clear_calls(CallInfo* calls)
{
	CallMap::iterator it = calls->children.begin();
	CallMap::iterator itend = calls->children.end();
	for( ; it != itend; it++)
	{
		clear_calls(it->second);
		delete it->second;
	}
	calls->children.clear();
}

static void clear_call_root()
{
	clear_calls(&s_root_call);
	//s_root_stat.children.clear();
    
	s_current_call = &s_root_call;
	s_root_call.namewhat = what_unknown;
	s_root_call.name.clear();
	s_root_call.parent = NULL;
	s_root_call.pv = NULL;
	s_root_call.callStart = 0;
	s_root_call.callTimes = 0;
	s_root_call.callTotal = 0;
    
	s_call_deeps = 0;
}

static void clear_funcs()
{
	FuncInfoMap::iterator  it = s_funcs.begin();
	FuncInfoMap::iterator  itend = s_funcs.end();
    
	for( ; it != itend; it++)
	{
		delete it->second;
	}
	s_funcs.clear();
}


static int namewhat_from(const char* nw, const char* what)
{
	switch(*nw)
	{
        case 'g' : return what_global;
        case 'l' : return what_local;
        case 'u' : return what_upvalue;
        case 'm' : return what_method;
        case 'f' : return what_field;
        default:
            switch(*what)
		{
            case 'm': return what_mainchunk;
            case 'C': return what_ccode;
            case 't': return what_tailcall;
		}
            return what_unknown;
	}
}

static const char* name_disp(lua_Debug* ar, char* buffer, int blen)
{
	const char* pn;
	switch(*ar->namewhat)
	{
        case 'g':
        case 'l':
        case 'u':
        case 'f':
        case 'm':
            pn = ar->name ? ar->name : "?";
            break;
        default:
            switch(*ar->what)
		{
            case 'm':
                pn = "";
                break;
            case 'C': case 't':
                pn = "?";
                break;
            default:
                snprintf(buffer, blen, "<%s:%d>", ar->short_src, ar->linedefined);
                pn = buffer;
                break;
		}
	}
	return pn;
}

static int update_call(const void* pv, lua_Debug* ar, long ms)
{
	int nw = namewhat_from(ar->namewhat, ar->what);
	char  name[256];
    
	CallInfo* pcall;
	CallMap::iterator it = s_current_call->children.find(pv);
	if(it == s_current_call->children.end())
	{
		pcall = new CallInfo;
		pcall->callStart = ms;
		pcall->callTotal = 0;
		pcall->callTimes = 1;
		pcall->namewhat = nw;
		pcall->name = name_disp(ar, name, sizeof(name));
		pcall->pv = pv;
		pcall->parent = s_current_call;
		it = s_current_call->children.insert(CallMap::value_type(pv, pcall)).first;
	}
	else
	{
		pcall = it->second;
		pcall->callStart = ms;
		pcall->callTimes += 1;
        
		if(nw > 0 && nw < pcall->namewhat)
		{
			pcall->name = name_disp(ar, name, sizeof(name));
		}
	}
    
	s_current_call = pcall;
	s_call_deeps++;
    
	//printf("%ld, enter function %s [%s], times:%d, deeps=%d\n", ms, pcall->name.c_str(), s_namewhat_disp[pcall->namewhat], pcall->callTimes, s_call_deeps);
    
	return 0;
}


static int update_return(long ms)
{
	s_current_call->callTotal += ms-s_current_call->callStart;
	if(s_current_call->parent)
	{
		CallInfo* pcall = s_current_call;
		s_current_call = s_current_call->parent;
		s_call_deeps--;
        
		//printf("%ld, leave function %s [%s], total: %ld, deeps=%d\n",  ms, pcall->name.c_str(), s_namewhat_disp[pcall->namewhat], pcall->callTotal, s_call_deeps);
	}
	return 0;
}

static int lprof_init(lua_State* L)
{
	lua_Integer n = luaL_checkint(L, 1);
	//printf("lprof.init: %d\n", (int)n);
	return 0;
}

static struct timeb s_stcb;

static void lprof_hook_callret(lua_State* L, lua_Debug* ar)
{
	struct timeb tb;
	ftime(&tb);
    
	//long sec = tb.time - s_stcb.time;
	//int msec = tb.millitm - s_stcb.millitm;
	//if(msec < 0)
	//{
	//	sec--;
	//	msec+=1000;
	//}
	long ms = (tb.time - s_stcb.time) * 1000 + (tb.millitm - s_stcb.millitm);
    
	switch(ar->event)
	{
        case LUA_HOOKCALL:
            lua_getinfo(L, "Snl", ar);
		{
			int n = lua_gettop(L);
			//printf("%p:%s\n", lua_tostring(L, -n-1), lua_typename(L,lua_type(L, -n-1)));
			const void* pv = lua_topointer(L, -n-1);
			update_call(pv, ar, ms);
			
		}
            //printf("%ld.%03d: lua [%s] function `%s' is begin called(at %s: %d).\n",
            //	sec, msec, ar->namewhat, ar->name, ar->short_src, ar->currentline);
            //s_callst.push_back()
            break;
        case LUA_HOOKRET:
            //if(s_callst.empty())
            //	break;
            //lua_getinfo(L, "Snl", ar);
            update_return(ms);
            //printf("%ld.%03d: lua [%s] function `%s' is returned(at line: %d).\n", sec, msec, ar->namewhat, ar->name, ar->currentline);
            break;
        case LUA_HOOKTAILRET:
            update_return(ms);
            //printf("lua function tail call is returned.\n");
            break;
	}
	fflush(stdout);
}


static int lprof_enable(lua_State* L)
{
	if(lua_isnoneornil(L, 1))
		luaL_typerror(L, 1, "boolean");
	lua_Integer b = lua_toboolean(L, 1);
	if(b)
	{
		ftime(&s_stcb);
		clear_call_root();
		lua_sethook(L, lprof_hook_callret, LUA_MASKCALL|LUA_MASKRET, 0);
	}
	else
	{
		lua_sethook(L, NULL, 0, 0);
	}
	return 0;
}




static void auxstat(lua_State* L, CallInfo* pCallInfo, long lmt, int deeps)
{
	int top = lua_gettop(L);
    
	char entab[1002];
	int chs = deeps * 2;
	if (chs > 1000) chs = 1000;
	memset(entab, ' ', deeps * 2);
	entab[chs] = 0;
	lua_pushstring(L, entab);
	lua_pushfstring(L, "function %s [%s], invoked times: %d, total cost: %d(ms)\n",
                    pCallInfo->name.c_str(), s_namewhat_disp[pCallInfo->namewhat], pCallInfo->callTimes, pCallInfo->callTotal);
	std::vector<CallInfo*>  cvs;
	for(CallMap::iterator it = pCallInfo->children.begin(); it != pCallInfo->children.end(); it++)
	{
		if(it->second->callTotal >= lmt)
		{
			cvs.push_back(it->second);
			//auxstat(L, it->second, deeps+1);
		}
	}
	std::sort(cvs.begin(), cvs.end(), CallInfoTotalGreater());
	CallInfo** pp = &*cvs.begin();
	CallInfo** pe = &*cvs.end();
	for(; pp < pe; pp++)
	{
		auxstat(L, *pp, lmt, deeps+1);
	}
    
	lua_concat(L, lua_gettop(L)-top);
}

static int lprof_stat(lua_State* L)
{
	//lua_pushliteral(L, "print");
	//lua_rawget(L, LUA_GLOBALSINDEX);
	long lmt = (long)luaL_optnumber(L, 1, -1);
	auxstat(L, &s_root_call, lmt, 0);
    
	return 1;
}


static const luaL_Reg lprof_reg[] = {
	{ "init", lprof_init },
	{ "enable", lprof_enable },
	{ "stat", lprof_stat},
	{ NULL,   NULL },
};


extern "C"  int luaopen_lprof(lua_State* L)
{
	luaL_register(L, "lprof", lprof_reg);
	return 0;
}











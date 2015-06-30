/*
 *  wax_instance.c
 *  Lua
 *
 *  Created by ProbablyInteractive on 5/18/09.
 *  Copyright 2009 Probably Interactive. All rights reserved.
 *
 */

#import "wax_instance.h"
#import "wax_class.h"
#import "wax.h"
#import "wax_helpers.h"
#import "lauxlib.h"
//#import "lobject.h"  chenzhanhui

//#define Lua_Self_Optimized  1       //这个flag先关闭，  由于5.3 lua的crash比较多，怀疑是此处优化代码引起。

void addArgument(WaxArguments *list, void* argument){
    if(list->first == NULL){
        list->first = (WaxArgument *)malloc(sizeof(WaxArgument));
        list->first->data = argument;
        list->first->next = NULL;
    }else{
        WaxArgument* node = list->first;
        while(node->next != NULL){
            node = node->next;
        }
        node->next =(WaxArgument *)malloc(sizeof(WaxArgument));
        node->next->data = argument;
        node->next->next = NULL;
    }
}

WaxArguments * NewArgumentList(){
    WaxArguments * ret =(WaxArguments *)malloc(sizeof(WaxArguments));
    ret -> first = NULL;
    return ret;
}

void freeArguments(WaxArguments * list){
    WaxArgument* node = list->first;
    while(node != NULL){
        WaxArgument* tmp = node;
        node = node->next;
        if (tmp->data)
            free(tmp->data);
        free(tmp);
    }
    free(list);
}



static int __index(lua_State *L);
static int __newindex(lua_State *L);
static int __gc(lua_State *L);
static int __tostring(lua_State *L);
static int __eq(lua_State *L);

static int methods(lua_State *L);

static int methodClosure(lua_State *L);
static int superMethodClosure(lua_State *L);
static int customInitMethodClosure(lua_State *L);

static BOOL overrideMethod(lua_State *L, wax_instance_userdata *instanceUserdata);
static int pcallUserdata(lua_State *L, id self, SEL selector, va_list args);

static const struct luaL_Reg metaFunctions[] = {
    {"__index", __index},
    {"__newindex", __newindex},
    {"__gc", __gc},
    {"__tostring", __tostring},
    {"__eq", __eq},
    {NULL, NULL}
};

static const struct luaL_Reg functions[] = {
    {"methods", methods},
    {NULL, NULL}
};

int luaopen_wax_instance(lua_State *L) {
    BEGIN_STACK_MODIFY(L);
    
    luaL_newmetatable(L, WAX_INSTANCE_METATABLE_NAME); //创建名为WAX_INSTANCE_METATABLE_NAME的表
    luaL_register(L, NULL, metaFunctions); //第一个参数为注册模块名，第二个注册函数的数组名
    luaL_register(L, WAX_INSTANCE_METATABLE_NAME, functions);
    
    END_STACK_MODIFY(L, 0)
    
    return 1;
}

#pragma mark Instance Utils
#pragma mark -------------------

// Creates userdata object for obj-c instance/class and pushes it onto the stack
wax_instance_userdata *wax_instance_create(lua_State *L, id instance, BOOL isClass) {
    BEGIN_STACK_MODIFY(L)
    
    // Does user data already exist?
    wax_instance_pushUserdata(L, instance);
    
    if (lua_isnil(L, -1)) {
        lua_pop(L, 1); // pop nil stack
    }
    else {
        //wax_instance_userdata *instanceUserdataFound = (wax_instance_userdata *)lua_touserdata(L, -1);
        //if (!isClass)
        //    wax_log(LOG_GC, @"wax_instance_create Found instanceUserdata %@ %@(%p) isSuper=%@ retainCount=%i", instanceUserdataFound->isClass ? @"Class" : @"Instance", [instanceUserdataFound->instance class], instanceUserdataFound->instance, instanceUserdataFound->isSuper,[instanceUserdataFound->instance retainCount]);
        return lua_touserdata(L, -1);
    }
    
    size_t nbytes = sizeof(wax_instance_userdata);
    wax_instance_userdata *instanceUserdata = (wax_instance_userdata *)lua_newuserdata(L, nbytes);
    instanceUserdata->instance = instance;
    instanceUserdata->isClass = isClass;
    instanceUserdata->isSuper = nil;
    instanceUserdata->actAsSuper = NO;
    instanceUserdata->waxRetain = NO;
    
    if (!isClass) {
        [instanceUserdata->instance retain];
    }
    
    // set the metatable
    luaL_getmetatable(L, WAX_INSTANCE_METATABLE_NAME); //获取WAX_INSTANCE_METATABLE_NAME并放入栈顶
    lua_setmetatable(L, -2); //把l把新生成的userdata的metatable设置为WAX_INSTANCE_METATABLE_NAME。
    
    // give it a nice clean environment
    lua_newtable(L);
    lua_setfenv(L, -2);
    
    
    //    //生成我们自己的环境表
    //    NSString *selfVarsEnvTableName = [[[NSString alloc] initWithFormat:@"%s%p","__uservarsenvtable_",&instanceUserdata] autorelease];
    //    wax_instance_pushSelfVarsTable(L, [selfVarsEnvTableName UTF8String], false);
    //    lua_pop(L, 1);
    
    
    
    wax_instance_pushUserdataTable(L);
    
    // register the userdata table in the metatable (so we can access it from obj-c)
    // if (!isClass)
    //   wax_log(LOG_GC, @"wax_instance_create Storing reference of %@ to userdata table %@(%p -> %p) retainCount=%i", isClass ? @"class" : @"instance", [instance class], instance, instanceUserdata, [instance retainCount]);
    lua_pushlightuserdata(L, instanceUserdata->instance);
    lua_pushvalue(L, -3); // Push userdata
    lua_rawset(L, -3);
    
    lua_pop(L, 1); // Pop off userdata table
    
    
    wax_instance_pushStrongUserdataTable(L);
    lua_pushlightuserdata(L, instanceUserdata->instance);
    lua_pushvalue(L, -3); // Push userdata
    lua_rawset(L, -3);
    
    //if (!isClass)
    //    wax_log(LOG_GC, @"wax_instance_create Storing reference to strong userdata table %@(%p -> %p)  retainCount=%i", [instance class], instance, instanceUserdata, [instance retainCount]);
    
    lua_pop(L, 1); // Pop off strong userdata table
    
    END_STACK_MODIFY(L, 1)
    
    //wax_log(LOG_GC, @"wax_instance_create created %@ %@(%p) isSuper=%@ retainCount=%i", instanceUserdata->isClass ? @"Class" : @"Instance", [instanceUserdata->instance class], instanceUserdata->instance, instanceUserdata->isSuper,[instanceUserdata->instance retainCount]);
    return instanceUserdata;
}

// Creates pseudo-super userdata object for obj-c instance and pushes it onto the stack
wax_instance_userdata *wax_instance_createSuper(lua_State *L, wax_instance_userdata *instanceUserdata) {
    // if (!instanceUserdata->isClass)
    //   wax_log(LOG_GC, @"enter wax_instance_createSuper %@ %@(%p) isSuper=%@ retainCount=%i", instanceUserdata->isClass ? @"Class" : @"Instance", [instanceUserdata->instance class], instanceUserdata->instance, instanceUserdata->isSuper,[instanceUserdata->instance retainCount]);
    BEGIN_STACK_MODIFY(L)
    
    size_t nbytes = sizeof(wax_instance_userdata);
    wax_instance_userdata *superInstanceUserdata = (wax_instance_userdata *)lua_newuserdata(L, nbytes);
    superInstanceUserdata->instance = instanceUserdata->instance;
    superInstanceUserdata->isClass = instanceUserdata->isClass;
    superInstanceUserdata->actAsSuper = YES;
    superInstanceUserdata->waxRetain = NO;
    
    // isSuper not only stores whether the class is a super, but it also contains the value of the next superClass
    if (instanceUserdata->isSuper) {
        superInstanceUserdata->isSuper = [instanceUserdata->isSuper superclass];
    }
    else {
        superInstanceUserdata->isSuper = [instanceUserdata->instance superclass];
    }
    
    
    // set the metatable
    luaL_getmetatable(L, WAX_INSTANCE_METATABLE_NAME);
    lua_setmetatable(L, -2);
    
    wax_instance_pushUserdata(L, instanceUserdata->instance);
    if (lua_isnil(L, -1)) { // instance has no lua object, push empty env table (This shouldn't happen, tempted to remove it)
        lua_pop(L, 1); // Remove nil and superclass userdata
        lua_newtable(L);
    }
    else {
        lua_getfenv(L, -1);
        lua_remove(L, -2); // Remove nil and superclass userdata
    }
    
    // Give it the instance's metatable
    lua_setfenv(L, -2);
    
    END_STACK_MODIFY(L, 1)
    
    //wax_log(LOG_GC, @"enter wax_instance_createSuper superInstanceUserdata %@ %@(%p) isSuper=%@ retainCount=%i", superInstanceUserdata->isClass ? @"Class" : @"Instance", [superInstanceUserdata->instance class], superInstanceUserdata->instance, superInstanceUserdata->isSuper,[superInstanceUserdata->instance retainCount]);
    return superInstanceUserdata;
}

// The userdata table holds weak references too all the instance userdata
// created. This is used to manage all instances of Objective-C objects created
// via Lua so we can release/gc them when both Lua and Objective-C are finished with
// them.
void wax_instance_pushUserdataTable(lua_State *L) {
    BEGIN_STACK_MODIFY(L)
    static const char* userdataTableName = "__wax_userdata";
    luaL_getmetatable(L, WAX_INSTANCE_METATABLE_NAME);
    lua_getfield(L, -1, userdataTableName);
    
    if (lua_isnil(L, -1)) { // Create new userdata table, add it to metatable
        lua_pop(L, 1); // Remove nil
        
        lua_pushstring(L, userdataTableName); // Table name
        lua_newtable(L);
        lua_rawset(L, -3); // Add userdataTableName table to WAX_INSTANCE_METATABLE_NAME
        lua_getfield(L, -1, userdataTableName);
        
        lua_pushvalue(L, -1);
        lua_setmetatable(L, -2); // userdataTable is it's own metatable
        
        lua_pushstring(L, "v");
        lua_setfield(L, -2, "__mode");  // Make weak table
    }
    
    END_STACK_MODIFY(L, 1)
}

// Holds strong references to userdata created by wax... if the retain count dips below
// 2, then we can remove it because we know obj-c doesn't care about it anymore
void wax_instance_pushStrongUserdataTable(lua_State *L) {
    BEGIN_STACK_MODIFY(L)
    static const char* userdataTableName = "__wax_strong_userdata";
    luaL_getmetatable(L, WAX_INSTANCE_METATABLE_NAME);
    lua_getfield(L, -1, userdataTableName);
    
    if (lua_isnil(L, -1)) { // Create new userdata table, add it to metatable
        lua_pop(L, 1); // Remove nil
        
        lua_pushstring(L, userdataTableName); // Table name
        lua_newtable(L);
        lua_rawset(L, -3); // Add userdataTableName table to WAX_INSTANCE_METATABLE_NAME
        lua_getfield(L, -1, userdataTableName);
    }
    
    END_STACK_MODIFY(L, 1)
}


// First look in the object's userdata for the function, then look in the object's class's userdata
BOOL wax_instance_pushFunction(lua_State *L, id self, SEL selector) {
    BEGIN_STACK_MODIFY(L)
    
    wax_instance_pushUserdata(L, self);
    if (lua_isnil(L, -1)) {
        
        // TODO:
        // quick and dirty solution to let obj-c call directly into lua
        // cause a obj-c leak, should we release it later?
        wax_instance_userdata *data = wax_instance_create(L, self, NO);
        data->waxRetain = YES;
        //END_STACK_MODIFY(L, 0)
        //return NO; // userdata doesn't exist
    }
    
    lua_getfenv(L, -1);
    wax_pushMethodNameFromSelector(L, selector);
    lua_rawget(L, -2);
    
    BOOL result = YES;
    
    if (!lua_isfunction(L, -1)) { // function not found in userdata
        lua_pop(L, 3); // Remove userdata, env and non-function
        if ([self class] == self) { // This is a class, not an instance
            result = wax_instance_pushFunction(L, [self superclass], selector); // Check to see if the super classes know about this function
        }
        else {
            result = wax_instance_pushFunction(L, [self class], selector);
        }
    }
    
    END_STACK_MODIFY(L, 1)
    
    return result;
}

// Retrieves associated userdata for an object from the wax instance userdata table
void wax_instance_pushUserdata(lua_State *L, id object) {
    BEGIN_STACK_MODIFY(L);
    
    wax_instance_pushUserdataTable(L);
    lua_pushlightuserdata(L, object);
    lua_rawget(L, -2);
    lua_remove(L, -2); // remove userdataTable
    
    
    END_STACK_MODIFY(L, 1)
}

BOOL wax_instance_isWaxClass(id instance) {
    // If this is a wax class, or an instance of a wax class, it has the userdata ivar set
    return class_getInstanceVariable([instance class], WAX_CLASS_INSTANCE_USERDATA_IVAR_NAME) != nil;
}
void wax_pop(lua_State *L,int n){
    
    lua_pop(L, n);
}

#pragma mark Override Metatable Functions
#pragma mark ---------------------------------

static int __index(lua_State *L) {
    
    wax_instance_userdata *instanceUserdata = (wax_instance_userdata *)luaL_checkudata(L, 1, WAX_INSTANCE_METATABLE_NAME);
    
    if (lua_isstring(L, 2) && strcmp("super", lua_tostring(L, 2)) == 0) { // call to super!
        wax_instance_createSuper(L, instanceUserdata);
        return 1;
    }
    
    // Check instance userdata, unless we are acting like a super
    if (!instanceUserdata->actAsSuper) {
        lua_getfenv(L, -2);
        lua_pushvalue(L, -2);
        lua_rawget(L, 3);
    }
    else {
        lua_pushnil(L);
    }
    //作一个保护判断，防止脚本destoryDealloc中self.abc self被oc释放两次，instanceUserdata->instance野指针的情况
    if(lua_isnil(L, -1))
    {
        // Check instance's class userdata, or if it is a super, check the super's class data
        Class classToCheck = instanceUserdata->actAsSuper ? instanceUserdata->isSuper : [instanceUserdata->instance class];
        while (lua_isnil(L, -1) && wax_instance_isWaxClass(classToCheck)) {
            // Keep checking superclasses if they are waxclasses, we want to treat those like they are lua
            lua_pop(L, 1);
            wax_instance_pushUserdata(L, classToCheck);
            
            // If there is no userdata for this instance's class, then leave the nil on the stack and don't anything else
            if (!lua_isnil(L, -1)) {
                lua_getfenv(L, -1);
                lua_pushvalue(L, 2);
                lua_rawget(L, -2);
                lua_remove(L, -2); // Get rid of the userdata env
                lua_remove(L, -2); // Get rid of the userdata
            }
            
            classToCheck = class_getSuperclass(classToCheck);
        }
    }
    
    if (lua_isnil(L, -1)) { // If we are calling a super class, or if we couldn't find the index in the userdata environment table, assume it is defined in obj-c classes
        SEL foundSelectors[2] = {nil, nil};
        BOOL foundSelector = wax_selectorForInstance(instanceUserdata, foundSelectors, lua_tostring(L, 2), NO);
#ifdef Lua_Nil_Protection
        //armstrong
        //invoking a instance's method which doesn't exist, we replace it with a method that do nothing.
        //to avoid the exception which causes crash.
        BOOL isReplacement = NO;
        lua_getglobal(L, "nilReplaceTag");
        if (lua_isboolean(L, -1)) {
            isReplacement = lua_toboolean(L, -1);
        }
        lua_pushnil(L);
        lua_setglobal(L, "nilReplaceTag");  //reset the global boolean
        lua_settop(L, lua_gettop(L) -1);    //pop the boolean value
        if (!foundSelector && !instanceUserdata->isClass && isReplacement) {
            //            NSLog(@"%s 方法没找到，用init 替代", lua_tostring(L, 2));
            lua_pushstring(L, "init");
            lua_replace(L, 2);
            foundSelector = wax_selectorForInstance(instanceUserdata, foundSelectors, lua_tostring(L, 2), NO);
            //tell methodClosure that init is a replaced method
            lua_pushboolean(L, 1);
            lua_setglobal(L, "initReplaceTag");
        }
#endif
        
        if (foundSelector) { // If the class has a method with this name, push as a closure
            lua_pushstring(L, sel_getName(foundSelectors[0]));
            foundSelectors[1] ? lua_pushstring(L, sel_getName(foundSelectors[1])) : lua_pushnil(L);
            lua_pushcclosure(L, instanceUserdata->actAsSuper ? superMethodClosure : methodClosure, 2);
        }
    }
    else if (!instanceUserdata->isSuper && instanceUserdata->isClass && wax_isInitMethod(lua_tostring(L, 2))) { // Is this an init method create in lua?
        lua_pushcclosure(L, customInitMethodClosure, 1);
    }
    
    // Always reset this, an object only acts like a super ONE TIME!
    instanceUserdata->actAsSuper = NO;
    
    return 1;
    
}

static int __newindex(lua_State *L) {
    
    wax_instance_userdata *instanceUserdata = (wax_instance_userdata *)luaL_checkudata(L, 1, WAX_INSTANCE_METATABLE_NAME);
    
    // If this already exists in a protocol, or superclass make sure it will call the lua functions
    if (instanceUserdata->isClass && lua_type(L, 3) == LUA_TFUNCTION) {
        overrideMethod(L, instanceUserdata);
    }
    
    // Add value to the userdata's environment table
    lua_getfenv(L, 1);
    lua_insert(L, 2);
    lua_rawset(L, 2);
    
    return 0;
    
}

static int __gc(lua_State *L) {
    wax_instance_userdata *instanceUserdata = (wax_instance_userdata *)luaL_checkudata(L, 1, WAX_INSTANCE_METATABLE_NAME);
    //    if (!instanceUserdata->isClass)
    //        wax_log(LOG_GC, @"__gc Maybe Releasing %@ %@(%p) isSuper=%@ retainCount=%i", instanceUserdata->isClass ? @"Class" : @"Instance", [instanceUserdata->instance class], instanceUserdata->instance, instanceUserdata->isSuper,[instanceUserdata->instance retainCount]);
    
    if (!instanceUserdata->isClass && !instanceUserdata->isSuper) {
        // This seems like a stupid hack. But...
        // If we want to call methods on an object durring gc, we have to readd
        // the instance/userdata to the userdata table. Why? Because it is
        // removed from the weak table before GC is called.
        wax_instance_pushUserdataTable(L);
        lua_pushlightuserdata(L, instanceUserdata->instance);
        lua_pushvalue(L, -3);
        lua_rawset(L, -3);
        
        //wax_log(LOG_GC, @"__gc Releasing %@ %@(%p) retain count:%zd", instanceUserdata->isClass ? @"Class" : @"Instance", [instanceUserdata->instance class], instanceUserdata->instance,[instanceUserdata->instance retainCount]);
        
        //这里实在有点坑，wax中自定义的NSObject不能写dealloc，否则在waxend的时候会crash。。。看下面的链接：
        //https://groups.google.com/forum/#!searchin/iphonewax/dealloc/iphonewax/gSEFFsH2bTI/OcKf1Trrq-0J
        //https://groups.google.com/forum/#!searchin/iphonewax/dealloc/iphonewax/AfTiHKvHaqI/BB-X1L9y1SEJ
        //所以这里增加一个destroy的调用替代原来dealloc的完成的清理工作吧。不过，super的dealloc还是会被调用的，呵呵。。。
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
        if (!instanceUserdata->isClass && !instanceUserdata->isSuper
            && [instanceUserdata->instance respondsToSelector:@selector(destroyDealloc)]) {
            [instanceUserdata->instance performSelector:@selector(destroyDealloc)];
        }
#pragma clang diagnostic pop
        
        [instanceUserdata->instance release];
        
        lua_pushlightuserdata(L, instanceUserdata->instance);
        lua_pushnil(L);
        lua_rawset(L, -3);
        lua_pop(L, 1);
    }
    
    return 0;
}








static int __tostring(lua_State *L) {
    wax_instance_userdata *instanceUserdata = (wax_instance_userdata *)luaL_checkudata(L, 1, WAX_INSTANCE_METATABLE_NAME);
    lua_pushstring(L, [[NSString stringWithFormat:@"(%p => %p) %@", instanceUserdata, instanceUserdata->instance, instanceUserdata->instance] UTF8String]);
    
    return 1;
}

static int __eq(lua_State *L) {
    wax_instance_userdata *o1 = (wax_instance_userdata *)luaL_checkudata(L, 1, WAX_INSTANCE_METATABLE_NAME);
    wax_instance_userdata *o2 = (wax_instance_userdata *)luaL_checkudata(L, 2, WAX_INSTANCE_METATABLE_NAME);
    
    lua_pushboolean(L, [o1->instance isEqual:o2->instance]);
    return 1;
}

#pragma mark Userdata Functions
#pragma mark -----------------------

static int methods(lua_State *L) {
    wax_instance_userdata *instanceUserdata = (wax_instance_userdata *)luaL_checkudata(L, 1, WAX_INSTANCE_METATABLE_NAME);
    
    uint count;
    Method *methods = class_copyMethodList([instanceUserdata->instance class], &count);
    
    lua_newtable(L);
    
    for (int i = 0; i < count; i++) {
        Method method = methods[i];
        lua_pushstring(L, sel_getName(method_getName(method)));
        lua_rawseti(L, -2, i + 1);
    }
    
    return 1;
}

#pragma mark Function Closures
#pragma mark ----------------------

static int methodClosure(lua_State *L) {
    //NSLog(@"methodClosure");
    if (![[NSThread currentThread] isEqual:[NSThread mainThread]]) NSLog(@"METHODCLOSURE: OH NO SEPERATE THREAD");
    
    const char *selectorName = luaL_checkstring(L, lua_upvalueindex(1));
    
    //armstrong
#ifdef Lua_Nil_Protection
    //get the mark from global variables, judge if it's a nil's invocation.
    BOOL isReplacedInstance = NO;
    wax_instance_userdata *instanceUserdata = NULL;
    BOOL isReplacement = NO;
    lua_getglobal(L, "initReplaceTag");
    if (lua_isboolean(L, -1) && strcmp(selectorName, "init")==0) {  //init is the replaced method
        //get the mark, then remove it from global variables.
        isReplacement = lua_toboolean(L, -1);
        lua_pushnil(L);
        lua_setglobal(L, "initReplaceTag");
        lua_settop(L, lua_gettop(L) - 1);
    }
    else {
        //no mark, we need to remove the nil from stack
        lua_settop(L, lua_gettop(L) - 1);
    }
    
    if (lua_isuserdata(L, 1)) {
        instanceUserdata = (wax_instance_userdata *)luaL_checkudata(L, 1, WAX_INSTANCE_METATABLE_NAME);
    }
    else {
        //        NSLog(@"非userdata 的方法调用，用一个NSObject 替代");
        wax_instance_userdata data;
        data.instance =[[NSObject new] autorelease];
        data.isClass = NO;
        data.isSuper = nil;
        data.actAsSuper = NO;
        instanceUserdata = &data;
        isReplacedInstance = YES;
    }
#else
    wax_instance_userdata *instanceUserdata = (wax_instance_userdata *)luaL_checkudata(L, 1, WAX_INSTANCE_METATABLE_NAME);
#endif
    
    // If the only arg is 'self' and there is a selector with no args. USE IT!
    if (lua_gettop(L) == 1 && lua_isstring(L, lua_upvalueindex(2))) {
        selectorName = luaL_checkstring(L, lua_upvalueindex(2));
    }
    //NSLog(@"methodClosure %s",selectorName);
    //NSString *method = [NSString stringWithFormat:@"%s",selectorName];
    SEL selector = sel_getUid(selectorName);
    id instance = instanceUserdata->instance;
    BOOL autoAlloc = NO;
    
    // If init is called on a class, auto-allocate it.
    if (instanceUserdata->isClass && wax_isInitMethod(selectorName)) {
        autoAlloc = YES;
        instance = [instance alloc];
    }
    
    NSMethodSignature *signature = [instance methodSignatureForSelector:selector];
    if (!signature) {
        const char *className = [NSStringFromClass([instance class]) UTF8String];
        luaL_error(L, "'%s' has no method selector '%s'", className, selectorName);
    }
    
    NSInvocation *invocation = nil;
    invocation = [NSInvocation invocationWithMethodSignature:signature];
    
    [invocation setTarget:instance];
    [invocation setSelector:selector];
    
    int objcArgumentCount = [signature numberOfArguments] - 2; // skip the hidden self and _cmd argument
    int luaArgumentCount = lua_gettop(L) - 1;
    
    //armstrong
    //if it's a exception replacement, the argument count won't be right.
    //so we need to set it to jump the error.
#ifdef Lua_Nil_Protection
    if (isReplacedInstance) {
        luaArgumentCount = 100;
        objcArgumentCount = 0;
    }
#endif
    
    
    if (objcArgumentCount > luaArgumentCount && !wax_instance_isWaxClass(instance)) {
        luaL_error(L, "Not Enough arguments given! Method named '%s' requires %d argument(s), you gave %d. (Make sure you used ':' to call the method)", selectorName, objcArgumentCount + 1, lua_gettop(L));
    }
    
    
    
    void **arguements = calloc(sizeof(void*), objcArgumentCount);
    for (int i = 0; i < objcArgumentCount; i++) {
        arguements[i] = wax_copyToObjc(L, [signature getArgumentTypeAtIndex:i + 2], i + 2, nil);
        [invocation setArgument:arguements[i] atIndex:i + 2];
    }
    
    @try {
        [invocation invoke];
    }
    @catch (NSException *exception) {
        luaL_error(L, "Error invoking method '%s' on '%s' because %s", selector, class_getName([instance class]), [[exception description] UTF8String]);
    }
    
    for (int i = 0; i < objcArgumentCount; i++) {
        free(arguements[i]);
    }
    free(arguements);
    
    int methodReturnLength = [signature methodReturnLength];
    if (methodReturnLength > 0) {
        void *buffer = calloc(1, methodReturnLength);
        //armstrong
#ifdef Lua_Nil_Protection
        //if the target is replaced, means invoking nil's method; so we return a nil value.
        if (!isReplacedInstance) {
            [invocation getReturnValue:buffer];
        }
        else {
            memset(buffer, 0, methodReturnLength);
        }
#else
        [invocation getReturnValue:buffer];
#endif
        
        wax_fromObjc(L, [signature methodReturnType], buffer);
        
        if (autoAlloc) {
            if (lua_isnil(L, -1)) {
                // The init method returned nil... means initialization failed!
                // Remove it from the userdataTable (We don't ever want to clean up after this... it should have cleaned up after itself)
                wax_instance_pushUserdataTable(L);
                lua_pushlightuserdata(L, instance);
                lua_pushnil(L);
                lua_rawset(L, -3);
                lua_pop(L, 1); // Pop the userdataTable
                lua_pushnil(L);
                [instance release];
            }
            else {
                wax_instance_userdata *returnedInstanceUserdata = (wax_instance_userdata *)lua_topointer(L, -1);
                if (returnedInstanceUserdata) { // Could return nil
                    [returnedInstanceUserdata->instance release]; // Wax automatically retains a copy of the object, so the alloc needs to be released
                }
            }
        }
        
        free(buffer);
    }
    
    return 1;
}

static int superMethodClosure(lua_State *L) {
    wax_instance_userdata *instanceUserdata = (wax_instance_userdata *)luaL_checkudata(L, 1, WAX_INSTANCE_METATABLE_NAME);
    const char *selectorName = luaL_checkstring(L, lua_upvalueindex(1));
    
    // If the only arg is 'self' and there is a selector with no args. USE IT!
    if (lua_gettop(L) == 1 && lua_isstring(L, lua_upvalueindex(2))) {
        selectorName = luaL_checkstring(L, lua_upvalueindex(2));
    }
    
    SEL selector = sel_getUid(selectorName);
    
    // Super Swizzle
    Method selfMethod = class_getInstanceMethod([instanceUserdata->instance class], selector);
    Method superMethod = class_getInstanceMethod(instanceUserdata->isSuper, selector);
    
    if (superMethod && selfMethod != superMethod) { // Super's got what you're looking for
        IMP selfMethodImp = method_getImplementation(selfMethod);
        IMP superMethodImp = method_getImplementation(superMethod);
        method_setImplementation(selfMethod, superMethodImp);
        
        methodClosure(L);
        
        method_setImplementation(selfMethod, selfMethodImp); // Swap back to self's original method
    }
    else {
        methodClosure(L);
    }
    
    return 1;
}

static int customInitMethodClosure(lua_State *L) {
    wax_instance_userdata *classInstanceUserdata = (wax_instance_userdata *)luaL_checkudata(L, 1, WAX_INSTANCE_METATABLE_NAME);
    wax_instance_userdata *instanceUserdata = nil;
    
    id instance = nil;
    BOOL shouldRelease = NO;
    if (classInstanceUserdata->isClass) {
        shouldRelease = YES;
        instance = [classInstanceUserdata->instance alloc];

        instanceUserdata = wax_instance_create(L, instance, NO);
        lua_replace(L, 1); // replace the old userdata with the new one!
    }
    else {
        luaL_error(L, "I WAS TOLD THIS WAS A CUSTOM INIT METHOD. BUT YOU LIED TO ME");
        return -1;
    }
    
    lua_pushvalue(L, lua_upvalueindex(1)); // Grab the function!
    lua_insert(L, 1); // push it up top
    
    if (wax_pcall(L, lua_gettop(L) - 1, 1)) {
        const char* errorString = lua_tostring(L, -1);
        luaL_error(L, "Custom init method on '%s' failed.\n%s", class_getName([instanceUserdata->instance class]), errorString);
    }
    
    if (shouldRelease) {
        [instance release];
    }
    
    if (lua_isnil(L, -1)) { // The init method returned nil... return the instanceUserdata instead
        luaL_error(L, "Init method must return the self");
    }
    
    return 1;
}

#pragma mark Override Methods
#pragma mark ---------------------

#define GET_FLOAT(index) getFloat##index()
#define GET_DOUBLE(index) getDouble##index()

#if defined(__arm64__)
#define ASM_STRING0 "sub sp, sp, #16\n  str s0,[sp,#0]\n    ldr s0, [sp, #0]\n  add sp, sp, #16\n   ret\n"
#define ASM_STRING1 "sub sp, sp, #16\n  str s1,[sp,#0]\n    ldr s0, [sp, #0]\n  add sp, sp, #16\n   ret\n"
#define ASM_STRING2 "sub sp, sp, #16\n  str s2,[sp,#0]\n    ldr s0, [sp, #0]\n  add sp, sp, #16\n   ret\n"
#define ASM_STRING3 "sub sp, sp, #16\n  str s3,[sp,#0]\n    ldr s0, [sp, #0]\n  add sp, sp, #16\n   ret\n"
#define ASM_STRING4 "sub sp, sp, #16\n  str s4,[sp,#0]\n    ldr s0, [sp, #0]\n  add sp, sp, #16\n   ret\n"
#define ASM_STRING5 "sub sp, sp, #16\n  str s5,[sp,#0]\n    ldr s0, [sp, #0]\n  add sp, sp, #16\n   ret\n"
#define ASM_STRING6 "sub sp, sp, #16\n  str s6,[sp,#0]\n    ldr s0, [sp, #0]\n  add sp, sp, #16\n   ret\n"
#define ASM_STRING7 "sub sp, sp, #16\n  str s7,[sp,#0]\n    ldr s0, [sp, #0]\n  add sp, sp, #16\n   ret\n"

#elif defined(__x86_64__)
#define ASM_STRING0 "movq %xmm0,%xmm0\n     retq\n"
#define ASM_STRING1 "movq %xmm1,%xmm0\n     retq\n"
#define ASM_STRING2 "movq %xmm2,%xmm0\n     retq\n"
#define ASM_STRING3 "movq %xmm3,%xmm0\n     retq\n"
#define ASM_STRING4 "movq %xmm4,%xmm0\n     retq\n"
#define ASM_STRING5 "movq %xmm5,%xmm0\n     retq\n"
#define ASM_STRING6 "movq %xmm6,%xmm0\n     retq\n"
#define ASM_STRING7 "movq %xmm7,%xmm0\n     retq\n"
#endif

#if defined(__arm64__) || defined(__x86_64__)
#define NAKED_GET_FLOAT(index)                          \
__attribute__((naked)) float getFloat##index()          \
{                                                       \
__asm__ __volatile__(ASM_STRING##index);            \
}

#define NAKED_GET_DOUBLE(index)                         \
__attribute__((naked)) double getDouble##index()        \
{                                                       \
__asm__ __volatile__(ASM_STRING##index);            \
}

NAKED_GET_FLOAT(0)
NAKED_GET_FLOAT(1)
NAKED_GET_FLOAT(2)
NAKED_GET_FLOAT(3)
NAKED_GET_FLOAT(4)
NAKED_GET_FLOAT(5)
NAKED_GET_FLOAT(6)
NAKED_GET_FLOAT(7)
NAKED_GET_DOUBLE(0)
NAKED_GET_DOUBLE(1)
NAKED_GET_DOUBLE(2)
NAKED_GET_DOUBLE(3)
NAKED_GET_DOUBLE(4)
NAKED_GET_DOUBLE(5)
NAKED_GET_DOUBLE(6)
NAKED_GET_DOUBLE(7)
#endif

typedef struct _buffer_16 {char b[16];} buffer_16;
typedef struct _buffer_32 {char b[32];} buffer_32;

static void *globalPoint = NULL;
static BOOL invalidInvocation = NO;

void myForwardInvocation(id self, SEL _cmd, NSInvocation * inv){
    NSInteger n = [[inv methodSignature] numberOfArguments];
    WaxArguments * list = NewArgumentList();
    //HACK
    const char *selectorName = sel_getName([inv selector]);
    char newWaxSelectorName[strlen(selectorName) + 10];
    strcpy(newWaxSelectorName, "WAX");
    strcat(newWaxSelectorName, selectorName);
    SEL newWaxSelector = sel_getUid(newWaxSelectorName);
    
    NSMethodSignature *signature = [self methodSignatureForSelector:newWaxSelector];
    void * value = NULL;
    for (int i = 0; i < n-2; i++) {
        const char *type = [signature getArgumentTypeAtIndex:i+2];
        int size = wax_sizeOfTypeDescription(type);
        if (type[0] == WAX_TYPE_STRUCT) {
            if (size == 16) {
                buffer_16* arg = malloc(sizeof(buffer_16));
                [inv getArgument:arg atIndex:(int)i+2];
                addArgument(list, arg);
            }
            else if (size == 32) {
                buffer_32* arg = malloc(sizeof(buffer_32));
                [inv getArgument:arg atIndex:(int)i+2];
                addArgument(list, arg);
            }
        } else {
            if (type[0] == WAX_TYPE_UNSIGNED_LONG_LONG) {
                UInt64 *longValue = malloc(sizeof(UInt64));
                [inv getArgument:longValue atIndex:(int)i+2];
                addArgument(list, longValue);
            }
            else if (type[0] == WAX_TYPE_LONG_LONG) {
                long long *value = malloc(sizeof(long long));
                [inv getArgument:value atIndex:(int)i+2];
                addArgument(list, value);
            }
            else if (type[0] == WAX_TYPE_C99_BOOL) {
                BOOL *boolValue = malloc(sizeof(BOOL));
                [inv getArgument:boolValue atIndex:(int)i+2];
                addArgument(list, boolValue);
            }
            else if (type[0] == WAX_TYPE_INT) {
                int *intValue = malloc(sizeof(int));
                [inv getArgument:intValue atIndex:(int)i+2];
                addArgument(list, intValue);
                
            }
            else if (type[0] == WAX_TYPE_FLOAT) {
                float *floatValue = malloc(sizeof(float));
                [inv getArgument:floatValue atIndex:(int)i+2];
                addArgument(list, floatValue);
            }
            else if (type[0] == WAX_TYPE_DOUBLE) {
                double *doubleValue = malloc(sizeof(double));
                [inv getArgument:doubleValue atIndex:(int)i+2];
                addArgument(list, doubleValue);
            }
            else {
                id arg;
                [inv getArgument:&arg atIndex:(int)i+2];
                if(!arg){
                    //                    arg = [NSNull null];
                }
                if (arg) {
                    value = calloc(sizeof([arg class]), 1);
                    *(id*)value = arg;
                }
                else {
                    value = NULL;
                }
                addArgument(list, value);
            }
        }
    }
    if(class_respondsToSelector([[inv target] class], newWaxSelector)) {
        if([[inv methodSignature]numberOfArguments] > 2){
            [inv setArgument:&list atIndex:2];
            globalPoint = list;
        }
        [inv setSelector:newWaxSelector];
        [inv invoke];
    }else{
        if(class_respondsToSelector([[inv target]class], @selector(ORIGforwardInvocation:))){
            [inv setSelector:@selector(ORIGforwardInvocation:)];
            invalidInvocation = YES;
            [inv invoke];
        }
    }
    freeArguments(list);
}


#if defined(__arm64__) || defined(__x86_64__)
static int pcallUserdata_arm64(lua_State *L, id self, SEL selector, struct WaxArguments * arguments) {
    BEGIN_STACK_MODIFY(L)
    arguments = globalPoint; globalPoint = NULL;
    //无效的api调用，忽略之
    if (invalidInvocation) {
        invalidInvocation = NO;
        
        return 0;
    }
    
    if (![[NSThread currentThread] isEqual:[NSThread mainThread]]) NSLog(@"PCALLUSERDATA: OH NO SEPERATE THREAD");
    
    // A WaxClass could have been created via objective-c (like via NSKeyUnarchiver)
    // In this case, no lua object was ever associated with it, so we've got to
    // create one.
    if (wax_instance_isWaxClass(self)) {
        // NSLog(@"wax_instance_create wax_instance_isWaxClass");
        BOOL isClass = self == [self class];
        wax_instance_create(L, self, isClass); // If it already exists, then it will just return without doing anything
        lua_pop(L, 1); // Pops userdata off
    }
    
    const char *selectorName = sel_getName(selector);
    if (strncmp(selectorName, "WAX", 3)==0){
        char* newSelectorName = selectorName+3;
        SEL newSelector = sel_getUid(newSelectorName);
        selector = newSelector;
    }
    
    // Find the function... could be in the object or in the class
    if (!wax_instance_pushFunction(L, self, selector)) {
        lua_pushfstring(L, "Could not find function named \"%s\" associated with object %s(%p).(It may have been released by the GC)", selector, class_getName([self class]), self);
        goto error; // function not found in userdata...
    }
    
    // Push userdata as the first argument
    wax_fromInstance(L, self);
    if (lua_isnil(L, -1)) {
        lua_pushfstring(L, "Could not convert '%s' into lua", class_getName([self class]));
        goto error;
    }
    
    NSMethodSignature *signature = [self methodSignatureForSelector:selector];
    int nargs = [signature numberOfArguments] - 1; // Don't send in the _cmd argument, only self
    int nresults = [signature methodReturnLength] ? 1 : 0;
    
    
    
    WaxArgument * args;
    if(nargs > 1){
        args = arguments->first;
    }
    for (int i = 2; i < [signature numberOfArguments]; i++) { // start at 2 because to skip the automatic self and _cmd arugments
        const char *type = [signature getArgumentTypeAtIndex:i];
        if(strstr(type, "NSRange") > 0) {
            type =  "{NSRange=QQ}";
        }
        wax_fromObjc_NWax(L, type, args->data);
        args=args->next;
    }
    
    if (wax_pcall(L, nargs, nresults)) { // Userdata will allways be the first object sent to the function
        goto error;
    }
    
    END_STACK_MODIFY(L, nresults)
    return nresults;
    
error:
    END_STACK_MODIFY(L, 1)
    return -1;
}

#else
static int pcallUserdata(lua_State *L, id self, SEL selector, va_list args) {
    BEGIN_STACK_MODIFY(L)
    
    BOOL bMainThread = [[NSThread currentThread] isEqual:[NSThread mainThread]];
    if (!bMainThread)
    {
        wax_log(LOG_DEBUG, @"PCALLUSERDATA: OH NO SEPERATE THREAD");
        lua_pushfstring(L, "PCALLUSERDATA: OH NO SEPERATE THREAD");
        lua_error(wax_currentLuaState());
    }
    
    
    
    
    // A WaxClass could have been created via objective-c (like via NSKeyUnarchiver)
    // In this case, no lua object was ever associated with it, so we've got to
    // create one.
    if (wax_instance_isWaxClass(self)) {
        // NSLog(@"wax_instance_create wax_instance_isWaxClass");
        BOOL isClass = self == [self class];
        wax_instance_create(L, self, isClass); // If it already exists, then it will just return without doing anything
        lua_pop(L, 1); // Pops userdata off
    }
    
    // Find the function... could be in the object or in the class
    if (!wax_instance_pushFunction(L, self, selector)) {
        lua_pushfstring(L, "Could not find function named \"%s\" associated with object %s(%p).(It may have been released by the GC)", selector, class_getName([self class]), self);
        goto error; // function not found in userdata...
    }
    
    // Push userdata as the first argument
    wax_fromInstance(L, self);
    if (lua_isnil(L, -1)) {
        lua_pushfstring(L, "Could not convert '%s' into lua", class_getName([self class]));
        goto error;
    }
    
    NSMethodSignature *signature = [self methodSignatureForSelector:selector];
    int nargs = [signature numberOfArguments] - 1; // Don't send in the _cmd argument, only self
    int nresults = [signature methodReturnLength] ? 1 : 0;
    
    for (int i = 2; i < [signature numberOfArguments]; i++) { // start at 2 because to skip the automatic self and _cmd arugments
        const char *type = [signature getArgumentTypeAtIndex:i];
        int size = wax_fromObjc(L, type, args);
        args += size; // HACK! Since va_arg requires static type, I manually increment the args
    }
    
    if (wax_pcall(L, nargs, nresults)) { // Userdata will allways be the first object sent to the function
        goto error;
    }
    
    END_STACK_MODIFY(L, nresults)
    return nresults;
    
error:
    END_STACK_MODIFY(L, 1)
    return -1;
}

#endif


/*
 5.3.0版本和之前版本这里有问题，执行脚本中的函数若失败，resulte为-1,失败处理逻辑里面把luaL_error注释掉了，目的是想让脚本的
 问题不至于导到整个手Q crash的，这会打乱oc运行时的逻辑,就像如果oc中例如ViewDidLoad若失败了，那怎么善后，只能让它crash
 同样这里也是如此，脚本也是转换成这样oc方法来执行，出了问题也只能crash了。所以这里把它放开,否则不好处理，如果直接返回，那个函数是要返回参数的怎办，如果不直接返回，那下面又要去取返回值，但这个返函数执行的时候就出问题了根本就没值返回，下面去取值必定有问题，还不如直接crash爆露脚本的问题，上报到rdm
 */

#define WAX_METHOD_NAME(_type_) wax_##_type_##_call



#if defined(__arm64__) || defined(__x86_64__)  //arm64


#define WAX_METHOD(_type_) \
static _type_ WAX_METHOD_NAME(_type_)(id self, SEL _cmd, struct Arguments * args) { \
/* Grab the static L... this is a hack */ \
lua_State *L = wax_currentLuaState(); \
BEGIN_STACK_MODIFY(L); \
int result = pcallUserdata_arm64(L, self, _cmd, args); \
if (result == -1) { \
luaL_error(L, "Error calling '%s' on '%s'\n%s", _cmd, [[self description] UTF8String], lua_tostring(L, -1)); \
} \
else if (result == 0) { \
_type_ returnValue; \
bzero(&returnValue, sizeof(_type_)); \
END_STACK_MODIFY(L, 0) \
return returnValue; \
} \
\
NSMethodSignature *signature = [self methodSignatureForSelector:_cmd]; \
_type_ *pReturnValue = (_type_ *)wax_copyToObjc(L, [signature methodReturnType], -1, nil); \
_type_ returnValue = *pReturnValue; \
free(pReturnValue); \
END_STACK_MODIFY(L, 0) \
return returnValue; \
}


#else   //armv7

#define WAX_METHOD(_type_) \
static _type_ WAX_METHOD_NAME(_type_)(id self, SEL _cmd, ...) { \
va_list args; \
va_start(args, _cmd); \
va_list args_copy; \
va_copy(args_copy, args); \
/* Grab the static L... this is a hack */ \
lua_State *L = wax_currentLuaState(); \
BEGIN_STACK_MODIFY(L); \
int result = pcallUserdata(L, self, _cmd, args_copy); \
va_end(args_copy); \
va_end(args); \
if (result == -1) { \
wax_printStack(L); \
NSLog(@"/************\r\nError calling '%s' on '%s'\n%s\r\n***************/", [NSStringFromSelector(_cmd) UTF8String], [[self description] UTF8String], lua_tostring(L, -1));  \
luaL_error(L, "Error calling '%s' on '%s'\n%s", [NSStringFromSelector(_cmd) UTF8String], [[self description] UTF8String], lua_tostring(L, -1)); \
} \
else if (result == 0) { \
_type_ returnValue; \
bzero(&returnValue, sizeof(_type_)); \
END_STACK_MODIFY(L, 0) \
return returnValue; \
} \
\
NSMethodSignature *signature = [self methodSignatureForSelector:_cmd]; \
_type_ *pReturnValue = (_type_ *)wax_copyToObjc(L, [signature methodReturnType], -1, nil); \
_type_ returnValue = *pReturnValue; \
free(pReturnValue); \
END_STACK_MODIFY(L, 0) \
return returnValue; \
}

#endif

//typedef struct _buffer_16 {char b[16];} buffer_16;
//typedef struct _buffer_32 {char b[32];} buffer_32;

WAX_METHOD(buffer_16)
WAX_METHOD(buffer_32)
WAX_METHOD(id)
WAX_METHOD(int)
WAX_METHOD(long)
WAX_METHOD(float)
WAX_METHOD(double)
WAX_METHOD(BOOL)

#if defined(__arm64__) || defined(__x86_64__)    //x86 //arm64
// Only allow classes to do this
static BOOL overrideMethod(lua_State *L, wax_instance_userdata *instanceUserdata) {
    BEGIN_STACK_MODIFY(L);
    BOOL success = NO;
    const char *methodName = lua_tostring(L, 2);
    SEL foundSelectors[2] = {nil, nil};
    wax_selectorForInstance(instanceUserdata, foundSelectors, methodName, YES);
    SEL selector = foundSelectors[0];
    if (foundSelectors[1]) {
        //NSLog(@"Found two selectors that match %s. Defaulting to %s over %s", methodName, foundSelectors[0], foundSelectors[1]);
    }
    
    Class klass = [instanceUserdata->instance class];
    
    if(!class_getClassMethod(klass, @selector(ORIGforwardInvocation:))){
        IMP forwardInvocationOriginalImp = class_replaceMethod(klass, @selector(forwardInvocation:), (IMP)myForwardInvocation, "v@:@");
        class_addMethod(klass, @selector(ORIGforwardInvocation:), forwardInvocationOriginalImp, "v@:@");
    }
    
    id metaclass = objc_getMetaClass(object_getClassName(klass));
    if(!class_getClassMethod(metaclass, @selector(ORIGforwardInvocation:))){
        IMP forwardInvocationOriginalImp = class_replaceMethod(metaclass, @selector(forwardInvocation:), (IMP)myForwardInvocation, "v@:@");
        class_addMethod(metaclass, @selector(ORIGforwardInvocation:), forwardInvocationOriginalImp, "v@:@");
    }
    
    
    char *typeDescription = nil;
    char *returnType = nil;
    
    Method method = class_getInstanceMethod(klass, selector);
    
    if (method) { // Is method defined in the superclass?
        typeDescription = (char *)method_getTypeEncoding(method);
        returnType = method_copyReturnType(method);
    }
    else { // Is this method implementing a protocol?
        Class currentClass = klass;
        
        while (!returnType && [currentClass superclass] != [currentClass class]) { // Walk up the object heirarchy
            uint count;
            Protocol **protocols = class_copyProtocolList(currentClass, &count);
            
            SEL possibleSelectors[3];
            wax_selectorsForName(methodName, possibleSelectors);
            
            for (int i = 0; !returnType && i < count; i++) {
                Protocol *protocol = protocols[i];
                struct objc_method_description m_description;
                
                for (int j = 0; !returnType && j < 3; j++) {
                    selector = possibleSelectors[j];
                    if (!selector) continue; // There may be only one acceptable selector sent back
                    
                    m_description = protocol_getMethodDescription(protocol, selector, YES, YES);
                    if (!m_description.name) m_description = protocol_getMethodDescription(protocol, selector, NO, YES); // Check if it is not a "required" method
                    
                    if (m_description.name) {
                        typeDescription = m_description.types;
                        returnType = method_copyReturnType((Method)&m_description);
                    }
                }
            }
            
            free(protocols);
            
            currentClass = [currentClass superclass];
        }
    }
    
    if (returnType) { // Matching method found! Create an Obj-C method on the
        if (!instanceUserdata->isClass) {
            luaL_error(L, "Trying to override method '%s' on an instance. You can only override classes", methodName);
        }
        
        const char *simplifiedReturnType = wax_removeProtocolEncodings(returnType);
        IMP imp;
        switch (simplifiedReturnType[0]) {
            case WAX_TYPE_VOID:
            case WAX_TYPE_ID:
                imp = (IMP)WAX_METHOD_NAME(id);
                break;
                
            case WAX_TYPE_CHAR:
            case WAX_TYPE_INT:
            case WAX_TYPE_SHORT:
            case WAX_TYPE_UNSIGNED_CHAR:
            case WAX_TYPE_UNSIGNED_INT:
            case WAX_TYPE_UNSIGNED_SHORT:
                imp = (IMP)WAX_METHOD_NAME(int);
                break;
                
            case WAX_TYPE_LONG:
            case WAX_TYPE_LONG_LONG:
            case WAX_TYPE_UNSIGNED_LONG:
            case WAX_TYPE_UNSIGNED_LONG_LONG:
                imp = (IMP)WAX_METHOD_NAME(long);
                break;
                
            case WAX_TYPE_FLOAT:
                imp = (IMP)WAX_METHOD_NAME(float);
                break;
            case WAX_TYPE_DOUBLE:
                imp = (IMP)WAX_METHOD_NAME(double);
                break;
                
            case WAX_TYPE_C99_BOOL:
                imp = (IMP)WAX_METHOD_NAME(BOOL);
                break;
                
            case WAX_TYPE_STRUCT: {
                int size = wax_sizeOfTypeDescription(simplifiedReturnType);
                switch (size) {
                    case 16:
                        imp = (IMP)WAX_METHOD_NAME(buffer_16);
                        break;
                    case 32:
                        imp = (IMP)WAX_METHOD_NAME(buffer_32);
                        break;
                    default:
                        luaL_error(L, "Trying to override a method that has a struct return type of size '%d'. There is no implementation for this size yet.", size);
                        return NO;
                        break;
                }
                break;
            }
            default:
                luaL_error(L, "Can't override method with return type %s", simplifiedReturnType);
                return NO;
                break;
        }
        id metaclass = objc_getMetaClass(object_getClassName(klass));
#if 0
        success = class_addMethod(klass, selector, imp, typeDescription) && class_addMethod(metaclass, selector, imp, typeDescription);
#else  //不存在，则添加、存在则overwrite ,支持lua打补丁的能力
        
        IMP instImp = class_respondsToSelector(klass, selector) ? class_getMethodImplementation(klass, selector) : NULL;
        IMP metaImp = class_respondsToSelector(metaclass, selector) ? class_getMethodImplementation(metaclass, selector) : NULL;
        if(instImp) {
            // original selector is reserved in ORIGxxxx
            //Strong HACK!!! I can't stress enough how hacky this is! I'm removing the original method implementation so that when it is called, the call gets forwarded by mine myForwardInvocation
            IMP prevImp = class_replaceMethod(klass, selector, class_getMethodImplementation(klass, @selector(testesss)), typeDescription);
            
            const char *selectorName = sel_getName(selector);
            //New
            char newWaxSelectorName[strlen(selectorName) + 10];
            strcpy(newWaxSelectorName, "WAX");
            strcat(newWaxSelectorName, selectorName);
            
            char newSelectorName[strlen(selectorName) + 10];
            strcpy(newSelectorName, "ORIG");
            strcat(newSelectorName, selectorName);
            SEL newSelector = sel_getUid(newSelectorName);
            if(!class_respondsToSelector(klass, newSelector)) {
                class_addMethod(klass, newSelector, prevImp, typeDescription);
            }
            
            //New
            SEL newWaxSelector = sel_getUid(newWaxSelectorName);
            if(!class_respondsToSelector(klass, newWaxSelector)) {
                class_addMethod(klass, newWaxSelector, imp, typeDescription);
            }
            success = YES;
        } else if(metaImp) {
            //Strong HACK!!! I can't stress enough how hacky this is! I'm removing the original method implementation so that when it is called, the call gets forwarded by mine myForwardInvocation
            IMP prevImp = class_replaceMethod(metaclass, selector, class_getMethodImplementation(metaclass, @selector(testesss)), typeDescription);
            
            const char *selectorName = sel_getName(selector);
            char newWaxSelectorName[strlen(selectorName) + 10];
            strcpy(newWaxSelectorName, "WAX");
            strcat(newWaxSelectorName, selectorName);
            SEL newWaxSelector = sel_getUid(newWaxSelectorName);
            if(!class_respondsToSelector(metaclass, newWaxSelector)) {
                class_addMethod(metaclass, newWaxSelector, imp, typeDescription);
            }
            
            char newSelectorName[strlen(selectorName) + 10];
            strcpy(newSelectorName, "ORIG");
            strcat(newSelectorName, selectorName);
            SEL newSelector = sel_getUid(newSelectorName);
            if(!class_respondsToSelector(metaclass, newSelector)) {
                class_addMethod(metaclass, newSelector, prevImp, typeDescription);
            }
            
            success = YES;
        } else {
            // add to both instance and class method
            const char *selectorName = sel_getName(selector);
            char newWaxSelectorName[strlen(selectorName) + 10];
            strcpy(newWaxSelectorName, "WAX");
            strcat(newWaxSelectorName, selectorName);
            SEL newWaxSelector = sel_getUid(newWaxSelectorName);
            
            success = class_addMethod(klass, selector, class_getMethodImplementation(klass, @selector(testesss)), typeDescription) && class_addMethod(metaclass, selector, class_getMethodImplementation(klass, @selector(testesss)), typeDescription);
            
            success = class_addMethod(klass, newWaxSelector, imp, typeDescription) && class_addMethod(metaclass, newWaxSelector, imp, typeDescription);
        }
    }
    else {
        SEL possibleSelectors[2];
        wax_selectorsForName(methodName, possibleSelectors);
        
        success = YES;
        for (int i = 0; i < 2; i++) {
            selector = possibleSelectors[i];
            if (!selector) continue; // There may be only one acceptable selector sent back
            
            int argCount = 0;
            char *match = (char *)sel_getName(selector);
            while ((match = strchr(match, ':'))) {
                match += 1; // Skip past the matched char
                argCount++;
            }
            
            size_t typeDescriptionSize = 3 + argCount;
            typeDescription = calloc(typeDescriptionSize + 1, sizeof(char));
            memset(typeDescription, '@', typeDescriptionSize);
            typeDescription[2] = ':'; // Never forget _cmd!
            
            IMP imp = (IMP)WAX_METHOD_NAME(id);
            id metaclass = objc_getMetaClass(object_getClassName(klass));
            
#if 0
            success = success &&
            class_addMethod(klass, possibleSelectors[i], imp, typeDescription) &&
            class_addMethod(metaclass, possibleSelectors[i], imp, typeDescription);
#else
            
            IMP instImp = class_respondsToSelector(klass, selector) ? class_getMethodImplementation(klass, selector) : NULL;
            IMP metaImp = class_respondsToSelector(metaclass, selector) ? class_getMethodImplementation(metaclass, selector) : NULL;
            if(instImp) {
                // original selector is reserved in ORIGxxxx
                IMP prevImp = class_replaceMethod(klass, selector, class_getMethodImplementation(klass, @selector(testesss)), typeDescription);
                
                const char *selectorName = sel_getName(selector);
                char newWaxSelectorName[strlen(selectorName) + 10];
                strcpy(newWaxSelectorName, "WAX");
                strcat(newWaxSelectorName, selectorName);
                SEL newWaxSelector = sel_getUid(newWaxSelectorName);
                if(!class_respondsToSelector(klass, newWaxSelector)) {
                    class_addMethod(klass, newWaxSelector, imp, typeDescription);
                }
                
                char newSelectorName[strlen(selectorName) + 10];
                strcpy(newSelectorName, "ORIG");
                strcat(newSelectorName, selectorName);
                SEL newSelector = sel_getUid(newSelectorName);
                if(!class_respondsToSelector(klass, newSelector)) {
                    class_addMethod(klass, newSelector, prevImp, typeDescription);
                }
                success = YES;
            } else if(metaImp) {
                IMP prevImp = class_replaceMethod(metaclass, selector, class_getMethodImplementation(metaclass, @selector(testesss)), typeDescription);
                
                const char *selectorName = sel_getName(selector);
                char newWaxSelectorName[strlen(selectorName) + 10];
                strcpy(newWaxSelectorName, "WAX");
                strcat(newWaxSelectorName, selectorName);
                SEL newWaxSelector = sel_getUid(newWaxSelectorName);
                if(!class_respondsToSelector(metaclass, newWaxSelector)) {
                    class_addMethod(metaclass, newWaxSelector, imp, typeDescription);
                }
                
                char newSelectorName[strlen(selectorName) + 10];
                strcpy(newSelectorName, "ORIG");
                strcat(newSelectorName, selectorName);
                SEL newSelector = sel_getUid(newSelectorName);
                if(!class_respondsToSelector(metaclass, newSelector)) {
                    class_addMethod(metaclass, newSelector, prevImp, typeDescription);
                }
                success = YES;
            } else {
                // add to both instance and class method
                const char *selectorName = sel_getName(selector);
                char newWaxSelectorName[strlen(selectorName) + 10];
                strcpy(newWaxSelectorName, "WAX");
                strcat(newWaxSelectorName, selectorName);
                
                SEL newWaxSelector = sel_getUid(newWaxSelectorName);
                success = class_addMethod(klass, selector, class_getMethodImplementation(klass, @selector(testesss)), typeDescription) && class_addMethod(metaclass, selector, class_getMethodImplementation(klass, @selector(testesss)), typeDescription);
                
                success = class_addMethod(klass, newWaxSelector, imp, typeDescription) && class_addMethod(metaclass, newWaxSelector, imp, typeDescription);
            }
#endif
#endif
            
            free(typeDescription);
        }
    }
    
    END_STACK_MODIFY(L, 1)
    return success;
}

#else
static BOOL overrideMethod(lua_State *L, wax_instance_userdata *instanceUserdata) {
    
    BEGIN_STACK_MODIFY(L);
    BOOL success = NO;
    const char *methodName = lua_tostring(L, 2);
    SEL foundSelectors[2] = {nil, nil};
    wax_selectorForInstance(instanceUserdata, foundSelectors, methodName, YES);
    SEL selector = foundSelectors[0];
    if (foundSelectors[1]) {
        //NSLog(@"Found two selectors that match %s. Defaulting to %s over %s", methodName, foundSelectors[0], foundSelectors[1]);
    }
    
    Class klass = [instanceUserdata->instance class];
    
    char *typeDescription = nil;
    char *returnType = nil;
    
    Method method = class_getInstanceMethod(klass, selector);
    
    if (method) { // Is method defined in the superclass?
        typeDescription = (char *)method_getTypeEncoding(method);
        returnType = method_copyReturnType(method);
    }
    else { // Is this method implementing a protocol?
        Class currentClass = klass;
        
        while (!returnType && [currentClass superclass] != [currentClass class]) { // Walk up the object heirarchy
            uint count;
            Protocol **protocols = class_copyProtocolList(currentClass, &count);
            
            SEL possibleSelectors[3];
            wax_selectorsForName(methodName, possibleSelectors);
            
            for (int i = 0; !returnType && i < count; i++) {
                Protocol *protocol = protocols[i];
                struct objc_method_description m_description;
                
                for (int j = 0; !returnType && j < 3; j++) {
                    selector = possibleSelectors[j];
                    if (!selector) continue; // There may be only one acceptable selector sent back
                    
                    m_description = protocol_getMethodDescription(protocol, selector, YES, YES);
                    if (!m_description.name) m_description = protocol_getMethodDescription(protocol, selector, NO, YES); // Check if it is not a "required" method
                    
                    if (m_description.name) {
                        typeDescription = m_description.types;
                        returnType = method_copyReturnType((Method)&m_description);
                    }
                }
            }
            
            free(protocols);
            
            currentClass = [currentClass superclass];
        }
    }
    
    if (returnType) { // Matching method found! Create an Obj-C method on the
        if (!instanceUserdata->isClass) {
            luaL_error(L, "Trying to override method '%s' on an instance. You can only override classes", methodName);
        }
        
        const char *simplifiedReturnType = wax_removeProtocolEncodings(returnType);
        IMP imp;
        switch (simplifiedReturnType[0]) {
            case WAX_TYPE_VOID:
            case WAX_TYPE_ID:
                imp = (IMP)WAX_METHOD_NAME(id);
                break;
                
            case WAX_TYPE_CHAR:
            case WAX_TYPE_INT:
            case WAX_TYPE_SHORT:
            case WAX_TYPE_UNSIGNED_CHAR:
            case WAX_TYPE_UNSIGNED_INT:
            case WAX_TYPE_UNSIGNED_SHORT:
                imp = (IMP)WAX_METHOD_NAME(int);
                break;
                
            case WAX_TYPE_LONG:
            case WAX_TYPE_LONG_LONG:
            case WAX_TYPE_UNSIGNED_LONG:
            case WAX_TYPE_UNSIGNED_LONG_LONG:
                imp = (IMP)WAX_METHOD_NAME(long);
                break;
                
            case WAX_TYPE_FLOAT:
                imp = (IMP)WAX_METHOD_NAME(float);
                break;
            case WAX_TYPE_DOUBLE:
                imp = (IMP)WAX_METHOD_NAME(double);
                break;
                
            case WAX_TYPE_C99_BOOL:
                imp = (IMP)WAX_METHOD_NAME(BOOL);
                break;
                
            case WAX_TYPE_STRUCT: {
                int size = wax_sizeOfTypeDescription(simplifiedReturnType);
                switch (size) {
                    case 16:
                        imp = (IMP)WAX_METHOD_NAME(buffer_16);
                        break;
                    case 32:
                        imp = (IMP)WAX_METHOD_NAME(buffer_32);
                        break;
                    default:
                        luaL_error(L, "Trying to override a method that has a struct return type of size '%d'. There is no implementation for this size yet.", size);
                        return NO;
                        break;
                }
                break;
            }
                
            default:
                luaL_error(L, "Can't override method with return type %s", simplifiedReturnType);
                return NO;
                break;
        }
        
        id metaclass = objc_getMetaClass(object_getClassName(klass));
#if 0
        success = class_addMethod(klass, selector, imp, typeDescription) && class_addMethod(metaclass, selector, imp, typeDescription);
#else  //不存在，则添加、存在则overwrite ,支持lua打补丁的能力
        
        IMP instImp = class_respondsToSelector(klass, selector) ? class_getMethodImplementation(klass, selector) : NULL;
        IMP metaImp = class_respondsToSelector(metaclass, selector) ? class_getMethodImplementation(metaclass, selector) : NULL;
        if(instImp) {
            // original selector is reserved in ORIGxxxx
            IMP prevImp = class_replaceMethod(klass, selector, imp, typeDescription);
            const char *selectorName = sel_getName(selector);
            char newSelectorName[strlen(selectorName) + 10];
            strcpy(newSelectorName, "ORIG");
            strcat(newSelectorName, selectorName);
            SEL newSelector = sel_getUid(newSelectorName);
            if(!class_respondsToSelector(klass, newSelector)) {
                class_addMethod(klass, newSelector, prevImp, typeDescription);
            }
            success = YES;
        } else if(metaImp) {
            IMP prevImp = class_replaceMethod(metaclass, selector, imp, typeDescription);
            const char *selectorName = sel_getName(selector);
            char newSelectorName[strlen(selectorName) + 10];
            strcpy(newSelectorName, "ORIG");
            strcat(newSelectorName, selectorName);
            SEL newSelector = sel_getUid(newSelectorName);
            if(!class_respondsToSelector(metaclass, newSelector)) {
                class_addMethod(metaclass, newSelector, prevImp, typeDescription);
            }
            success = YES;
        } else {
            // add to both instance and class method
            success = class_addMethod(klass, selector, imp, typeDescription) && class_addMethod(metaclass, selector, imp, typeDescription);
        }
#endif
        
        
        if (returnType) free(returnType);
    }
    else {
        SEL possibleSelectors[3];
        wax_selectorsForName(methodName, possibleSelectors);
        
        success = YES;
        for (int i = 0; i < 3; i++) {
            selector = possibleSelectors[i];
            if (!selector) continue; // There may be only one acceptable selector sent back
            
            int argCount = 0;
            char *match = (char *)sel_getName(selector);
            while ((match = strchr(match, ':'))) {
                match += 1; // Skip past the matched char
                argCount++;
            }
            
            size_t typeDescriptionSize = 3 + argCount;
            typeDescription = calloc(typeDescriptionSize + 1, sizeof(char));
            memset(typeDescription, '@', typeDescriptionSize);
            typeDescription[2] = ':'; // Never forget _cmd!
            
            IMP imp = (IMP)WAX_METHOD_NAME(id);
            id metaclass = objc_getMetaClass(object_getClassName(klass));
            
#if 0
            success = success &&
            class_addMethod(klass, possibleSelectors[i], imp, typeDescription) &&
            class_addMethod(metaclass, possibleSelectors[i], imp, typeDescription);
#else
            
            IMP instImp = class_respondsToSelector(klass, selector) ? class_getMethodImplementation(klass, selector) : NULL;
            IMP metaImp = class_respondsToSelector(metaclass, selector) ? class_getMethodImplementation(metaclass, selector) : NULL;
            if(instImp) {
                // original selector is reserved in ORIGxxxx
                IMP prevImp = class_replaceMethod(klass, selector, imp, typeDescription);
                const char *selectorName = sel_getName(selector);
                char newSelectorName[strlen(selectorName) + 10];
                strcpy(newSelectorName, "ORIG");
                strcat(newSelectorName, selectorName);
                SEL newSelector = sel_getUid(newSelectorName);
                if(!class_respondsToSelector(klass, newSelector)) {
                    class_addMethod(klass, newSelector, prevImp, typeDescription);
                }
                success = YES;
            } else if(metaImp) {
                IMP prevImp = class_replaceMethod(metaclass, selector, imp, typeDescription);
                const char *selectorName = sel_getName(selector);
                char newSelectorName[strlen(selectorName) + 10];
                strcpy(newSelectorName, "ORIG");
                strcat(newSelectorName, selectorName);
                SEL newSelector = sel_getUid(newSelectorName);
                if(!class_respondsToSelector(metaclass, newSelector)) {
                    class_addMethod(metaclass, newSelector, prevImp, typeDescription);
                }
                success = YES;
            } else {
                // add to both instance and class method
                success = class_addMethod(klass, selector, imp, typeDescription) && class_addMethod(metaclass, selector, imp, typeDescription);
            }
#endif
            
            free(typeDescription);
        }
    }
    
    END_STACK_MODIFY(L, 1)
    return success;
}
#endif
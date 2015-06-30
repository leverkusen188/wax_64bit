//
//  LuaRuntimeContext.h
//  EmbedCocos2dxLua
//
//  Created by czh0766 on 14-3-28.
//
//

#import <Foundation/Foundation.h>
#import "wax.h"

@interface LuaRuntimeContext : NSObject {
    
    NSMutableDictionary* _dict;
    
}

//@property (retain,nonatomic) UIView* view;
//
//@property (copy,nonatomic) NSString* directory;

-(void)setValue:(id)value forKey:(NSString *)key;

-(id)valueForKey:(NSString *)key;

-(void)clean;

+(LuaRuntimeContext*) GetInstance;

@end


#ifdef  __cplusplus
extern "C" {
#endif
    
    int luaopen_app_Context(lua_State *L);
    
#ifdef  __cplusplus
}
#endif



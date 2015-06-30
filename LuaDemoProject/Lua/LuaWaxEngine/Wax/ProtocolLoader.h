// Many protocols will work from wax out of the box. But some need to be preloaded.
// If the protocol you are using isn't found, just add the protocol to this object
//
// This seems to be a bug, or there is a runtime method I'm unaware of

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>


@protocol TagSetsViewDelegate<NSObject>

- (BOOL)didSelectLabel:(NSString*)str;
@optional
- (void)didSelectEditLabel;

@end

@protocol ChosenTagShowViewDlegate<NSObject>

- (void)didRemoveLabel:(NSString *)str;

@end

@protocol CAAnimationDelegate
@optional
- (void)animationDidStart:(CAAnimation *)theAnimation;
- (void)animationDidStop:(CAAnimation *)theAnimation finished:(BOOL)flag;
@end

@class AwesomeMenu;
@protocol AwesomeMenuDelegate <NSObject>
@optional
- (void)awesomeMenu:(AwesomeMenu *)menu didSelectIndex:(NSInteger)idx;
- (void)awesomeMenuDidFinishAnimationClose:(AwesomeMenu *)menu;
- (void)awesomeMenuDidFinishAnimationOpen:(AwesomeMenu *)menu;
- (void)awesomeMenuWillAnimateOpen:(AwesomeMenu *)menu;
- (void)awesomeMenuWillAnimateClose:(AwesomeMenu *)menu;
@end
@interface ProtocolLoader : NSObject <UIApplicationDelegate, UIWebViewDelegate, UIActionSheetDelegate, UIAlertViewDelegate, UISearchBarDelegate, UITextViewDelegate, UITabBarControllerDelegate,CLLocationManagerDelegate,CAAnimationDelegate,TagSetsViewDelegate,ChosenTagShowViewDlegate, AwesomeMenuDelegate> {}
@end

@implementation ProtocolLoader
@end

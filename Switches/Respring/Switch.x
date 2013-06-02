#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>

@interface SpringBoard : UIApplication
- (void)_relaunchSpringBoardNow;
@end

@interface RespringSwitch : NSObject <FSSwitchDataSource>
@end

@implementation RespringSwitch

- (void)applyActionForSwitchIdentifier:(NSString *)switchIdentifier
{
	[(SpringBoard *)[objc_getClass("SpringBoard") sharedApplication] _relaunchSpringBoardNow];
}

@end

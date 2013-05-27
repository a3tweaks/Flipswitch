#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>

@interface SpringBoard : UIApplication
- (void)_relaunchSpringBoardNow;
- (void)_rebootNow;
- (void)_powerDownNow;
@end

@interface RespringSwitch : NSObject <FSSwitchDataSource>
@end

@implementation RespringSwitch

- (void)applyActionForSwitchIdentifier:(NSString *)switchIdentifier
{
	[(SpringBoard *)[objc_getClass("SpringBoard") sharedApplication] _relaunchSpringBoardNow];
}

@end

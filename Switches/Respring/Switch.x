#import <FSSwitch.h>
#import <FSSwitchPanel.h>

@interface SpringBoard : UIApplication
- (void)_relaunchSpringBoardNow;
- (void)_rebootNow;
- (void)_powerDownNow;
@end

@interface RespringSwitch : NSObject <FSSwitch>
@end

@implementation RespringSwitch

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	return FSSwitchStateIndeterminate;
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	[(SpringBoard *)[objc_getClass("SpringBoard") sharedApplication] _relaunchSpringBoardNow];
}

@end

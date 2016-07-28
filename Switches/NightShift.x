#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>

#import <SpringBoard/SpringBoard.h>
#import <objc/runtime.h>

static BOOL currentlyInNightShift;
static CBBlueLightClient *client;

@interface NightShiftSwitch : NSObject <FSSwitchDataSource>
@end

@implementation NightShiftSwitch

- (id)init
{
	if ((self = [super init])) {
		Class CBBlueLightClientClass = objc_getClass("CBBlueLightClient");
		if (![CBBlueLightClientClass supportsBlueLightReduction]) {
			[self release];
			return nil;
		}
		client = [[CBBlueLightClientClass alloc] init];
		CBBlueLightStatus status;
		if ([client getBlueLightStatus:&status]) {
			currentlyInNightShift = status.enabled;
		}
		[client setStatusNotificationBlock:^(CBBlueLightStatus *status) {
			currentlyInNightShift = status->enabled;
		    [[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:@"com.a3tweaks.switch.night-shift"];
		}];
	}
	return self;
}

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	return currentlyInNightShift;
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	switch (newState) {
		case FSSwitchStateIndeterminate:
		default:
			return;
		case FSSwitchStateOn:
			currentlyInNightShift = YES;
			[client setEnabled:YES withOption:3];
			break;
		case FSSwitchStateOff:
			currentlyInNightShift = NO;
			[client setEnabled:NO withOption:3];
			break;
	}
}

@end

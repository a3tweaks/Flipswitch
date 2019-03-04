#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>

#import <BulletinBoard/BulletinBoard.h>
#import <DoNotDisturbKit/DoNotDisturbKit.h>
#include <dlfcn.h>
#import <SpringBoard/SpringBoard.h>

static void (*BKSTerminateApplicationForReasonAndReportWithDescription)(NSString *app, int a, int b, NSString *description);

@interface DoNotDisturbSwitch : NSObject <FSSwitchDataSource, DNDStateUpdateListener>
@end

static DNDStateService *stateService;
static DNDModeAssertionService *assertionService;
static BBSettingsGateway *gateway;
static FSSwitchState state;

@implementation DoNotDisturbSwitch

- (id)init {
	if ((self = [super init])) {
		if (dlopen("/System/Library/PrivateFrameworks/DoNotDisturb.framework/DoNotDisturb", RTLD_LAZY)) {
			if (!stateService) {
				stateService = [(DNDStateService *)[objc_getClass("DNDStateService") serviceForClientIdentifier:@"com.apple.donotdisturb.control-center.module"] retain];
				if (stateService) {
					NSError *error = nil;
					[stateService addStateUpdateListener:self error:&error];
				}
			}
			if (!assertionService) {
				assertionService = [(DNDModeAssertionService *)[objc_getClass("DNDModeAssertionService") serviceForClientIdentifier:@"com.apple.donotdisturb.control-center.module"] retain];
			}
		}
	}
	return self;
}

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	if (stateService) {
		return [[stateService queryCurrentStateWithError:NULL] isActive] ? FSSwitchStateOn : FSSwitchStateOff;
	}
	return state;
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (assertionService) {
		switch (newState) {
			case FSSwitchStateOn: {
			    DNDModeAssertionDetails *newAssertion = [objc_getClass("DNDModeAssertionDetails") userRequestedAssertionDetailsWithIdentifier:@"com.apple.control-center.manual-toggle" modeIdentifier:@"com.apple.donotdisturb.mode.default" lifetime:nil];
			    [assertionService takeModeAssertionWithDetails:newAssertion error:NULL];
				return;
			}
			case FSSwitchStateOff:
			    [assertionService invalidateAllActiveModeAssertionsWithError:NULL];
				return;
			default:
				return;
		}
	}
	int mode;
	switch (newState) {
		case FSSwitchStateOn:
			state = FSSwitchStateOn;
			mode = 1;
			break;
		case FSSwitchStateOff:
			state = FSSwitchStateOff;
			mode = 2;
			break;
		default:
			return;
	}
	[gateway setBehaviorOverrideStatus:mode];
	// Now tell everyone about it. Bugs in SpringBoard if we don't :()
	if ([%c(SBBulletinSystemStateAdapter) respondsToSelector:@selector(sharedInstanceIfExists)] && [%c(SBBulletinSystemStateAdapter) instancesRespondToSelector:@selector(_activeBehaviorOverrideTypesChanged:)]) {
		[[%c(SBBulletinSystemStateAdapter) sharedInstanceIfExists] _activeBehaviorOverrideTypesChanged:state];
	}
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SBQuietModeStatusChangedNotification" object:nil];
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
		SBStatusBarDataManager *dm = [%c(SBStatusBarDataManager) sharedDataManager];
		[dm setStatusBarItem:1 enabled:NO];
		if (state) {
			[dm setStatusBarItem:1 enabled:YES];
		}
	});
	if (BKSTerminateApplicationForReasonAndReportWithDescription) {
		BKSTerminateApplicationForReasonAndReportWithDescription(@"com.apple.Preferences", 5, 0, nil);
	}
}

- (void)stateService:(DNDStateService *)stateService didReceiveDoNotDisturbStateUpdate:(id)update
{
	[[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:@"com.a3tweaks.switch.do-not-disturb"];
}

@end

%ctor
{
	if (kCFCoreFoundationVersionNumber < 700.9) {
		return;
	}
	state = FSSwitchStateIndeterminate;
	dispatch_async(dispatch_get_main_queue(), ^{
		if (stateService) {
			return;
		}
		Class BBSettingsGatewayClass = objc_getClass("BBSettingsGateway");
		if ([BBSettingsGatewayClass instancesRespondToSelector:@selector(initWithQueue:)])
			gateway = [[BBSettingsGatewayClass alloc] initWithQueue:dispatch_get_main_queue()];
		else
			gateway = [[BBSettingsGatewayClass alloc] init];
		[gateway setActiveBehaviorOverrideTypesChangeHandler:^(int value) {
			state = value & 1;
			[[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:@"com.a3tweaks.switch.do-not-disturb"];
		}];
		[gateway setBehaviorOverrideStatusChangeHandler:^(int value){
		}];
		if (kCFCoreFoundationVersionNumber < 800.0) {
			// Don't force terminate the Settings app on iOS 7. Usual toggle doesn't terminate and leaves the state inconsistent, so we may as well follow suit
			BKSTerminateApplicationForReasonAndReportWithDescription = dlsym(RTLD_DEFAULT, "BKSTerminateApplicationForReasonAndReportWithDescription");
		}
	});
}

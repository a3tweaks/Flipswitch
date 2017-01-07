#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>
#import <FSSwitchSettingsViewController.h>

#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import <CaptainHook/CaptainHook.h>
#import <UIKit/UIKit.h>
#import <SpringBoard/SpringBoard.h>
#import <objc/runtime.h>
#import <dlfcn.h>

#import "../NSObject+FSSwitchDataSource.h"

#import "Flashlight.h"

@interface FlashlightSwitch : NSObject <FSSwitchDataSource>
@end

static FlashlightSwitch *sharedFlashlight;

static AVCaptureDevice *currentDevice;

static AVFlashlight *flashlight;
static BOOL prewarming;
static FSSwitchState intendedState;

static Class FlashlightClass(void)
{
	Class result = %c(AVFlashlight);
	return ([result instancesRespondToSelector:@selector(setFlashlightLevel:withError:)] && [result instancesRespondToSelector:@selector(turnPowerOff)]) ? result : nil;
}

%hook AVFlashlight

- (id)init
{
	if ((self = %orig())) {
		// Steal iOS's flashlight
		if (flashlight) {
			[flashlight removeObserver:sharedFlashlight forKeyPath:@"available" context:NULL];
			[flashlight release];
		}
		if (flashlight || prewarming) {
			flashlight = [self retain];
			[self addObserver:sharedFlashlight forKeyPath:@"available" options:0 context:NULL];
		} else {
			flashlight = nil;
		}
	}
	return self;
}

%end

@implementation FlashlightSwitch

- (id)init
{
	if ((self = [super init])) {
		sharedFlashlight = self;
		if (FlashlightClass()) {
			%init();
		}
	}
	return self;
}

#ifdef DEBUG

- (void)dealloc
{
	sharedFlashlight = nil;
	[super dealloc];
}

#endif

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	return intendedState ?: (currentDevice ? FSSwitchStateOn : FSSwitchStateOff);
}

static void StealFlashlight(void)
{
	Class class = FlashlightClass();
	if (!class)
		return;
	AVFlashlight *newFlashlight;
	// Steal the existing one, if we don't already have one
	SBControlCenterViewController **_viewController = CHIvarRef([%c(SBControlCenterController) sharedInstanceIfExists], _viewController, SBControlCenterViewController *);
	if (_viewController) {
		id quickLaunchSection = nil;
		SBControlCenterContentView **_contentView = CHIvarRef(*_viewController, _contentView, SBControlCenterContentView *);
		if (_contentView && [*_contentView respondsToSelector:@selector(quickLaunchSection)]) {
			// iOS 7-9
			quickLaunchSection = [*_contentView quickLaunchSection];
		} else {
			// iOS 10
			id *_systemControlsPage = CHIvarRef(*_viewController, _systemControlsPage, id);
			if (_systemControlsPage) {
				id *_quickLaunchSection = CHIvarRef(*_systemControlsPage, _quickLaunchSection, id);
				if (_quickLaunchSection) {
					quickLaunchSection = *_quickLaunchSection;
				}
			}
		}
		if (quickLaunchSection) {
			NSMutableDictionary **_modulesByID = CHIvarRef(quickLaunchSection, _modulesByID, NSMutableDictionary *);
			id target = _modulesByID && *_modulesByID ? [*_modulesByID objectForKey:@"flashlight"] : quickLaunchSection;
			AVFlashlight **_flashlight = CHIvarRef(target, _flashlight, AVFlashlight *);
			if (_flashlight) {
				newFlashlight = *_flashlight;
				if (newFlashlight) {
					if (newFlashlight == flashlight)
						return;
					[newFlashlight retain];
					goto retain;
				}
			}
		}
	}
	newFlashlight = [[class alloc] init];
retain:
	[flashlight removeObserver:sharedFlashlight forKeyPath:@"available" context:NULL];
	[flashlight release];
	[newFlashlight addObserver:sharedFlashlight forKeyPath:@"available" options:0 context:NULL];
	flashlight = newFlashlight;
}

static float theJam;

- (void)pumpTheJam
{
	theJam = 1.0f - theJam;
	[flashlight setFlashlightLevel:theJam withError:NULL];
	[self performSelector:@selector(pumpTheJam) withObject:nil afterDelay:1.0/12.0];
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(pumpTheJam) object:nil];
	intendedState = newState;
	if (newState) {
		StealFlashlight();
		FlashlightSwitchAction action = (newState == FSSwitchStateIndeterminate) ? ActionForKey(CFSTR("AlternateAction"), 1) : ActionForKey(CFSTR("DefaultAction"), 0);
		switch (action) {
			case FlashlightSwitchActionOn:
				[flashlight setFlashlightLevel:1.0 withError:NULL];
				break;
			case FlashlightSwitchActionLowPower:
				[flashlight setFlashlightLevel:nextafterf(0.0f, 1.0f) withError:NULL];
				break;
			case FlashlightSwitchActionStrobe:
				theJam = 0.0;
				[self pumpTheJam];
				break;
		}
		[flashlight setFlashlightLevel:(newState == FSSwitchStateIndeterminate) ? 0.1 : 1.0 withError:NULL];
		if (flashlight)
			return;
	} else if (flashlight) {
		[flashlight turnPowerOff];
		if (!prewarming) {
			[flashlight removeObserver:self forKeyPath:@"available" context:NULL];
			[flashlight release];
			flashlight = nil;
		}
		if (!currentDevice)
			return;
	}

	if (newState) {
		if (currentDevice)
			return;
		for (AVCaptureDevice *device in [objc_getClass("AVCaptureDevice") devices]) {
			if (device.hasTorch && [device lockForConfiguration:NULL]) {
				[device setTorchMode:AVCaptureTorchModeOn];
				[device unlockForConfiguration];
				currentDevice = [device retain];
				return;
			}
		}
	} else {
		AVCaptureDevice *device = currentDevice;
		if (!device)
			return;
		currentDevice = nil;
		if ([device lockForConfiguration:NULL]) {
			[device setTorchMode:AVCaptureTorchModeOff];
			[device unlockForConfiguration];
		}
		[device release];
		device = nil;
	}
}

- (void)applyActionForSwitchIdentifier:(NSString *)switchIdentifier
{
	switch ([self stateForSwitchIdentifier:switchIdentifier]) {
		case FSSwitchStateOff:
			[self applyState:FSSwitchStateOn forSwitchIdentifier:switchIdentifier];
			break;
		default:
			[self applyState:FSSwitchStateOff forSwitchIdentifier:switchIdentifier];
			break;
	}
}

- (void)applyAlternateActionForSwitchIdentifier:(NSString *)switchIdentifier
{
	[[FSSwitchPanel sharedPanel] setState:FSSwitchStateIndeterminate forSwitchIdentifier:switchIdentifier];
}

- (BOOL)hasAlternateActionForSwitchIdentifier:(NSString *)switchIdentifier
{
	return (kCFCoreFoundationVersionNumber >= 800.0);
}

- (void)beginPrewarmingForSwitchIdentifier:(NSString *)switchIdentifier
{
	prewarming = YES;
	if (!flashlight) {
		StealFlashlight();
	}
}

- (void)cancelPrewarmingForSwitchIdentifier:(NSString *)switchIdentifier
{
	prewarming = NO;
	if (intendedState == FSSwitchStateOff) {
		[flashlight removeObserver:self forKeyPath:@"available" context:NULL];
		[flashlight release];
		flashlight = nil;
	}
}

- (NSString *)descriptionOfState:(FSSwitchState)state forSwitchIdentifier:(NSString *)switchIdentifier
{
	switch (state) {
		case FSSwitchStateOn:
			return TitleForAction(ActionForKey(CFSTR("DefaultAction"), 0));
		case FSSwitchStateIndeterminate:
			return TitleForAction(ActionForKey(CFSTR("AlternateAction"), 1));
		case FSSwitchStateOff:
		default:
			return [super descriptionOfState:state forSwitchIdentifier:switchIdentifier];
	}
}

- (Class <FSSwitchSettingsViewController>)settingsViewControllerClassForSwitchIdentifier:(NSString *)switchIdentifier
{
	if (kCFCoreFoundationVersionNumber < 800) {
		return Nil;
	}
	return [super settingsViewControllerClassForSwitchIdentifier:switchIdentifier];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	dispatch_async(dispatch_get_main_queue(), ^{
		if (intendedState) {
			FlashlightSwitchAction action = (intendedState == FSSwitchStateIndeterminate) ? ActionForKey(CFSTR("AlternateAction"), 1) : ActionForKey(CFSTR("DefaultAction"), 0);
			switch (action) {
				case FlashlightSwitchActionOn:
					[flashlight setFlashlightLevel:1.0 withError:NULL];
					break;
				case FlashlightSwitchActionLowPower:
					[flashlight setFlashlightLevel:nextafterf(0.0f, 1.0f) withError:NULL];
					break;
				case FlashlightSwitchActionStrobe:
					break;
			}
		}
	});
}

@end

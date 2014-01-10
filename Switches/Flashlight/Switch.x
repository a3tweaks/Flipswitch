#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>

#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import <CaptainHook/CaptainHook.h>

@interface FlashlightSwitch : NSObject <FSSwitchDataSource>
@end

@interface AVFlashlight : NSObject

+ (BOOL)hasFlashlight;

@property(readonly, nonatomic) float flashlightLevel;
- (BOOL)setFlashlightLevel:(float)level withError:(NSError **)error;

- (void)turnPowerOff;
- (BOOL)turnPowerOnWithError:(NSError **)error;
@property(readonly, nonatomic, getter=isOverheated) BOOL overheated;
@property(readonly, nonatomic, getter=isAvailable) BOOL available;

- (void)teardownFigRecorder;
- (BOOL)ensureFigRecorderWithError:(NSError **)error;
- (BOOL)bringupFigRecorderWithError:(NSError **)error;

@end

@interface SBControlCenterController : UIViewController
+ (SBControlCenterController *)sharedInstanceIfExists;
@end

@interface SBControlCenterViewController : UIViewController
@end

@interface SBCCQuickLaunchSectionController : /* ... */ UIViewController
@end

@interface SBControlCenterContentView : UIView
@property (retain, nonatomic) SBCCQuickLaunchSectionController *quickLaunchSection;
@end

static FlashlightSwitch *sharedFlashlight;

static AVCaptureDevice *currentDevice;

static AVFlashlight *flashlight;
static BOOL prewarming;
static BOOL intendedState;

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
	return (currentDevice || intendedState) ? FSSwitchStateOn : FSSwitchStateOff;
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
		SBControlCenterContentView **_contentView = CHIvarRef(*_viewController, _contentView, SBControlCenterContentView *);
		if (_contentView && [*_contentView respondsToSelector:@selector(quickLaunchSection)]) {
			AVFlashlight **_flashlight = CHIvarRef([*_contentView quickLaunchSection], _flashlight, AVFlashlight *);
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

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (newState == FSSwitchStateIndeterminate)
		return;

	intendedState = newState;
	if (newState) {
		StealFlashlight();
		[flashlight setFlashlightLevel:1.0 withError:NULL];
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
		for (AVCaptureDevice *device in [AVCaptureDevice devices]) {
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

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	dispatch_async(dispatch_get_main_queue(), ^{
		if (intendedState) {
			[flashlight setFlashlightLevel:1.0 withError:NULL];
		}
	});
}

@end

#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>
#import <FSSwitchSettingsViewController.h>

#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import <CaptainHook/CaptainHook.h>

typedef enum {
	FlashlightSwitchActionOn,
	FlashlightSwitchActionLowPower,
	FlashlightSwitchActionStrobe,
} FlashlightSwitchAction;

@interface FlashlightSwitch : NSObject <FSSwitchDataSource>
@end

@interface FlashlightSwitchSettingsViewController : UITableViewController <FSSwitchSettingsViewController> {
	FlashlightSwitchAction defaultAction;
	FlashlightSwitchAction alternateAction;
}
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
static FSSwitchState intendedState;

static Class FlashlightClass(void)
{
	Class result = %c(AVFlashlight);
	return ([result instancesRespondToSelector:@selector(setFlashlightLevel:withError:)] && [result instancesRespondToSelector:@selector(turnPowerOff)]) ? result : nil;
}

static NSString *TitleForAction(FlashlightSwitchAction action)
{
	switch (action) {
		case FlashlightSwitchActionOn:
			return @"On";
		case FlashlightSwitchActionLowPower:
			return @"Low Power";
		case FlashlightSwitchActionStrobe:
			return @"Strobe";
		default:
			return nil;
	}
}

static FlashlightSwitchAction ActionForKey(CFStringRef key, FlashlightSwitchAction defaultValue)
{
	CFPreferencesAppSynchronize(CFSTR("com.a3tweaks.switch.flashlight"));
	Boolean valid;
	CFIndex value = CFPreferencesGetAppIntegerValue(key, CFSTR("com.a3tweaks.switch.flashlight"), &valid);
	return valid ? value : defaultValue;
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
		case FSSwitchStateOff:
			return @"Off";
		case FSSwitchStateIndeterminate:
			return TitleForAction(ActionForKey(CFSTR("AlternateAction"), 1));
		default:
			return nil;
	}
}

- (Class <FSSwitchSettingsViewController>)settingsViewControllerClassForSwitchIdentifier:(NSString *)switchIdentifier
{
	return (kCFCoreFoundationVersionNumber >= 800) ? [FlashlightSwitchSettingsViewController class] : nil;
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

@implementation FlashlightSwitchSettingsViewController

- (id)init
{
	if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
		defaultAction = ActionForKey(CFSTR("DefaultAction"), 0);
		alternateAction = ActionForKey(CFSTR("AlternateAction"), 1);
	}
	return self;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)table
{
	return 2;
}

- (NSString *)tableView:(UITableView *)table titleForHeaderInSection:(NSInteger)section
{
	switch (section) {
		case 0:
			return @"Tap Action";
		case 1:
			return @"Hold Action";
		default:
			return nil;
	}
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
	return 3;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"] ?: [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"] autorelease];
	cell.textLabel.text = TitleForAction(indexPath.row);
	CFIndex value = indexPath.section ? alternateAction : defaultAction;
	cell.accessoryType = (value == indexPath.row) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	NSInteger section = indexPath.section;
	NSInteger value = indexPath.row;
	CFStringRef key;
	if (section) {
		key = CFSTR("AlternateAction");
		alternateAction = value;
	} else {
		key = CFSTR("DefaultAction");
		defaultAction = value;
	}
	for (NSInteger i = 0; i < 3; i++) {
		[tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:section]].accessoryType = (value == i) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
	}
	CFPreferencesSetAppValue(key, (CFTypeRef)[NSNumber numberWithInteger:value], CFSTR("com.a3tweaks.switch.flashlight"));
	CFPreferencesAppSynchronize(CFSTR("com.a3tweaks.switch.flashlight"));
}

@end

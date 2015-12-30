#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CaptainHook/CaptainHook.h>
#import <SpringBoard/SpringBoard.h>

#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>
#import <FSSwitchSettingsViewController.h>

#include <notify.h>
#include <dlfcn.h>

#define IsOS4 (kCFCoreFoundationVersionNumber >= 478.61)
static BOOL (*isEnabled)(void);
static void (*setEnabled)(BOOL newState);

@interface RotationSwitch : NSObject <FSSwitchDataSource>
@end

@interface RotationLockSwitch : RotationSwitch
@end

@interface RotationSwitchSettingsViewController : UITableViewController <FSSwitchSettingsViewController>
@end

%hook SBOrientationLockManager

- (void)unlock
{
	%orig();
	FSSwitchPanel *panel = [FSSwitchPanel sharedPanel];
	[panel stateDidChangeForSwitchIdentifier:@"com.a3tweaks.switch.rotation"];
	[panel stateDidChangeForSwitchIdentifier:@"com.a3tweaks.switch.rotation-lock"];
}

- (void)lock:(UIUserInterfaceIdiom)lock
{
	%orig();
	FSSwitchPanel *panel = [FSSwitchPanel sharedPanel];
	[panel stateDidChangeForSwitchIdentifier:@"com.a3tweaks.switch.rotation"];
	[panel stateDidChangeForSwitchIdentifier:@"com.a3tweaks.switch.rotation-lock"];
}

%end

#pragma mark Switch

@implementation RotationSwitch

- (id)init
{
	if (IsOS4 || (isEnabled && setEnabled))
		return [super init];
	[self release];
	return nil;
}

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	if (IsOS4)
		return ![[%c(SBOrientationLockManager) sharedInstance] isLocked];
	else
		return isEnabled ? isEnabled() : YES;
}

- (BOOL)hasAlternateActionForSwitchIdentifier:(NSString *)switchIdentifier
{
	CFPreferencesAppSynchronize(CFSTR("com.a3tweaks.switch.rotation"));
	return !CFPreferencesGetAppBooleanValue(CFSTR("DisableLandsapeLock"), CFSTR("com.a3tweaks.switch.rotation"), NULL);
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (newState == FSSwitchStateIndeterminate)
		return;
	if (IsOS4) {
		SBOrientationLockManager *lockManager = [%c(SBOrientationLockManager) sharedInstance];
		if (newState) {
			[lockManager unlock];
			if ([lockManager respondsToSelector:@selector(lockOverrideEnabled)] ? [lockManager lockOverrideEnabled] : [lockManager lockOverride])
				[lockManager updateLockOverrideForCurrentDeviceOrientation];
		} else {
			BOOL supportLandscapeLock = [self hasAlternateActionForSwitchIdentifier:switchIdentifier];
			UIInterfaceOrientation desiredOrientation = supportLandscapeLock ? [(SpringBoard *)[UIApplication sharedApplication] activeInterfaceOrientation] : UIInterfaceOrientationPortrait;
			[lockManager lock:desiredOrientation];
			if ([lockManager respondsToSelector:@selector(lockOverrideEnabled)] ? [lockManager lockOverrideEnabled] : [lockManager lockOverride]) {
				if ([lockManager respondsToSelector:@selector(setLockOverrideEnabled:forReason:)]) {
					for (id reason in [[CHIvar(lockManager, _lockOverrideReasons, NSMutableSet *) copy] autorelease])
						[lockManager setLockOverrideEnabled:NO forReason:reason];
				} else {
					[lockManager setLockOverride:0 orientation:UIInterfaceOrientationPortrait];
				}
			}
		}
		id appSwitcherController;
		if ([%c(SBAppSwitcherController) respondsToSelector:@selector(sharedInstanceIfAvailable)])
			appSwitcherController = [%c(SBAppSwitcherController) sharedInstanceIfAvailable];
		else if ([%c(SBUIController) instancesRespondToSelector:@selector(switcherController)])
			appSwitcherController = [(SBUIController *)[%c(SBUIController) sharedInstance] switcherController];
		else
			return;
		SBNowPlayingBar **nowPlayingBar = CHIvarRef(appSwitcherController, _nowPlaying, SBNowPlayingBar *);
		if (nowPlayingBar) {
			UIButton **_orientationLockButton = CHIvarRef(*nowPlayingBar, _orientationLockButton, UIButton *);
			if (_orientationLockButton) {
				[*_orientationLockButton setSelected:[lockManager isLocked]];
			}
		}
	} else {
		if (setEnabled) {
			setEnabled(newState);
			FSSwitchPanel *panel = [FSSwitchPanel sharedPanel];
			[panel stateDidChangeForSwitchIdentifier:@"com.a3tweaks.switch.rotation"];
			[panel stateDidChangeForSwitchIdentifier:@"com.a3tweaks.switch.rotation-lock"];
		}
	}
}

- (void)applyAlternateActionForSwitchIdentifier:(NSString *)switchIdentifier
{
	if (![self hasAlternateActionForSwitchIdentifier:switchIdentifier])
		return;
	SBOrientationLockManager *lockManager = [%c(SBOrientationLockManager) sharedInstance];
	if ([lockManager isLocked]) {
		switch ([lockManager respondsToSelector:@selector(userLockOrientation)] ? [lockManager userLockOrientation] : [lockManager lockOrientation]) {
			case UIInterfaceOrientationPortrait:
				[lockManager lock:UIInterfaceOrientationLandscapeLeft];
				break;
			case UIInterfaceOrientationLandscapeLeft:
				[lockManager lock:(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? UIInterfaceOrientationPortraitUpsideDown : UIInterfaceOrientationLandscapeRight];
				break;
			case UIInterfaceOrientationPortraitUpsideDown:
				[lockManager lock:UIInterfaceOrientationLandscapeRight];
				break;
			case UIInterfaceOrientationLandscapeRight:
				[lockManager unlock];
				break;
		}
	} else {
		[lockManager lock:UIInterfaceOrientationPortrait];
	}
}

static NSString *LockedOrientationName(void)
{
	SBOrientationLockManager *lockManager = [%c(SBOrientationLockManager) sharedInstance];
	if ([lockManager isLocked]) {
		switch ([lockManager respondsToSelector:@selector(userLockOrientation)] ? [lockManager userLockOrientation] : [lockManager lockOrientation]) {
			case UIInterfaceOrientationPortrait:
			case UIInterfaceOrientationPortraitUpsideDown:
				return @"Portrait";
			case UIInterfaceOrientationLandscapeLeft:
			case UIInterfaceOrientationLandscapeRight:
				return @"Landscape";
		}
	}
	return nil;
}

- (Class <FSSwitchSettingsViewController>)settingsViewControllerClassForSwitchIdentifier:(NSString *)switchIdentifier
{
	return (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) ? [RotationSwitchSettingsViewController class] : nil;
}

- (NSString *)descriptionOfState:(FSSwitchState)state forSwitchIdentifier:(NSString *)switchIdentifier
{
	switch (state) {
		case FSSwitchStateOn:
			return @"On";
		case FSSwitchStateOff:
			return LockedOrientationName() ?: @"Off";
		default:
			return nil;
	}
}

@end

@implementation RotationLockSwitch

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	return [super stateForSwitchIdentifier:switchIdentifier] ? FSSwitchStateOff : FSSwitchStateOn;
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	switch (newState) {
		case FSSwitchStateOn:
			newState = FSSwitchStateOff;
			break;
		case FSSwitchStateOff:
			newState = FSSwitchStateOn;
			break;
		default:
			break;
	}
	[super applyState:newState forSwitchIdentifier:switchIdentifier];
}

- (NSBundle *)bundleForSwitchIdentifier:(NSString *)switchIdentifier
{
	return [NSBundle bundleWithPath:@"/Library/Switches/RotationLock.bundle"];
}

- (NSString *)descriptionOfState:(FSSwitchState)state forSwitchIdentifier:(NSString *)switchIdentifier
{
	switch (state) {
		case FSSwitchStateOn:
			return LockedOrientationName() ?: @"On";
		case FSSwitchStateOff:
			return @"Off";
		default:
			return nil;
	}
}

@end

@implementation RotationSwitchSettingsViewController

- (id)init
{
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
	return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"] ?: [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"] autorelease];
	cell.textLabel.text = @"Support Landscape Lock";
	CFPreferencesAppSynchronize(CFSTR("com.a3tweaks.switch.rotation"));
	cell.accessoryType = CFPreferencesGetAppBooleanValue(CFSTR("DisableLandsapeLock"), CFSTR("com.a3tweaks.switch.rotation"), NULL) ? UITableViewCellAccessoryNone : UITableViewCellAccessoryCheckmark;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	BOOL newValue = (cell.accessoryType == UITableViewCellAccessoryCheckmark);
	cell.accessoryType = newValue ? UITableViewCellAccessoryNone : UITableViewCellAccessoryCheckmark;
	CFPreferencesSetAppValue(CFSTR("DisableLandsapeLock"), (CFTypeRef)[NSNumber numberWithBool:newValue], CFSTR("com.a3tweaks.switch.rotation"));
	CFPreferencesAppSynchronize(CFSTR("com.a3tweaks.switch.rotation"));
}

@end


CHConstructor
{
	%init();
	if (!IsOS4) {
		void *rotationinhibitor = dlopen("/Library/MobileSubstrate/DynamicLibraries/RotationInhibitor.dylib", RTLD_LAZY);
		isEnabled = dlsym(rotationinhibitor, "isEnabled");
		setEnabled = dlsym(rotationinhibitor, "setEnabled");
	}
}


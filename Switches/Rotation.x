#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CaptainHook/CaptainHook.h>
#import <SpringBoard/SpringBoard.h>

#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>
#import <FSSwitchSettingsViewController.h>

#import "../NSObject+FSSwitchDataSource.h"
#import "dlsymfn.h"

#include <notify.h>
#include <dlfcn.h>
#include <objc/runtime.h>

#define IsOS4 (kCFCoreFoundationVersionNumber >= 478.61)
#ifndef __LP64__
static BOOL (*isEnabled)(void);
static void (*setEnabled)(BOOL newState);
#endif

@interface RotationSwitch : NSObject <FSSwitchDataSource>
@end

@interface RotationLockSwitch : RotationSwitch
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

static BOOL isLocked(SBOrientationLockManager *orientationLockManager)
{
	return [orientationLockManager respondsToSelector:@selector(isUserLocked)] ? [orientationLockManager isUserLocked] : [orientationLockManager isLocked];
}

@implementation RotationSwitch

#ifndef __LP64__
- (id)init
{
	if (IsOS4 || (isEnabled && setEnabled))
		return [super init];
	[self release];
	return nil;
}
#endif

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
#ifndef __LP64__
	if (IsOS4)
#endif
		return !isLocked([%c(SBOrientationLockManager) sharedInstance]);
#ifndef __LP64__
	else
		return isEnabled ? isEnabled() : YES;
#endif
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
#ifndef __LP64__
	if (IsOS4) {
#endif
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
				[*_orientationLockButton setSelected:isLocked(lockManager)];
			}
		}
#ifndef __LP64__
	} else {
		if (setEnabled) {
			setEnabled(newState);
			FSSwitchPanel *panel = [FSSwitchPanel sharedPanel];
			[panel stateDidChangeForSwitchIdentifier:@"com.a3tweaks.switch.rotation"];
			[panel stateDidChangeForSwitchIdentifier:@"com.a3tweaks.switch.rotation-lock"];
		}
	}
#endif
}

- (void)applyAlternateActionForSwitchIdentifier:(NSString *)switchIdentifier
{
	if (![self hasAlternateActionForSwitchIdentifier:switchIdentifier])
		return;
	SBOrientationLockManager *lockManager = [%c(SBOrientationLockManager) sharedInstance];
	if (isLocked(lockManager)) {
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
	if (isLocked(lockManager)) {
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
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
		return Nil;
	}
	return [super settingsViewControllerClassForSwitchIdentifier:switchIdentifier];
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

CHConstructor
{
	%init();
#ifndef __LP64__
	if (!IsOS4) {
		void *rotationinhibitor = dlopen("/Library/MobileSubstrate/DynamicLibraries/RotationInhibitor.dylib", RTLD_LAZY);
		isEnabled = dlsymfn(rotationinhibitor, "isEnabled");
		setEnabled = dlsymfn(rotationinhibitor, "setEnabled");
	}
#endif
}

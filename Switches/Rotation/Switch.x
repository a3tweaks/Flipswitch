#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CaptainHook/CaptainHook.h>
#import <GraphicsServices/GraphicsServices.h>
//#import <SpringBoard/SpringBoard.h>

#import <FSSwitch.h>
#import <FSSwitchPanel.h>

#include <notify.h>

#define kSettingsChangeNotification "com.booleanmagic.rotationinhibitor.settingschange"
#define kSettingsFilePath "/User/Library/Preferences/com.booleanmagic.rotationinhibitor.plist"

#define IsOS4 (kCFCoreFoundationVersionNumber >= 478.61)

static BOOL rotationEnabled;

//Header Dependencies
@interface SBIconLabel : UILabel
@end

@interface SBIcon : NSObject
@end

@interface SBApplicationIcon : SBIcon
@end

// OS 4.0

@interface SBOrientationLockManager : NSObject {
	int _override;
	int _lockedOrientation;
	int _overrideOrientation;
}
+ (SBOrientationLockManager *)sharedInstance;
- (void)lock:(UIInterfaceOrientation)lock;
- (void)unlock;
- (BOOL)isLocked;
- (UIInterfaceOrientation)lockOrientation;
- (void)setLockOverride:(int)lockOverride orientation:(UIInterfaceOrientation)orientation;
- (int)lockOverride;
- (void)updateLockOverrideForCurrentDeviceOrientation;
@end

@interface SBOrientationLockManager (iOS50)
- (BOOL)lockOverrideEnabled;
- (void)setLockOverrideEnabled:(BOOL)enabled forReason:(NSString *)reason;
- (UIInterfaceOrientation)userLockOrientation;
@end

@class SBApplication;

@interface SBNowPlayingBar : NSObject {
	UIView *_containerView;
	UIButton *_orientationLockButton;
	UIButton *_prevButton;
	UIButton *_playButton;
	UIButton *_nextButton;
	SBIconLabel *_trackLabel;
	SBIconLabel *_orientationLabel;
	SBApplicationIcon *_nowPlayingIcon;
	SBApplication *_nowPlayingApp;
	int _scanDirection;
	BOOL _isPlaying;
	BOOL _isEnabled;
	BOOL _showingOrientationLabel;
}
- (void)_orientationLockHit:(id)sender;
- (void)_displayOrientationStatus:(BOOL)isLocked;
@end

@class SBNowPlayingBarMediaControlsView;
@interface SBNowPlayingBarView : UIView {
	UIView *_orientationLockContainer;
	UIButton *_orientationLockButton;
	UISlider *_brightnessSlider;
	UISlider *_volumeSlider;
	UIImageView *_brightnessImage;
	UIImageView *_volumeImage;
	SBNowPlayingBarMediaControlsView *_mediaView;
	SBApplicationIcon *_nowPlayingIcon;
}
@property(readonly, nonatomic) UIButton *orientationLockButton;
@property(readonly, nonatomic) UISlider *brightnessSlider;
@property(readonly, nonatomic) UISlider *volumeSlider;
@property(readonly, nonatomic) SBNowPlayingBarMediaControlsView *mediaView;
@property(retain, nonatomic) SBApplicationIcon *nowPlayingIcon;
@property(readonly, nonatomic) UIButton *airPlayButton;
- (void)_layoutForiPhone;
- (void)_layoutForiPad;
- (void)_orientationLockChanged:(id)sender;
- (void)showAudioRoutesPickerButton:(BOOL)button;
- (void)showVolume:(BOOL)volume;
@end

@class SBAppSwitcherModel, SBAppSwitcherBarView;
@interface SBAppSwitcherController : NSObject {
	SBAppSwitcherModel *_model;
	SBNowPlayingBar *_nowPlaying;
	SBAppSwitcherBarView *_bottomBar;
	SBApplicationIcon *_pushedIcon;
	BOOL _editing;
}
+ (id)sharedInstance;
+ (id)sharedInstanceIfAvailable;
@end

@interface SBNowPlayingBarView (iOS43)
@property (assign, nonatomic) NSInteger switchType;
@property (readonly, assign, nonatomic) UIButton *switchButton;
@end

@interface SpringBoard : UIApplication
- (UIInterfaceOrientation)activeInterfaceOrientation;
@end

%config(generator=internal);

// 4.0-4.2
%group iOS4

%hook SBNowPlayingBar

- (void)_orientationLockHit:(id)sender
{
	SBOrientationLockManager *lockManager = [%c(SBOrientationLockManager) sharedInstance];
	NSString *labelText;
	BOOL isLocked = [lockManager isLocked];
	if (isLocked) {
		[lockManager unlock];
		if ([lockManager respondsToSelector:@selector(lockOverrideEnabled)] ? [lockManager lockOverrideEnabled] : [lockManager lockOverride]) {
			if ([lockManager respondsToSelector:@selector(setLockOverrideEnabled:forReason:)]) {
				for (id reason in [[CHIvar(lockManager, _lockOverrideReasons, NSMutableSet *) copy] autorelease])
					[lockManager setLockOverrideEnabled:NO forReason:reason];
			} else {
				[lockManager setLockOverride:0 orientation:UIDeviceOrientationPortrait];
			}
		}
		labelText = @"Orientation Unlocked";
	} else {
		[lockManager lock:[(SpringBoard *)[UIApplication sharedApplication] activeInterfaceOrientation]];
		if ([lockManager respondsToSelector:@selector(lockOverrideEnabled)] ? [lockManager lockOverrideEnabled] : [lockManager lockOverride])
			[lockManager updateLockOverrideForCurrentDeviceOrientation];
		switch ([lockManager respondsToSelector:@selector(userLockOrientation)] ? [lockManager userLockOrientation] : [lockManager lockOrientation]) {
			case UIDeviceOrientationPortrait:
				labelText = @"Portrait Orientation Locked";
				break;
			case UIDeviceOrientationLandscapeLeft:
				labelText = @"Landscape Left Orientation Locked";
				break;
			case UIDeviceOrientationLandscapeRight:
				labelText = @"Landscape Right Orientation Locked";
				break;
			default:
				labelText = @"Upside Down Orientation Locked";
				break;
		}
	}
	SBNowPlayingBarView **nowPlayingBarView = CHIvarRef(self, _barView, SBNowPlayingBarView *);
	UIButton *orientationLockButton;
	if (nowPlayingBarView) {
		orientationLockButton = (*nowPlayingBarView).orientationLockButton;
	} else {
		orientationLockButton = CHIvar(self, _orientationLockButton, UIButton *);
		[self _displayOrientationStatus:isLocked];
		[CHIvar(self, _orientationLabel, UILabel *) setText:labelText];
	}
	orientationLockButton.selected = !isLocked;
}

// 4.3

- (void)_switchButtonHit:(id)sender
{
	SBNowPlayingBarView **nowPlayingBarView = CHIvarRef(self, _barView, SBNowPlayingBarView *);
	if (!nowPlayingBarView || [*nowPlayingBarView switchType] != 0) {
		%orig();
		return;
	}
	SBOrientationLockManager *lockManager = [%c(SBOrientationLockManager) sharedInstance];
	BOOL isLocked = [lockManager isLocked];
	if (isLocked) {
		[lockManager unlock];
		if ([lockManager respondsToSelector:@selector(lockOverrideEnabled)] ? [lockManager lockOverrideEnabled] : [lockManager lockOverride]) {
			if ([lockManager respondsToSelector:@selector(setLockOverrideEnabled:forReason:)]) {
				for (id reason in [[CHIvar(lockManager, _lockOverrideReasons, NSMutableSet *) copy] autorelease])
					[lockManager setLockOverrideEnabled:NO forReason:reason];
			} else {
				[lockManager setLockOverride:0 orientation:UIDeviceOrientationPortrait];
			}
		}
	} else {
		[lockManager lock:[(SpringBoard *)[UIApplication sharedApplication] activeInterfaceOrientation]];
		if ([lockManager respondsToSelector:@selector(lockOverrideEnabled)] ? [lockManager lockOverrideEnabled] : [lockManager lockOverride])
			[lockManager updateLockOverrideForCurrentDeviceOrientation];
	}
	UIButton *orientationLockButton = (*nowPlayingBarView).switchButton;
	orientationLockButton.selected = !isLocked;
}

%end

@interface RotationSwitch : NSObject <FSSwitch>
@end

%hook SBOrientationLockManager

- (void)unlock
{
	%orig();
	[[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:[NSBundle bundleForClass:[RotationSwitch class]].bundleIdentifier];
}

- (void)lock:(UIUserInterfaceIdiom)lock
{
	%orig();
	[[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:[NSBundle bundleForClass:[RotationSwitch class]].bundleIdentifier];
}

%end

%end

#pragma mark Preferences

static void ReloadPreferences()
{
	NSDictionary *dict = [[NSDictionary alloc] initWithContentsOfFile:@kSettingsFilePath];
	rotationEnabled = [[dict objectForKey:@"RotationEnabled"] boolValue];
	[dict release];
}

#pragma mark Switch

@implementation RotationSwitch

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	if (IsOS4)
		return ![[%c(SBOrientationLockManager) sharedInstance] isLocked];
	else
		return rotationEnabled;
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
			[lockManager lock:[(SpringBoard *)[UIApplication sharedApplication] activeInterfaceOrientation]];
			if ([lockManager respondsToSelector:@selector(lockOverrideEnabled)] ? [lockManager lockOverrideEnabled] : [lockManager lockOverride]) {
				if ([lockManager respondsToSelector:@selector(setLockOverrideEnabled:forReason:)]) {
					for (id reason in [[CHIvar(lockManager, _lockOverrideReasons, NSMutableSet *) copy] autorelease])
						[lockManager setLockOverrideEnabled:NO forReason:reason];
				} else {
					[lockManager setLockOverride:0 orientation:UIDeviceOrientationPortrait];
				}
			}
		}
		SBNowPlayingBar **nowPlayingBar = CHIvarRef([%c(SBAppSwitcherController) sharedInstanceIfAvailable], _nowPlaying, SBNowPlayingBar *);
		if (nowPlayingBar)
			[CHIvar(*nowPlayingBar, _orientationLockButton, UIButton *) setSelected:[lockManager isLocked]];
	} else {
		NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithContentsOfFile:@kSettingsFilePath];
		if (!dict)
			dict = [[NSMutableDictionary alloc] init];
		[dict setObject:[NSNumber numberWithBool:newState] forKey:@"RotationEnabled"];
		NSData *data = [NSPropertyListSerialization dataFromPropertyList:dict format:NSPropertyListBinaryFormat_v1_0 errorDescription:NULL];
		[dict release];
		[data writeToFile:@kSettingsFilePath options:NSAtomicWrite error:NULL];
		notify_post(kSettingsChangeNotification);
		[[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:[NSBundle bundleForClass:[RotationSwitch class]].bundleIdentifier];
	}
}

- (void)applyAlternateActionForSwitchIdentifier:(NSString *)switchIdentifier
{
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

@end

// OS 3.x

%group iOS3

%hook UIApplication

- (void)handleEvent:(GSEventRef)gsEvent withNewEvent:(UIEvent *)newEvent
{
	if (gsEvent)
		if (GSEventGetType(gsEvent) == 50)
			if (!rotationEnabled)
				return;
	%orig();
}

%end

%end

CHConstructor
{
	%init();
	if (IsOS4) {
		%init(iOS4);
	} else {
		%init(iOS3);
		ReloadPreferences();
		CFNotificationCenterAddObserver(
			CFNotificationCenterGetDarwinNotifyCenter(),
			NULL,
			(void (*)(CFNotificationCenterRef, void *, CFStringRef, const void *, CFDictionaryRef))ReloadPreferences,
			CFSTR(kSettingsChangeNotification),
			NULL,
			CFNotificationSuspensionBehaviorHold
		);
	}
}


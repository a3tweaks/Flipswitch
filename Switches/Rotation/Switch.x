#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CaptainHook/CaptainHook.h>
#import <GraphicsServices/GraphicsServices.h>
//#import <SpringBoard/SpringBoard.h>

#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>

#include <notify.h>
#include <dlfcn.h>

#define IsOS4 (kCFCoreFoundationVersionNumber >= 478.61)
static BOOL (*isEnabled)(void);
static void (*setEnabled)(BOOL newState);

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

@interface RotationSwitch : NSObject <FSSwitchDataSource>
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
					[lockManager setLockOverride:0 orientation:UIInterfaceOrientationPortrait];
				}
			}
		}
		SBNowPlayingBar **nowPlayingBar = CHIvarRef([%c(SBAppSwitcherController) sharedInstanceIfAvailable], _nowPlaying, SBNowPlayingBar *);
		if (nowPlayingBar) {
			UIButton **_orientationLockButton = CHIvarRef(*nowPlayingBar, _orientationLockButton, UIButton *);
			if (_orientationLockButton) {
				[*_orientationLockButton setSelected:[lockManager isLocked]];
			}
		}
	} else {
		if (setEnabled) {
			setEnabled(newState);
			[[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:[NSBundle bundleForClass:[RotationSwitch class]].bundleIdentifier];
		}
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

CHConstructor
{
	%init();
	if (!IsOS4) {
		void *rotationinhibitor = dlopen("/Library/MobileSubstrate/DynamicLibraries/RotationInhibitor.dylib", RTLD_LAZY);
		isEnabled = dlsym(rotationinhibitor, "isEnabled");
		setEnabled = dlsym(rotationinhibitor, "setEnabled");
	}
}


#import <UIKit/UIKit.h>

@interface SpringBoard : UIApplication
- (void)_relaunchSpringBoardNow;
- (void)reboot;
- (void)powerDown;
- (UIInterfaceOrientation)activeInterfaceOrientation;
@end

@interface SBTelephonyManager
+ (SBTelephonyManager *)sharedTelephonyManager;
- (void)setIsInAirplaneMode:(BOOL)airplaneMode;
- (BOOL)isInAirplaneMode;
@end

@interface SBWiFiManager
+ (id)sharedInstance;
- (BOOL)wiFiEnabled;
- (void)setWiFiEnabled:(BOOL)enabled;
@end

@interface SBStatusBarController
+ (SBStatusBarController *)sharedStatusBarController;
- (BOOL)airplaneModeIsEnabled;
@end

@interface SBIconLabel : UILabel
@end

@interface SBIcon : NSObject
@end

@interface SBApplicationIcon : SBIcon
@end

@interface SBMediaController
+ (id)sharedInstance;
- (BOOL)isRingerMuted;
- (void)setRingerMuted:(BOOL)muted;
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

@interface SBUIController : NSObject
+ (id)sharedInstance;
- (SBAppSwitcherController *)switcherController;
@end

@interface SBNowPlayingBarView (iOS43)
@property (assign, nonatomic) NSInteger switchType;
@property (readonly, assign, nonatomic) UIButton *switchButton;
@end

typedef struct {
	BOOL itemIsEnabled[24];
	BOOL timeString[64];
	int gsmSignalStrengthRaw;
	int gsmSignalStrengthBars;
	BOOL serviceString[100];
	BOOL serviceCrossfadeString[100];
	BOOL serviceImages[2][100];
	BOOL operatorDirectory[1024];
	unsigned serviceContentType;
	int wifiSignalStrengthRaw;
	int wifiSignalStrengthBars;
	unsigned dataNetworkType;
	int batteryCapacity;
	unsigned batteryState;
	BOOL batteryDetailString[150];
	int bluetoothBatteryCapacity;
	int thermalColor;
	unsigned thermalSunlightMode : 1;
	unsigned slowActivity : 1;
	unsigned syncActivity : 1;
	BOOL activityDisplayId[256];
	unsigned bluetoothConnected : 1;
	unsigned displayRawGSMSignal : 1;
	unsigned displayRawWifiSignal : 1;
	unsigned locationIconType : 1;
} SBStatusBarData;


@interface SBStatusBarDataManager : NSObject {
	SBStatusBarData _data;
	int _actions;
	BOOL _itemIsEnabled[24];
	BOOL _itemIsCloaked[24];
	BOOL _telephonyAndBluetoothCloaked;
	BOOL _allButBatteryCloaked;
	BOOL _timeCloaked;
	int _updateBlockDepth;
	BOOL _dataChangedSinceLastPost;
	NSDateFormatter* _timeItemDateFormatter;
	NSTimer* _timeItemTimer;
	NSString* _timeItemTimeString;
	BOOL _simulateInCallStatusBar;
	NSString* _serviceString;
	NSString* _serviceCrossfadeString;
	NSString* _serviceImages[2];
	NSString* _operatorDirectory;
	BOOL _showsActivityIndicatorOnHomeScreen;
	BOOL _showsActivityIndicatorForNewsstand;
	int _syncActivityIndicatorCount;
	int _activityIndicatorEverywhereCount;
	int _thermalColor;
	BOOL _thermalSunlightMode;
	NSString* _recordingAppString;
	BOOL _showingNotChargingItem;
	NSString* _batteryDetailString;
}
+ (id)sharedDataManager;
- (BOOL)_shouldShowEmergencyOnlyStatus;
- (BOOL)_getServiceImageNames:(id [2])names directory:(id *)directory forOperator:(id)anOperator statusBarCarrierName:(id *)name;
- (id)_displayStringForRegistrationStatus:(int)registrationStatus;
- (id)_displayStringForSIMStatus:(id)simstatus;
- (BOOL)_simStatusMeansLocked:(id)locked;
- (void)switchSimulatesInCallStatusBar;
- (void)_updateTelephonyState;
- (void)_updateBatteryDetail;
- (BOOL)_shouldShowNotChargingItem;
- (void)_restartTimeItemTimer;
- (void)_stopTimeItemTimer;
- (void)_configureTimeItemDateFormatter;
- (void)_assistantChange;
- (void)_quietModeChange;
- (void)_rotationLockChange;
- (void)_locationStatusChange;
- (void)_bluetoothBatteryChange;
- (void)_bluetoothChange;
- (void)airplaneModeChanged;
- (void)_dataConnectionTypeChange;
- (void)_dataNetworkChange;
- (void)_vpnChange;
- (void)_callForwardingChange;
- (void)_ttyChange;
- (void)_signalStrengthChange;
- (void)_operatorChange;
- (void)_notChargingStatusChange;
- (void)_batteryStatusChange;
- (void)_didWakeFromSleep;
- (void)_localeChanged;
- (void)_significantTimeChanged;
- (void)_registerForNotifications;
- (void)_updateThermalColorItem;
- (void)_updateAssistantItem;
- (void)_updateQuietModeItem;
- (void)_updateRotationLockItem;
- (void)_updateLocationItem;
- (void)_updatePlayItem;
- (void)_updateActivityItem;
- (void)_updateCallForwardingItem;
- (void)_updateVPNItem;
- (void)_updateTTYItem;
- (void)_updateBluetoothBatteryItem;
- (void)_updateBluetoothItem;
- (void)_updateBatteryItems;
- (void)_updateDataNetworkItem;
- (void)_updateServiceItem;
- (void)_updateSignalStrengthItem;
- (void)_updateAirplaneMode;
- (void)_updateTimeItem;
- (void)_updateTimeString;
- (void)_postData;
- (void)_dataChanged;
- (const SBStatusBarData *)currentData;
- (void)resetData;
- (void)setThermalColor:(int)color sunlightMode:(BOOL)mode;
- (void)setTimeCloaked:(BOOL)cloaked;
- (void)setAllItemsExceptBatteryCloaked:(BOOL)cloaked;
- (void)setTelephonyAndBluetoothItemsCloaked:(BOOL)cloaked;
- (void)_updateCloakedItems;
- (void)setShowsSyncActivityIndicator:(BOOL)indicator;
- (void)setShowsActivityIndicatorEverywhere:(BOOL)everywhere;
- (void)setShowsActivityIndicatorOnHomeScreen:(BOOL)screen;
- (void)setShowsActivityIndicatorForNewsstand:(BOOL)newsstand;
- (void)enableTime:(BOOL)time crossfade:(BOOL)crossfade crossfadeDuration:(double)duration;
- (void)enableTime:(BOOL)time;
- (BOOL)isTimeEnabled;
- (void)sendStatusBarActions:(int)actions;
- (void)updateStatusBarItem:(int)item;
- (BOOL)setStatusBarItem:(int)item enabled:(BOOL)enabled;
- (void)endUpdateBlock;
- (void)beginUpdateBlock;
- (void)dealloc;
- (instancetype)init;
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

@interface BluetoothManager
+ (BluetoothManager *)sharedInstance;
- (BOOL)powered;
- (BOOL)setPowered:(BOOL)powered;
- (void)setEnabled:(BOOL)enabled;
@end

@interface NSNetworkSettings : NSObject
+ (NSNetworkSettings *)sharedNetworkSettings;
- (void)setProxyDictionary:(NSDictionary *)dictionary;
- (BOOL)connectedToInternet:(BOOL)unknown;
- (void)setProxyPropertiesForURL:(NSURL *)url onStream:(CFReadStreamRef)stream;
- (BOOL)isProxyNeededForURL:(NSURL *)url;
- (NSDictionary *)proxyPropertiesForURL:(NSURL *)url;
- (NSDictionary *)proxyDictionary;
- (void)_listenForProxySettingChanges;
- (void)_updateProxySettings;
@end

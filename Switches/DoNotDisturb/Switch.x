#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>

#import <Foundation/Foundation.h>
#include <dispatch/dispatch.h>
#include <dlfcn.h>

@interface BBSettingsGateway : NSObject {
	id _serverProxy;
	id _overrideStatusChangeHandler;
	id _activeOverrideTypesChangedHandler;
}
+ (void)initialize;
- (void)setBehaviorOverridesEnabled:(BOOL)enabled;
- (void)getBehaviorOverridesEnabledWithCompletion:(void (^)(int value))completion;
- (void)activeBehaviorOverrideTypesChanged:(unsigned)changed;
- (void)behaviorOverrideStatusChanged:(int)changed;
- (id)proxy:(id)proxy detailedSignatureForSelector:(SEL)selector;
- (void)setPrivilegedSenderAddressBookGroupRecordID:(int)anId name:(id)name;
- (void)setPrivilegedSenderTypes:(unsigned)types;
- (void)setBehaviorOverrideStatus:(int)status;
- (void)setBehaviorOverrides:(id)overrides;
- (void)setSectionInfo:(id)info forSectionID:(id)sectionID;
- (void)setOrderedSectionIDs:(id)ids;
- (void)setSectionOrderRule:(unsigned)rule;
- (void)setActiveBehaviorOverrideTypesChangeHandler:(void (^)(int value))handler;
- (void)setBehaviorOverrideStatusChangeHandler:(void (^)(int value))handler;
- (void)getPrivilegedSenderAddressBookGroupRecordIDAndNameWithCompletion:(id)completion;
- (void)getPrivilegedSenderTypesWithCompletion:(id)completion;
- (void)getBehaviorOverridesWithCompletion:(void (^)(NSArray *value))completion;
- (void)getSectionOrderRuleWithCompletion:(void (^)(unsigned value))completion;
- (void)getSectionInfoWithCompletion:(void (^)(int value))completion;
- (void)dealloc;
- (id)init;
@end

@interface BBSettingsGateway (iOS7)
- (id)initWithQueue:(dispatch_queue_t)queue;
@end

@interface BBBehaviorOverride : NSObject <NSCopying, NSCoding> {
@private
	unsigned _overrideType;
	unsigned _mode;
	NSArray *_effectiveIntervals;
}
@property (copy, nonatomic) NSArray *effectiveIntervals;
@property (assign, nonatomic) unsigned mode;
@property (assign, nonatomic) unsigned overrideType;
- (NSDate *)nextOverrideTransitionDateAfterDate:(NSDate *)date;
- (BOOL)isActiveForDate:(NSDate *)date;
- (NSString *)description;
- (id)initWithOverrideType:(unsigned)overrideType mode:(unsigned)mode effectiveIntervals:(NSArray *)effectiveIntervals;
- (id)initWithEffectiveIntervals:(NSArray *)effectiveIntervals overrideType:(unsigned)type;
@end

@class BBSystemStateProvider;
@interface SBBulletinSystemStateAdapter : NSObject {
	BBSystemStateProvider *_stateProvider;
	BBSettingsGateway *_settingsGateway;
	BOOL _quietModeEnabled;
}
+ (SBBulletinSystemStateAdapter *)sharedInstanceIfExists;
+ (SBBulletinSystemStateAdapter *)sharedInstance;
- (void)_lostModeStateChanged;
- (void)_screenDimmed:(id)notification;
- (void)_lockStateChanged:(id)notification;
- (BOOL)quietModeEnabled;
- (void)_activeBehaviorOverrideTypesChanged:(unsigned)newValue;
- (void)dealloc;
- (id)init;
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
- (id)init;
@end

static void (*BKSTerminateApplicationForReasonAndReportWithDescription)(NSString *app, int a, int b, NSString *description);

@interface DoNotDisturbSwitch : NSObject <FSSwitchDataSource>
@end

static BBSettingsGateway *gateway;
static FSSwitchState state;

@implementation DoNotDisturbSwitch

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	return state;
}

- (void)applyMode:(unsigned)mode
{
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

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	switch (newState) {
		case FSSwitchStateIndeterminate:
			break;
		case FSSwitchStateOn:
			state = FSSwitchStateOn;
			[self applyMode:1];
			break;
		case FSSwitchStateOff:
			state = FSSwitchStateOff;
			[self applyMode:0];
			/*[gateway getBehaviorOverridesWithCompletion:^(NSArray *overrides) {
				if ([overrides count]) {
					BBBehaviorOverride *override = [overrides objectAtIndex:0];
					[self applyMode:override.mode ? 2 : 0];
				} else {
					[self applyMode:0];
				}
			}];*/
			break;
	}
}

@end

%ctor
{
	state = FSSwitchStateIndeterminate;
	dispatch_async(dispatch_get_main_queue(), ^{
		if ([BBSettingsGateway instancesRespondToSelector:@selector(initWithQueue:)])
			gateway = [[BBSettingsGateway alloc] initWithQueue:dispatch_get_main_queue()];
		else
			gateway = [[BBSettingsGateway alloc] init];
		[gateway getBehaviorOverridesWithCompletion:^(NSArray *overrides) {
		}];
		[gateway setActiveBehaviorOverrideTypesChangeHandler:^(int value){
			state = value & 1;
			[[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:[NSBundle bundleForClass:[DoNotDisturbSwitch class]].bundleIdentifier];
		}];
		BKSTerminateApplicationForReasonAndReportWithDescription = dlsym(RTLD_DEFAULT, "BKSTerminateApplicationForReasonAndReportWithDescription");
	});
}

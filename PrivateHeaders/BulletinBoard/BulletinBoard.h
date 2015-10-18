#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

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

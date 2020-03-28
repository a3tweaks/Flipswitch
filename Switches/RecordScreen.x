#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>

#ifdef __arm64__

#import <ReplayKit/ReplayKit.h>
#import <dlfcn.h>
#import <SpringBoard/SpringBoard.h>

@interface RPScreenRecorder (iOS13)
- (void)stopRecordingAndSaveToCameraRoll:(BOOL)save;
@end

@interface CCUIShortcutModule : NSObject
@end

@interface CCUIRecordScreenShortcut : CCUIShortcutModule <RPScreenRecorderDelegate>

+ (NSString *)displayName;
+ (NSString *)identifier;
+ (BOOL)isInternalButton;
+ (BOOL)isSupported:(int)argument;

- (void)_startRecording;
- (void)_stopRecording;
- (bool)_toggleState;
- (void)activate;
- (void)deactivate;
- (void)warmup;
- (void)cooldown;

@end

@interface CCUIShortcutModule (RPControlCenterModule)
@property (nonatomic, readonly) RPControlCenterClient *client;
@end

static CCUIRecordScreenShortcut *staticRecordScreenShortcut;

static CCUIRecordScreenShortcut *sharedRecordScreenShortcut(void)
{
	if (!staticRecordScreenShortcut) {
		[[[%c(CCUIRecordScreenShortcut) alloc] init] autorelease];
	}
	return staticRecordScreenShortcut;
}

static void assignRecordScreenShortcut(CCUIRecordScreenShortcut *newValue)
{
	if (newValue != staticRecordScreenShortcut) {
		CCUIRecordScreenShortcut *oldValue = staticRecordScreenShortcut;
		staticRecordScreenShortcut = [newValue retain];
		[oldValue release];
	}
}

static RPScreenRecorder *sharedRecorder(void)
{
	return [%c(RPScreenRecorder) sharedRecorder];
}

%hook RPScreenRecorder

- (void)updateScreenRecordingState:(BOOL)newState
{
	%orig();
	[[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:@"com.a3tweaks.switch.record-screen"];
}

%end

%hook CCUIRecordScreenShortcut

+ (BOOL)isSupported:(int)something
{
	%orig();
	return sharedRecorder().isAvailable;
}

- (id)init
{
	self = %orig();
	assignRecordScreenShortcut(self);
	return self;
}

- (void)setEnabled:(BOOL)enabled
{
	assignRecordScreenShortcut(self);
	%orig();
	[[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:@"com.a3tweaks.switch.record-screen"];
}

- (void)warmup
{
	assignRecordScreenShortcut(self);
	%orig();
}

%end

@interface RecordScreenSwitch : NSObject <FSSwitchDataSource>
@end

@implementation RecordScreenSwitch

- (id)init
{
	if ((self = [super init])) {
		dlopen("/System/Library/ControlCenter/Bundles/ReplayKitModule.bundle/ReplayKitModule", RTLD_LAZY);
		if (!sharedRecorder().isAvailable) {
			[self release];
			return nil;
		}
		%init(CCUIRecordScreenShortcut = objc_getClass("CCUIRecordScreenShortcut") ?: objc_getClass("RPControlCenterModule"));
	}
	return self;
}

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	return sharedRecorder().recording;
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (newState == FSSwitchStateIndeterminate)
		return;
	if (sharedRecorder().recording != newState) {
		CCUIRecordScreenShortcut *shortcut = sharedRecordScreenShortcut();
		if ([shortcut respondsToSelector:@selector(_toggleState)]) {
			[shortcut _toggleState];
		} else {
			Class clientClass = %c(RPControlCenterClient);
			if ([clientClass respondsToSelector:@selector(sharedInstance)]) {
				RPControlCenterClient *client = (RPControlCenterClient *)[clientClass sharedInstance];
				if (newState == FSSwitchStateOn) {
					[client startRecordingWithHandler:nil];
				} else {
					[client stopCurrentSession:nil];
				}
			} else {
				if (newState == FSSwitchStateOn) {
					[sharedRecorder() startRecordingWithHandler:nil];
				} else {
					[sharedRecorder() stopRecordingAndSaveToCameraRoll:nil];
				}
			}
		}
	}
}

- (void)beginPrewarmingForSwitchIdentifier:(NSString *)switchIdentifier
{
	[sharedRecordScreenShortcut() warmup];
}

- (void)cancelPrewarmingForSwitchIdentifier:(NSString *)switchIdentifier
{
	[sharedRecordScreenShortcut() cooldown];
}

@end

#endif

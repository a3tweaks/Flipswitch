#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>

#ifdef __arm64__

#import <ReplayKit/ReplayKit.h>

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
		if (!sharedRecorder().isAvailable) {
			[self release];
			return nil;
		}
		%init();
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
		[sharedRecordScreenShortcut() _toggleState];
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

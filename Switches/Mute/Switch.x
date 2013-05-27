#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>

@interface SBMediaController
+ (id)sharedInstance;
- (BOOL)isRingerMuted;
- (void)setRingerMuted:(BOOL)muted;
@end

@interface MuteSwitch : NSObject <FSSwitchDataSource>
@end

@implementation MuteSwitch

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	return ![[%c(SBMediaController) sharedInstance] isRingerMuted];
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (newState == FSSwitchStateIndeterminate)
		return;
	[[%c(SBMediaController) sharedInstance] setRingerMuted:!newState];
}

@end

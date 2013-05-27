#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>
#import "notify.h"

#define kSpringBoardPlist @"/private/var/mobile/Library/Preferences/com.apple.springboard.plist"

extern void GSSendAppPreferencesChanged(NSString *bundleID, NSString * key);

@interface VibrationSwitch : NSObject <FSSwitchDataSource>
@end

@implementation VibrationSwitch

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:kSpringBoardPlist];
    BOOL enabled = ([[dict valueForKey:@"ring-vibrate"] boolValue] && [[dict valueForKey:@"silent-vibrate"] boolValue]);

	return enabled;
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (newState == FSSwitchStateIndeterminate)
		return;
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithContentsOfFile:kSpringBoardPlist];
        
        [dict setValue:[NSNumber numberWithBool:newState] forKey:@"ring-vibrate"];
        [dict setValue:[NSNumber numberWithBool:newState] forKey:@"silent-vibrate"];
        [dict writeToFile:kSpringBoardPlist atomically:YES];
        [dict release];
        
        notify_post("com.apple.springboard.ring-vibrate.changed");
        GSSendAppPreferencesChanged(@"com.apple.springboard", @"ring-vibrate");
        notify_post("com.apple.springboard.silent-vibrate.changed");
        GSSendAppPreferencesChanged(@"com.apple.springboard", @"silent-vibrate");
    });
}

@end

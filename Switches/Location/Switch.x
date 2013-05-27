#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>
#import "notify.h"

#define kLocationServicesPlist @"/private/var/mobile/Library/Preferences/com.apple.locationd.plist"

@interface LocationSwitch : NSObject <FSSwitchDataSource>
@end

@implementation LocationSwitch

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	BOOL enabled = [[[NSDictionary dictionaryWithContentsOfFile:kLocationServicesPlist] valueForKey:@"LocationServicesEnabled"] boolValue];
	return enabled;
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (newState == FSSwitchStateIndeterminate)
		return;

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithContentsOfFile:kLocationServicesPlist];
        [dict setValue:[NSNumber numberWithBool:newState] forKey:@"LocationServicesEnabled"];
        [dict writeToFile:kLocationServicesPlist atomically:YES];
        [dict release];
        
        notify_post("com.apple.locationd/Prefs");
    });
}

@end

// Note: newState always seems to be On when toggled
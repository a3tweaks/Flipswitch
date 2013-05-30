#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>

@interface SettingsSwitch : NSObject <FSSwitchDataSource>
@end

@implementation SettingsSwitch

- (void)applyActionForSwitchIdentifier:(NSString *)switchIdentifier
{
	[[FSSwitchPanel sharedPanel] openURLAsAlternateAction:[NSURL URLWithString:@"prefs:"]];
}

@end

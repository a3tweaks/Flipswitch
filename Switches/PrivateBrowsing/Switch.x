#import "FSSwitchDataSource.h"
#import "FSSwitchPanel.h"


#define kMobileSafariPlist @"/private/var/mobile/Library/Preferences/com.apple.mobilesafari.plist"


@interface PrivateBrowsingSwitch : NSObject <FSSwitchDataSource>
NSString *_title;
@end


@implementation PrivateBrowsingSwitch

- (id)init
{
    if ((self = [super init])) {
        _title = [[[NSBundle bundleWithPath:@"/System/Library/PreferenceBundles/MobileSafariSettings.bundle"] localizedStringForKey:@"Private Browsing" value:@"Private Browsing" table:@"Safari"] retain];
    }
    return self;
}

- (void)dealloc
{
    [_title release];
    
    [super dealloc];
}

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	return [[[NSDictionary dictionaryWithContentsOfFile:kMobileSafariPlist] objectForKey:@"PrivateBrowsing"] boolValue]? FSSwitchStateOn : FSSwitchStateOff;
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (newState == FSSwitchStateIndeterminate)
		return;
    
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithContentsOfFile:kMobileSafariPlist];
    [dict setValue:[NSNumber numberWithBool:newState==FSSwitchStateOn? YES : NO] forKey:@"PrivateBrowsing"];
    [dict writeToFile:kMobileSafariPlist atomically:YES];
    [dict release];
    
    GSSendAppPreferencesChanged(@"com.apple.mobilesafari", @"PrivateBrowsing");
}

- (NSString *)titleForSwitchIdentifier:(NSString *)switchIdentifier
{
    return _title;
}

@end
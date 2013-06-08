#import "FSSwitchDataSource.h"
#import "FSSwitchPanel.h"


#define kSpringBoardPlist @"/private/var/mobile/Library/Preferences/com.apple.springboard.plist"


@interface MultitaskingGesturesSwitch : NSObject <FSSwitchDataSource>
NSString *_title;
@end


@implementation MultitaskingGesturesSwitch

- (id)init
{
    if ((self = [super init])) {
        _title = [[[NSBundle bundleWithPath:@"/Applications/Preferences.app"] localizedStringForKey:@"Multitasking_Gestures" value:@"Multitasking Gestures" table:@"General"] retain];
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
	return [[[NSDictionary dictionaryWithContentsOfFile:kSpringBoardPlist] objectForKey:@"SBUseSystemGestures"] boolValue];
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (newState == FSSwitchStateIndeterminate)
		return;
    
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithContentsOfFile:kSpringBoardPlist];
    [dict setObject:[NSNumber numberWithInt:newState] forKey:@"SBUseSystemGestures"];
    [dict writeToFile:kSpringBoardPlist atomically:YES];
    [dict release];
    GSSendAppPreferencesChanged(@"com.apple.springboard", @"SBUseSystemGestures");
}

- (NSString *)titleForSwitchIdentifier:(NSString *)switchIdentifier
{
    return _title;
}

@end
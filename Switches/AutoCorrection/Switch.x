#import "FSSwitchDataSource.h"
#import "FSSwitchPanel.h"
#import <Foundation/Foundation.h>
#import <CoreGraphics/CGGeometry.h>
#import <Preferences/PSSpecifier.h>


#define kBundlePath @"/System/Library/PreferenceBundles/KeyboardSettings.bundle"

@interface KeyboardController
- (id)initForContentSize:(CGSize)size;
- (void)setKeyboardPreferenceValue:(id)arg1 forSpecifier:(id)arg2;
- (id)specifiers;
@end


@interface AutoCorrectionSwitch : NSObject <FSSwitchDataSource>
NSString *_title;
@end


@implementation AutoCorrectionSwitch

- (id)init
{
    if ((self = [super init])) {
        _title = [[[NSBundle bundleWithPath:kBundlePath] localizedStringForKey:@"Auto-Correction" value:@"Auto-Correction" table:@"Keyboard"] retain];
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
	return [[[NSDictionary dictionaryWithContentsOfFile:@"/private/var/mobile/Library/Preferences/com.apple.Preferences.plist"] objectForKey:@"KeyboardAutocorrection"] boolValue];
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (newState == FSSwitchStateIndeterminate)
		return;
    
    NSBundle *bundle = [[NSBundle bundleWithPath:kBundlePath] retain];
        if ([bundle load]) {
            id controller = [[[bundle classNamed:@"KeyboardController"] alloc] initForContentSize:CGSizeZero];
            if ([controller respondsToSelector:@selector(specifiers)]) {
                if ([[controller specifiers] count] >= 3) {
                    PSSpecifier *specifier = [[controller specifiers] objectAtIndex:2];
                    if (specifier && [controller respondsToSelector:@selector(setKeyboardPreferenceValue:forSpecifier:)]) {
                        [controller setKeyboardPreferenceValue:[NSNumber numberWithInt:newState] forSpecifier:specifier];
                    }
                }
            }
            [controller release];
            [bundle unload];
        }
        [bundle release];
}

- (NSString *)titleForSwitchIdentifier:(NSString *)switchIdentifier
{
    return _title;
}

@end
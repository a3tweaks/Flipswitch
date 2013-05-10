#import "A3ToggleManager.h"

#define kTogglesPath @"/Library/Toggles/"

static A3ToggleManager *_toggleManager = nil;

@implementation A3ToggleManager

+ (void)initialize
{
    if ([self isEqual:[A3ToggleManager class]] && objc_getClass("SpringBoard") == nil) _toggleManager = [[A3ToggleManager alloc] init];
}

+ (A3ToggleManager *)sharedInstance
{
    return _toggleManager;
}

- (A3ToggleManager *)init
{
    if ((self = [super init]))
    {

    }
    return self;
}


- (void)dealloc
{    
    [super dealloc];
}

@end

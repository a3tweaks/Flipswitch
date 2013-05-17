#import "A3Toggle.h"

@implementation NSObject (A3Toggle)

- (NSString *)titleForToggleIdentifier:(NSString *)toggleIdentifier
{
	// TODO: Read from bundle/plist metadata
	return toggleIdentifier;
}

@end

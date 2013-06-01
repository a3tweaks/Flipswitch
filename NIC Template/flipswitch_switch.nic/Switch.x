#import "FSSwitchDataSource.h"
#import "FSSwitchPanel.h"

@interface @@PROJECTNAME@@Switch : NSObject <FSSwitchDataSource>
@end

@implementation @@PROJECTNAME@@Switch

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	return FSSwitchStateOn;
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (newState == FSSwitchStateIndeterminate)
		return;
}

@end
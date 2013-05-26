#import "FSSwitchPanel.h"

__attribute__((visibility("hidden")))
@interface FSSwitchMainPanel : FSSwitchPanel {
@private
	NSMutableDictionary *_switchImplementations;
	BOOL hasUpdatedSwitches;
}
@end


#import "FSSwitch.h"

__attribute__((visibility("hidden")))
@interface FSPreferenceSwitch : NSObject <FSSwitch> {
@private
	NSBundle *bundle;
	NSString *switchIdentifier_;
}
- (id)initWithBundle:(NSBundle *)bundle;
@end

#import "FSSwitch.h"

__attribute__((visibility("hidden")))
@interface FSLazySwitch : NSObject <FSSwitch> {
@private
	NSBundle *bundle;
}
- (id)initWithBundle:(NSBundle *)bundle;
@end

#import "FSSwitchDataSource.h"

// Private class. Do not interact with except through the defined API!
__attribute__((visibility("hidden")))
@interface _FSLazySwitch : NSObject <FSSwitchDataSource> {
@private
	NSBundle *bundle;
}
- (id)initWithBundle:(NSBundle *)bundle;
@end

#import "FSSwitchDataSource.h"

__attribute__((visibility("hidden")))
@interface FSLazySwitch : NSObject <FSSwitchDataSource> {
@private
	NSBundle *bundle;
}
- (id)initWithBundle:(NSBundle *)bundle;
@end

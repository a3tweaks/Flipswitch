#import "A3Toggle.h"

__attribute__((visibility("hidden")))
@interface A3LazyToggle : NSObject <A3Toggle> {
@private
	NSBundle *bundle;
}
- (id)initWithBundle:(NSBundle *)bundle;
@end

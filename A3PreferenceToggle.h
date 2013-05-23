#import "A3Toggle.h"

__attribute__((visibility("hidden")))
@interface A3PreferenceToggle : NSObject <A3Toggle> {
@private
	NSBundle *bundle;
	NSString *toggleIdentifier_;
}
- (id)initWithBundle:(NSBundle *)bundle;
@end

#import "FSSwitchDataSource.h"

__attribute__((visibility("hidden")))
@interface FSPreferenceSwitchDataSource : NSObject <FSSwitchDataSource> {
@private
	NSBundle *bundle;
	NSString *switchIdentifier_;
}
- (id)initWithBundle:(NSBundle *)bundle;
@end

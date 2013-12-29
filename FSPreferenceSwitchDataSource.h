#import "FSSwitchDataSource.h"

@interface FSPreferenceSwitchDataSource : NSObject <FSSwitchDataSource> {
@private
	NSBundle *bundle;
	NSString *switchIdentifier_;
}
- (id)initWithBundle:(NSBundle *)bundle;
@end

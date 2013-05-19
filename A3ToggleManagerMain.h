#import "A3ToggleManager.h"

__attribute__((visibility("hidden")))
@interface A3ToggleManagerMain : A3ToggleManager {
@private
	NSMutableDictionary *_toggleImplementations;
	BOOL hasUpdatedToggles;
}
@end


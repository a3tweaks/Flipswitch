#import "FSSwitchPanel.h"

// Private class. Do not interact with except through the defined API!
__attribute__((visibility("hidden")))
@interface FSSwitchMainPanel : FSSwitchPanel
- (void)postNotificationName:(NSString *)notificationName userInfo:(NSDictionary *)userInfo;
- (void)_loadBuiltInSwitches;
@end

__attribute__((visibility("hidden")))
extern NSMutableDictionary *_switchImplementations;

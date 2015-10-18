#import <FSSwitchDataSource.h>
#import "FSPreferenceSwitchDataSource.h"

@interface CLLocationManager : NSObject
@end

@interface CLLocationManager (iOS7)
+ (BOOL)locationServicesEnabled;
+ (void)setLocationServicesEnabled:(BOOL)newValue;
@end

@interface LocationSwitch : FSPreferenceSwitchDataSource <FSSwitchDataSource>
@end

@implementation LocationSwitch

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
    if (kCFCoreFoundationVersionNumber >= 800.0) {
        return [CLLocationManager locationServicesEnabled];
    }
    return [super stateForSwitchIdentifier:switchIdentifier];
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
    if (kCFCoreFoundationVersionNumber >= 800.0) {
        if (newState != FSSwitchStateIndeterminate) {
            [CLLocationManager setLocationServicesEnabled:(BOOL)newState];
        }
        return;
    }
    [super applyState:newState forSwitchIdentifier:switchIdentifier];
}

@end

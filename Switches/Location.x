#import <FSSwitchDataSource.h>
#import "FSPreferenceSwitchDataSource.h"

#import <CoreLocation/CoreLocation.h>

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

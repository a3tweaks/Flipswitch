#include_next <CoreLocation/CoreLocation.h>

@interface CLLocationManager (Private)
//+ (BOOL)locationServicesEnabled;
+ (void)setLocationServicesEnabled:(BOOL)newValue;
@end


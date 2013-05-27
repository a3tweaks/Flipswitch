#import "FSSwitchState.h"

NSString *NSStringFromFSSwitchState(FSSwitchState state)
{
	switch (state) {
		case FSSwitchStateOn:
			return @"on";
		case FSSwitchStateOff:
			return @"off";
		case FSSwitchStateIndeterminate:
		default:
			return @"indeterminate";
	}
}

FSSwitchState FSSwitchStateFromNSString(NSString *stateString)
{
	if ([stateString isEqualToString:@"on"])
		return FSSwitchStateOn;
	if ([stateString isEqualToString:@"off"])
		return FSSwitchStateOff;
	return FSSwitchStateIndeterminate;
}

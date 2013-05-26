#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>

@interface BluetoothManager
+ (id)sharedInstance;
- (void)_powerChanged;
- (BOOL)powered;
- (BOOL)setPowered:(BOOL)powered;
- (void)setEnabled:(BOOL)seenabled;
@end

@interface BluetoothSwitch : NSObject <FSSwitchDataSource>
@end

%hook BluetoothManager

- (void)_powerChanged
{
	%orig();
	[[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:[NSBundle bundleForClass:[BluetoothSwitch class]].bundleIdentifier];
}

%end

@implementation BluetoothSwitch

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	return [[%c(BluetoothManager) sharedInstance] powered];
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (newState == FSSwitchStateIndeterminate)
		return;
	[[%c(BluetoothManager) sharedInstance] setPowered:newState];
	[[%c(BluetoothManager) sharedInstance] setEnabled:newState];
}

@end

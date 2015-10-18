#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>

#import <SpringBoard/SpringBoard.h>

@interface BluetoothSwitch : NSObject <FSSwitchDataSource>
- (void)_bluetoothStateDidChange:(NSNotification *)notification;
@end

static FSSwitchState state;

@implementation BluetoothSwitch

- (id)init
{
    if ((self = [super init])) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_bluetoothStateDidChange:) name:@"BluetoothPowerChangedNotification" object:nil];
        state = [[%c(BluetoothManager) sharedInstance] powered];
    }

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [super dealloc];
}

- (void)_bluetoothStateDidChange:(NSNotification *)notification
{
    state = [[%c(BluetoothManager) sharedInstance] powered];
    [[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:[NSBundle bundleForClass:[self class]].bundleIdentifier];
}

#pragma mark - FSSwitchDataSource

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	return state;
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (newState == FSSwitchStateIndeterminate)
		return;
	state = newState;
	BluetoothManager *mrManager = [%c(BluetoothManager) sharedInstance];
	[mrManager setPowered:newState];
	[mrManager setEnabled:newState];
}

@end

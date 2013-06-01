#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>

#import <AVFoundation/AVFoundation.h>

@interface FlashlightSwitch : NSObject <FSSwitchDataSource>
@end

static AVCaptureDevice *currentDevice;

@implementation FlashlightSwitch

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	return currentDevice ? FSSwitchStateOn : FSSwitchStateOff;
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (newState == FSSwitchStateIndeterminate)
		return;
	if (newState) {
		if (currentDevice)
			return;
		for (AVCaptureDevice *device in [AVCaptureDevice devices]) {
			if (device.hasTorch && [device lockForConfiguration:NULL]) {
				[device setTorchMode:AVCaptureTorchModeOn];
				[device unlockForConfiguration];
				currentDevice = [device retain];
				return;
			}
		}
	} else {
		AVCaptureDevice *device = currentDevice;
		if (!device)
			return;
		currentDevice = nil;
		if ([device lockForConfiguration:NULL]) {
			[device setTorchMode:AVCaptureTorchModeOff];
			[device unlockForConfiguration];
		}
		[device release];
		device = nil;
	}
}

@end

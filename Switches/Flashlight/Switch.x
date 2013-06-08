#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>

#import <AVFoundation/AVFoundation.h>

@interface FlashlightSwitch : NSObject <FSSwitchDataSource>
NSString *_title;
@end

static AVCaptureDevice *currentDevice;

@implementation FlashlightSwitch

- (id)init
{
    if ((self = [super init])) {
        _title = [[NSBundle bundleWithPath:@"/System/Library/AccessibilityBundles/PhotoLibraryFramework.axbundle"] localizedStringForKey:@"flash.mode.button.format" value:@"Flash" table:@"Accessibility"];
        _title = [[_title substringToIndex:[_title length]-4] retain];
    }
    return self;
}

- (void)dealloc
{
    [_title release];
    
    [super dealloc];
} 

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

- (NSString *)titleForSwitchIdentifier:(NSString *)switchIdentifier
{
    return _title;
}

@end

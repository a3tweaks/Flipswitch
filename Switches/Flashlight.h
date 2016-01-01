#import <Foundation/Foundation.h>

typedef enum {
	FlashlightSwitchActionOn,
	FlashlightSwitchActionLowPower,
	FlashlightSwitchActionStrobe,
} FlashlightSwitchAction;

__attribute__((unused))
static NSString *TitleForAction(FlashlightSwitchAction action)
{
	switch (action) {
		case FlashlightSwitchActionOn:
			return @"On";
		case FlashlightSwitchActionLowPower:
			return @"Low Power";
		case FlashlightSwitchActionStrobe:
			return @"Strobe";
		default:
			return nil;
	}
}

__attribute__((unused))
static FlashlightSwitchAction ActionForKey(CFStringRef key, FlashlightSwitchAction defaultValue)
{
	CFPreferencesAppSynchronize(CFSTR("com.a3tweaks.switch.flashlight"));
	Boolean valid;
	CFIndex value = CFPreferencesGetAppIntegerValue(key, CFSTR("com.a3tweaks.switch.flashlight"), &valid);
	return valid ? value : defaultValue;
}


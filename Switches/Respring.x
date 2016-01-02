#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>

#import <SpringBoard/SpringBoard.h>
#import <UIKit/UIKit.h>

#import "Respring.h"

@interface RespringSwitch : NSObject <FSSwitchDataSource, UIAlertViewDelegate> {
	CFIndex lastChosenAction;
}
- (void)tryPerformActionWithValue:(CFIndex)value;
@end

@implementation RespringSwitch

static void PerformAction(CFIndex actionIndex)
{
	SpringBoard *sb = (SpringBoard *)[%c(SpringBoard) sharedApplication];
	switch (actionIndex) {
		case 0:
			[sb _relaunchSpringBoardNow];
			break;
		case 1:
			[sb reboot];
			break;
		case 2:
			[sb powerDown];
			break;
		case 3:
			[sb performSelector:@selector(enterSafeMode) withObject:nil afterDelay:0.0];
			break;
	}
}

- (void)applyActionForSwitchIdentifier:(NSString *)switchIdentifier
{
	CFPreferencesAppSynchronize(CFSTR("com.a3tweaks.switch.respring"));
	CFIndex value = CFPreferencesGetAppIntegerValue(CFSTR("DefaultAction"), CFSTR("com.a3tweaks.switch.respring"), NULL);
	[self tryPerformActionWithValue:value];
}

- (BOOL)hasAlternateActionForSwitchIdentifier:(NSString *)switchIdentifier
{
	Boolean valid;
	CFPreferencesAppSynchronize(CFSTR("com.a3tweaks.switch.respring"));
	CFIndex value = CFPreferencesGetAppIntegerValue(CFSTR("AlternateAction"), CFSTR("com.a3tweaks.switch.respring"), &valid);
	return valid && (value != 4);
}

- (void)applyAlternateActionForSwitchIdentifier:(NSString *)switchIdentifier
{
	Boolean valid;
	CFPreferencesAppSynchronize(CFSTR("com.a3tweaks.switch.respring"));
	CFIndex value = CFPreferencesGetAppIntegerValue(CFSTR("AlternateAction"), CFSTR("com.a3tweaks.switch.respring"), &valid);
	if (valid) {
		[self tryPerformActionWithValue:value];
	}
}

- (void)tryPerformActionWithValue:(CFIndex)value
{
	Boolean valid;
	Boolean confirmationValue = CFPreferencesGetAppBooleanValue(CFSTR("RequireConfirmation"), CFSTR("com.a3tweaks.switch.respring"), &valid);
	BOOL confirmationIsNeeded = valid ? (confirmationValue == TRUE ? YES : NO) : NO;
	if (!confirmationIsNeeded || value == 4) //Don't ask for confirmation if action == do nothing.
		PerformAction(value);
	else {
		lastChosenAction = value;
		NSString *message = [NSString stringWithFormat:@"Confirm %@",userStringFromAction(value)];
		[[[[UIAlertView alloc] initWithTitle:nil message:message delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Confirm",nil] autorelease] show];
	}
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (buttonIndex != [alertView cancelButtonIndex]) {
		PerformAction(lastChosenAction);
	}
}

@end

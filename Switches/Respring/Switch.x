#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>

@interface SpringBoard : UIApplication
- (void)_relaunchSpringBoardNow;
- (void)reboot;
- (void)powerDown;
@end

@interface RespringSwitch : NSObject <FSSwitchDataSource, UIAlertViewDelegate> {
	CFIndex lastChosenAction;
}
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

static NSString *userStringFromAction(CFIndex value)
{
	NSString *title;
	switch (value) {
		case 0:
			title = @"Respring";
			break;
		case 1:
			title = @"Restart";
			break;
		case 2:
			title = @"Power Off";
			break;
		case 3:
			title = @"Safe Mode";
			break;
		case 4:
			title = @"Do Nothing";
			break;
		default:
			title = nil;
			break;
	}
	return title;
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

@interface RespringSwitchSettingsViewController : UITableViewController <FSSwitchSettingsViewController> {
	CFIndex defaultAction;
	CFIndex alternateAction;
	BOOL confirmationCellChecked;
}
@end

@implementation RespringSwitchSettingsViewController

- (id)init
{
	if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
		defaultAction = CFPreferencesGetAppIntegerValue(CFSTR("DefaultAction"), CFSTR("com.a3tweaks.switch.respring"), NULL);
		Boolean valid;
		CFIndex value = CFPreferencesGetAppIntegerValue(CFSTR("AlternateAction"), CFSTR("com.a3tweaks.switch.respring"), &valid);
		alternateAction = valid ? value : 4;
		valid = NO;
		Boolean confirmationValue = CFPreferencesGetAppBooleanValue(CFSTR("RequireConfirmation"), CFSTR("com.a3tweaks.switch.respring"), &valid);
		confirmationCellChecked = valid ? confirmationValue : NO;
	}
	return self;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)table
{
	return 3;
}

- (NSString *)tableView:(UITableView *)table titleForHeaderInSection:(NSInteger)section
{
	switch (section) {
		case 0:
			return @"Tap Action";
		case 1:
			return @"Hold Action";
		case 2:
			return @"Options";
		default:
			return nil;
	}
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
	return section == 2 ? 1 : 5;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"] ?: [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"] autorelease];
	NSString *title;
	if (indexPath.section == 2)
		title = @"Confirmation";
	else {
		title = userStringFromAction(indexPath.row);
	}
	cell.textLabel.text = title;
	if (indexPath.section == 2) {
		cell.accessoryType = confirmationCellChecked ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
	}
	else {
		CFIndex value = indexPath.section ? alternateAction : defaultAction;
		cell.accessoryType = (value == indexPath.row) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
	}
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	NSInteger section = indexPath.section;
	NSInteger value = indexPath.row;
	CFStringRef key;
	if (section == 2) {
		key = CFSTR("RequireConfirmation");
		//Toggle cell checkmark
		[tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:section]].accessoryType = confirmationCellChecked ? UITableViewCellAccessoryNone : UITableViewCellAccessoryCheckmark;
		value = confirmationCellChecked ? 0 : 1;
		confirmationCellChecked = ! confirmationCellChecked;
	}
	else {
		if (section == 1) {
			key = CFSTR("AlternateAction");
			alternateAction = value;
		} else {
			key = CFSTR("DefaultAction");
			defaultAction = value;
		}
		for (NSInteger i = 0; i < 5; i++) {
			[tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:section]].accessoryType = (value == i) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
		}
	}
	CFPreferencesSetAppValue(key, (CFTypeRef)[NSNumber numberWithInteger:value], CFSTR("com.a3tweaks.switch.respring"));
	CFPreferencesAppSynchronize(CFSTR("com.a3tweaks.switch.respring"));
}

@end

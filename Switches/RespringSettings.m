#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>

#import <SpringBoard/SpringBoard.h>
#import <UIKit/UIKit.h>

#import "Respring.h"

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
		title = @"Require Confirmation";
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

#import "Flashlight.h"
#import "FSSwitchSettingsViewController.h"
#import <UIKit/UIKit.h>

__attribute__((visibility("hidden")))
@interface FlashlightSwitchSettingsViewController : UITableViewController <FSSwitchSettingsViewController> {
@private
	FlashlightSwitchAction defaultAction;
	FlashlightSwitchAction alternateAction;
}
@end

@implementation FlashlightSwitchSettingsViewController

- (id)init
{
	if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
		defaultAction = ActionForKey(CFSTR("DefaultAction"), 0);
		alternateAction = ActionForKey(CFSTR("AlternateAction"), 1);
	}
	return self;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)table
{
	return 2;
}

- (NSString *)tableView:(UITableView *)table titleForHeaderInSection:(NSInteger)section
{
	switch (section) {
		case 0:
			return @"Tap Action";
		case 1:
			return @"Hold Action";
		default:
			return nil;
	}
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
	return 3;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"] ?: [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"] autorelease];
	cell.textLabel.text = TitleForAction(indexPath.row);
	CFIndex value = indexPath.section ? alternateAction : defaultAction;
	cell.accessoryType = (value == indexPath.row) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	NSInteger section = indexPath.section;
	NSInteger value = indexPath.row;
	CFStringRef key;
	if (section) {
		key = CFSTR("AlternateAction");
		alternateAction = value;
	} else {
		key = CFSTR("DefaultAction");
		defaultAction = value;
	}
	for (NSInteger i = 0; i < 3; i++) {
		[tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:section]].accessoryType = (value == i) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
	}
	CFPreferencesSetAppValue(key, (CFTypeRef)[NSNumber numberWithInteger:value], CFSTR("com.a3tweaks.switch.flashlight"));
	CFPreferencesAppSynchronize(CFSTR("com.a3tweaks.switch.flashlight"));
}

@end

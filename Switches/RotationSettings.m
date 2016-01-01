#import "FSSwitchSettingsViewController.h"
#import <UIKit/UIKit.h>

@interface RotationSwitchSettingsViewController : UITableViewController <FSSwitchSettingsViewController>
@end

@implementation RotationSwitchSettingsViewController

- (id)init
{
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
	return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"] ?: [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"] autorelease];
	cell.textLabel.text = @"Support Landscape Lock";
	CFPreferencesAppSynchronize(CFSTR("com.a3tweaks.switch.rotation"));
	cell.accessoryType = CFPreferencesGetAppBooleanValue(CFSTR("DisableLandsapeLock"), CFSTR("com.a3tweaks.switch.rotation"), NULL) ? UITableViewCellAccessoryNone : UITableViewCellAccessoryCheckmark;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	BOOL newValue = (cell.accessoryType == UITableViewCellAccessoryCheckmark);
	cell.accessoryType = newValue ? UITableViewCellAccessoryNone : UITableViewCellAccessoryCheckmark;
	CFPreferencesSetAppValue(CFSTR("DisableLandsapeLock"), (CFTypeRef)[NSNumber numberWithBool:newValue], CFSTR("com.a3tweaks.switch.rotation"));
	CFPreferencesAppSynchronize(CFSTR("com.a3tweaks.switch.rotation"));
}

@end

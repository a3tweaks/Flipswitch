#import "FSSwitchSettingsViewController.h"
#import <UIKit/UIKit.h>
#import <notify.h>

__attribute__((visibility("hidden")))
@interface DataSpeedSwitchSettingsViewController : UITableViewController <FSSwitchSettingsViewController> {
@private
	NSInteger offDataRate;
	NSInteger onDataRate;
}
@end

static NSString * const supportedDataRates[] = {
	@"LTE/4G",
	@"3G",
	@"2G",
};

@implementation DataSpeedSwitchSettingsViewController

- (id)init
{
	if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
		Boolean valid;
		// settings are stored in the normal (ascending) order
		CFIndex value = CFPreferencesGetAppIntegerValue(CFSTR("onDataRate"), CFSTR("com.a3tweaks.switch.dataspeed"), &valid);
		onDataRate = valid ? value : 0; // default to 4G, settings are only available if 4G is supported
		value = CFPreferencesGetAppIntegerValue(CFSTR("offDataRate"), CFSTR("com.a3tweaks.switch.dataspeed"), &valid);
		offDataRate = valid ? value : 1; // default to 3G
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
			return @"Enabled Data Rate";
		case 1:
			return @"Disabled Data Rate";
		default:
			return nil;
	}
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
	return sizeof(supportedDataRates) / sizeof(*supportedDataRates);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"] ?: [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"] autorelease];
	[cell.textLabel setText:supportedDataRates[indexPath.row]];
	CFIndex value = indexPath.section ? offDataRate : onDataRate;
	cell.accessoryType = (value == indexPath.row) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	NSInteger section = indexPath.section;
	NSInteger row = indexPath.row;

	// ON must be > OFF
	if (section) {
		if (row <= onDataRate) {
			return;
		}
	} else {
		if (row >= offDataRate) {
			return;
		}
	}

	CFStringRef key;
	NSInteger oldRow;
	if (indexPath.section) {
		key = CFSTR("offDataRate");
		oldRow = offDataRate;
		offDataRate = row;
	} else {
		key = CFSTR("onDataRate");
		oldRow = onDataRate;
		onDataRate = row;
	}
	CFPreferencesSetAppValue(key, (CFTypeRef)[NSNumber numberWithInteger:row], CFSTR("com.a3tweaks.switch.dataspeed"));
	CFPreferencesAppSynchronize(CFSTR("com.a3tweaks.switch.dataspeed"));
	notify_post("com.a3tweaks.switch.dataspeed");

	[tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:oldRow inSection:section]].accessoryType = UITableViewCellAccessoryNone;
	[tableView cellForRowAtIndexPath:indexPath].accessoryType = UITableViewCellAccessoryCheckmark;
}

@end

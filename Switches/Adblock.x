#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>

#import <Foundation/Foundation.h>
#import <SpringBoard/SpringBoard.h>

#define kAdBlockIdentifier @"com.futuremind.adblock"

static SBApplication *adBlockApp(void)
{
	SBApplicationController *ac = [%c(SBApplicationController) sharedInstance];
	if (![ac respondsToSelector:@selector(applicationWithBundleIdentifier:)]) {
		return nil;
	}
	return [ac applicationWithBundleIdentifier:kAdBlockIdentifier];
}

static SBSApplicationShortcutItem *availableShortcutItem(SBApplication *app)
{
	NSArray *dynamicShortcuts;
	if ([app respondsToSelector:@selector(dynamicApplicationShortcutItems)]) {
		dynamicShortcuts = app.dynamicApplicationShortcutItems;
	} else if ([app respondsToSelector:@selector(dynamicShortcutItems)]) {
		dynamicShortcuts = app.dynamicShortcutItems;
	} else {
		dynamicShortcuts = nil;
	}
	if ([dynamicShortcuts count] == 0) {
		return nil;
	}
	return [dynamicShortcuts objectAtIndex:0];
}

// Maintain a "pending state" that times out after a few seconds
// Activating/deactivating is asynchronous and we want the state of the switch to remain consistent in the meantime
static uint32_t pendingState;

static void ResetPendingState(void *something)
{
	pendingState = 0;
	[[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:@"com.a3tweaks.switch.futuremind-adblock"];
}

%hook SBApplication

- (void)setDynamicApplicationShortcutItems:(NSArray *)shortcutItems
{
	if ([self.bundleIdentifier isEqualToString:kAdBlockIdentifier]) {
		%orig();
		ResetPendingState(NULL);
	} else {
		%orig();
	}
}

- (void)setDynamicShortcutItems:(NSArray *)shortcutItems
{
	if ([self.bundleIdentifier isEqualToString:kAdBlockIdentifier]) {
		%orig();
		ResetPendingState(NULL);
	} else {
		%orig();
	}
}

%end

@interface FuturemindAdBlockSwitch : NSObject <FSSwitchDataSource>
@end

@implementation FuturemindAdBlockSwitch

- (id)init
{
	if ([availableShortcutItem(adBlockApp()) respondsToSelector:@selector(type)]) {
		%init();
		return [super init];
	} else {
		[self release];
		return nil;
	}
}

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	SBSApplicationShortcutItem *item = availableShortcutItem(adBlockApp());
	if (!item)
		return FSSwitchStateIndeterminate;
	if (pendingState)
		return pendingState - 1;
	NSString *type = item.type;
	if ([type isEqualToString:@"EnableConfigShortcutType"])
		return FSSwitchStateOff;
	if ([type isEqualToString:@"DisableConfigShortcutType"])
		return FSSwitchStateOn;
	return FSSwitchStateIndeterminate;
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (newState == FSSwitchStateIndeterminate)
		return;
	if ([self stateForSwitchIdentifier:switchIdentifier] == newState)
		return;
	SBApplication *application = adBlockApp();
	SBSApplicationShortcutItem *shortcutItem = availableShortcutItem(application);
	if (!shortcutItem)
		return;
	pendingState = newState + 1;
	dispatch_after_f(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 5), dispatch_get_main_queue(), NULL, ResetPendingState);
	Class SBIconControllerClass = %c(SBIconController);
	if ([SBIconControllerClass instancesRespondToSelector:@selector(_activateShortcutItem:fromApplication:)]) {
		SBIconController *iconController = (SBIconController *)[%c(SBIconController) sharedInstance];
		[iconController _activateShortcutItem:shortcutItem fromApplication:application];
	} else {
		static FBSOpenApplicationService *service;
		if (!service) {
			service = [[%c(FBSOpenApplicationService) alloc] init];
		}
		UIHandleApplicationShortcutAction *shortcutAction = [[[%c(UIHandleApplicationShortcutAction) alloc] initWithSBSShortcutItem:shortcutItem] autorelease];
		NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSArray arrayWithObject:shortcutAction], @"__Actions", nil];
		[service openApplication:kAdBlockIdentifier withOptions:[%c(FBSOpenApplicationOptions) optionsWithDictionary:options] completion:nil];
	}
}

@end

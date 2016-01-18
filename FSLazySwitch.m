#import "FSLazySwitch.h"
#import "FSSwitchPanel.h"
#import "FSSwitchMainPanel.h"

@implementation _FSLazySwitch

- (id)initWithBundle:(NSBundle *)_bundle
{
	if ((self = [super init])) {
		bundle = [_bundle retain];
	}
	return self;
}

- (void)dealloc
{
	[bundle release];
	[super dealloc];
}

- (void)lazyLoadWithSwitchIdentifier:(NSString *)switchIdentifier
{
	Class switchClass = [bundle principalClass] ?: NSClassFromString([bundle objectForInfoDictionaryKey:@"NSPrincipalClass"]);

	[[self retain] autorelease];

	id<FSSwitchDataSource> switchImplementation = [switchClass respondsToSelector:@selector(initWithBundle:)] ? [[switchClass alloc] initWithBundle:bundle] : [[switchClass alloc] init];
	if (switchImplementation) {
		[[FSSwitchPanel sharedPanel] registerDataSource:switchImplementation forSwitchIdentifier:switchIdentifier];
		[switchImplementation release];
	} else if (![_switchImplementations objectForKey:switchIdentifier]) {
		[[FSSwitchPanel sharedPanel] unregisterSwitchIdentifier:switchIdentifier];
		NSLog(@"Flipswitch: Lazy switch with identifier '%@' was unregistered because it failed to load!", switchIdentifier);
	}
}

- (NSBundle *)bundleForSwitchIdentifier:(NSString *)switchIdentifier
{
	return bundle;
}

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	[self lazyLoadWithSwitchIdentifier:switchIdentifier];
	return [[FSSwitchPanel sharedPanel] stateForSwitchIdentifier:switchIdentifier];
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	[self lazyLoadWithSwitchIdentifier:switchIdentifier];
	[[FSSwitchPanel sharedPanel] setState:newState forSwitchIdentifier:switchIdentifier];
}

- (void)applyActionForSwitchIdentifier:(NSString *)switchIdentifier
{
	[self lazyLoadWithSwitchIdentifier:switchIdentifier];
	[[FSSwitchPanel sharedPanel] applyActionForSwitchIdentifier:switchIdentifier];
}

- (BOOL)hasAlternateActionForSwitchIdentifier:(NSString *)switchIdentifier
{
	[self lazyLoadWithSwitchIdentifier:switchIdentifier];
	return [[FSSwitchPanel sharedPanel] hasAlternateActionForSwitchIdentifier:switchIdentifier];
}

- (void)applyAlternateActionForSwitchIdentifier:(NSString *)switchIdentifier
{
	[self lazyLoadWithSwitchIdentifier:switchIdentifier];
	[[FSSwitchPanel sharedPanel] applyAlternateActionForSwitchIdentifier:switchIdentifier];
}

- (Class <FSSwitchSettingsViewController>)settingsViewControllerClassForSwitchIdentifier:(NSString *)switchIdentifier
{
	NSString *className = [[self bundleForSwitchIdentifier:switchIdentifier] objectForInfoDictionaryKey:@"settings-view-controller-class"];
	if (className) {
		[self lazyLoadWithSwitchIdentifier:switchIdentifier];
		return [[FSSwitchPanel sharedPanel] settingsViewControllerClassForSwitchIdentifier:switchIdentifier];
	} else {
		return nil;
	}
}

@end

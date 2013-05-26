#import "FSLazySwitch.h"
#import "FSSwitchPanel.h"

@implementation FSLazySwitch

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
	Class switchClass = [bundle principalClass];
	id<FSSwitchDataSource> switchImplementation = [switchClass respondsToSelector:@selector(initWithBundle:)] ? [[switchClass alloc] initWithBundle:bundle] : [[switchClass alloc] init];
	if (switchImplementation) {
		[[self retain] autorelease];
		[[FSSwitchPanel sharedPanel] registerDataSource:switchImplementation forSwitchIdentifier:switchIdentifier];
	} else {
		[NSException raise:NSInvalidArgumentException format:@"Unable to lazily load switch for %@ (using switch class %@)", switchIdentifier, switchClass];
	}
	[switchImplementation release];
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

@end

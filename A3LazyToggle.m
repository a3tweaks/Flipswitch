#import "A3LazyToggle.h"
#import "A3ToggleManager.h"

@implementation A3LazyToggle

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

- (void)lazyLoadWithToggleIdentifier:(NSString *)toggleIdentifier
{
	Class toggleClass = [bundle principalClass];
	id<A3Toggle> toggle = [toggleClass respondsToSelector:@selector(initWithBundle:)] ? [[toggleClass alloc] initWithBundle:bundle] : [[toggleClass alloc] init];
	if (toggle) {
		[[self retain] autorelease];
		[[A3ToggleManager sharedToggleManager] registerToggle:toggle forIdentifier:toggleIdentifier];
	}
	[toggle release];
}

- (A3ToggleState)stateForToggleIdentifier:(NSString *)toggleIdentifier
{
	[self lazyLoadWithToggleIdentifier:toggleIdentifier];
	return [[A3ToggleManager sharedToggleManager] toggleStateForToggleIdentifier:toggleIdentifier];
}

- (void)applyState:(A3ToggleState)newState forToggleIdentifier:(NSString *)toggleIdentifier
{
	[self lazyLoadWithToggleIdentifier:toggleIdentifier];
	[[A3ToggleManager sharedToggleManager] setToggleState:newState onToggleIdentifier:toggleIdentifier];
}

- (void)applyActionForToggleIdentifier:(NSString *)toggleIdentifier
{
	[self lazyLoadWithToggleIdentifier:toggleIdentifier];
	[[A3ToggleManager sharedToggleManager] applyActionForToggleIdentifier:toggleIdentifier];
}

- (BOOL)hasAlternateActionForToggleIdentifier:(NSString *)toggleIdentifier
{
	[self lazyLoadWithToggleIdentifier:toggleIdentifier];
	return [[A3ToggleManager sharedToggleManager] hasAlternateActionForToggleIdentifier:toggleIdentifier];
}

- (void)applyAlternateActionForToggleIdentifier:(NSString *)toggleIdentifier
{
	[self lazyLoadWithToggleIdentifier:toggleIdentifier];
	[[A3ToggleManager sharedToggleManager] applyAlternateActionForToggleIdentifier:toggleIdentifier];
}

@end

#import "A3ToggleButton.h"
#import "A3ToggleManager.h"

@implementation A3ToggleButton

- (id)initWithToggleIdentifier:(NSString *)toggleIdentifier_ template:(NSBundle *)template_
{
	CGFloat width = [[template_ objectForInfoDictionaryKey:@"width"] floatValue];
	CGFloat height = [[template_ objectForInfoDictionaryKey:@"height"] floatValue];
	if ((self = [super initWithFrame:CGRectMake(0.0f, 0.0f, width, height)])) {
		toggleIdentifier = [toggleIdentifier_ copy];
		template = [template_ retain];
		self.adjustsImageWhenHighlighted = NO;
		self.adjustsImageWhenDisabled = NO;
		CALayer *layer = self.layer;
		layer.needsDisplayOnBoundsChange = NO;
		[layer setNeedsDisplay];
		[self addObserver:self forKeyPath:@"enabled" options:0 context:template];
		[self addObserver:self forKeyPath:@"highlighted" options:0 context:template];
		[self addObserver:self forKeyPath:@"selected" options:0 context:template];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(toggleStateDidChange:) name:A3ToggleManagerToggleStateChangedNotification object:nil];
		[self addTarget:self action:@selector(_pressed) forControlEvents:UIControlEventTouchUpInside];
	}
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[self removeObserver:self forKeyPath:@"enabled"];
	[self removeObserver:self forKeyPath:@"highlighted"];
	[self removeObserver:self forKeyPath:@"selected"];
	[toggleIdentifier release];
	[template release];
	[super dealloc];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (context != template)
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	else
		[self.layer setNeedsDisplay];
}

- (void)toggleStateDidChange:(NSNotification *)notification
{
	NSString *changedIdentifier = [notification.userInfo objectForKey:A3ToggleManagerToggleIdentifierKey];
	if ([changedIdentifier isEqual:toggleIdentifier] || !changedIdentifier)
		[self.layer setNeedsDisplay];
}

- (void)displayLayer:(CALayer *)layer
{
	A3ToggleManager *sharedToggleManager = [A3ToggleManager sharedToggleManager];
	UIImage *image = [sharedToggleManager imageOfToggleState:[sharedToggleManager stateForToggleIdentifier:toggleIdentifier] controlState:self.state forToggleIdentifier:toggleIdentifier usingTemplate:template];
	[self setImage:image forState:UIControlStateNormal];
}

- (void)_pressed
{
	[[A3ToggleManager sharedToggleManager] applyActionForToggleIdentifier:toggleIdentifier];
}

@end

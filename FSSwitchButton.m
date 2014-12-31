#import "FSSwitchButton.h"
#import "FSSwitchPanel.h"
#import "NSBundle+Flipswitch.h"

@interface CALayer (Private)
@property (assign) BOOL allowsGroupBlending;
@end

@implementation _FSSwitchButton

- (id)initWithSwitchIdentifier:(NSString *)switchIdentifier_ template:(NSBundle *)template_
{
	NSDictionary *infoDictionary = template_.flipswitchThemedInfoDictionary;
	CGFloat width = [[infoDictionary objectForKey:@"width"] floatValue];
	CGFloat height = [[infoDictionary objectForKey:@"height"] floatValue];
	if ((self = [super initWithFrame:CGRectMake(0.0f, 0.0f, width, height)])) {
		switchIdentifier = [switchIdentifier_ copy];
		template = [template_ retain];
		self.adjustsImageWhenHighlighted = NO;
		self.adjustsImageWhenDisabled = NO;
		CALayer *layer = self.layer;
		layer.needsDisplayOnBoundsChange = NO;
		if ([layer respondsToSelector:@selector(setAllowsGroupBlending:)]) {
			[layer setAllowsGroupBlending:NO];
		}
		[layer setNeedsDisplay];
		[self addObserver:self forKeyPath:@"enabled" options:0 context:template];
		[self addObserver:self forKeyPath:@"highlighted" options:0 context:template];
		[self addObserver:self forKeyPath:@"selected" options:0 context:template];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(switchStateDidChange:) name:FSSwitchPanelSwitchStateChangedNotification object:nil];
		[self addTarget:self action:@selector(_pressed) forControlEvents:UIControlEventTouchUpInside];
		self.enabled = [[FSSwitchPanel sharedPanel] switchWithIdentifierIsEnabled:switchIdentifier_];
	}
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[self removeObserver:self forKeyPath:@"enabled"];
	[self removeObserver:self forKeyPath:@"highlighted"];
	[self removeObserver:self forKeyPath:@"selected"];
	[switchIdentifier release];
	[template release];
	[backgroundView release];
	[currentBackgroundImage release];
	[super dealloc];
}

- (NSString *)description
{
	NSString *addedContent = [NSString stringWithFormat:@" switchIdentifier=%@ template=%@", switchIdentifier, template.bundleIdentifier ?: template.bundlePath];
	NSMutableString *result = [[[super description] mutableCopy] autorelease];
	[result insertString:addedContent atIndex:[result length] - 1];
	return result;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (context != template)
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	else
		[self.layer setNeedsDisplay];
}

- (void)switchStateDidChange:(NSNotification *)notification
{
	NSString *changedIdentifier = [notification.userInfo objectForKey:FSSwitchPanelSwitchIdentifierKey];
	if ([changedIdentifier isEqual:switchIdentifier] || !changedIdentifier) {
		self.enabled = [[FSSwitchPanel sharedPanel] switchWithIdentifierIsEnabled:switchIdentifier];
		[self.layer setNeedsDisplay];
	}
}

- (void)displayLayer:(CALayer *)layer
{
	FSSwitchPanel *sharedPanel = [FSSwitchPanel sharedPanel];
	FSSwitchState switchState = [sharedPanel stateForSwitchIdentifier:switchIdentifier];
	UIControlState controlState = self.state;
	UIImage *image = [sharedPanel imageOfSwitchState:switchState controlState:controlState forSwitchIdentifier:switchIdentifier usingTemplate:template];
	[self setImage:image forState:UIControlStateNormal];
	[self setImage:image forState:UIControlStateHighlighted];
	UIImageView *imageView = self.imageView;
	[sharedPanel applyEffectsToLayer:imageView.layer forSwitchState:switchState controlState:controlState usingTemplate:template];
	// Add background image so that button can be stretchable
	UIImage *backgroundImage = [sharedPanel imageOfSwitchState:switchState controlState:controlState forSwitchIdentifier:switchIdentifier usingLayerSet:@"background" inTemplate:template];
	if (backgroundImage && (backgroundImage != currentBackgroundImage)) {
		[currentBackgroundImage release];
		currentBackgroundImage = [backgroundImage retain];
		CGSize size = backgroundImage.size;
		if ([backgroundImage respondsToSelector:@selector(resizableImageWithCapInsets:resizingMode:)]) {
			backgroundImage = [backgroundImage resizableImageWithCapInsets:UIEdgeInsetsMake(size.height * 0.5, size.width * 0.5, size.height * 0.5, size.width * 0.5) resizingMode:UIImageResizingModeStretch];
		} else if ([backgroundImage respondsToSelector:@selector(resizableImageWithCapInsets:)]) {
			backgroundImage = [backgroundImage resizableImageWithCapInsets:UIEdgeInsetsMake(size.height * 0.5, size.width * 0.5, size.height * 0.5, size.width * 0.5)];
		} else {
			backgroundImage = [backgroundImage stretchableImageWithLeftCapWidth:size.width * 0.5 topCapHeight:size.height * 0.5];
		}
		if (!backgroundView) {
			backgroundView = [[UIImageView alloc] initWithFrame:self.bounds];
			backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
			[imageView.superview insertSubview:backgroundView belowSubview:imageView];
		}
		backgroundView.image = backgroundImage;
		[sharedPanel applyEffectsToLayer:backgroundView.layer forSwitchState:switchState controlState:controlState usingLayerSet:@"background" inTemplate:template];
	}
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	[super touchesBegan:touches withEvent:event];
	skippingForHold = NO;
	[self performSelector:@selector(_held) withObject:nil afterDelay:1.0];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	[super touchesMoved:touches withEvent:event];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_held) object:nil];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	[super touchesEnded:touches withEvent:event];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_held) object:nil];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	[super touchesCancelled:touches withEvent:event];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_held) object:nil];
}

- (void)_pressed
{
	if (!skippingForHold) {
		[[FSSwitchPanel sharedPanel] applyActionForSwitchIdentifier:switchIdentifier];
	}
}

- (void)_held
{
	skippingForHold = YES;
	[[FSSwitchPanel sharedPanel] applyAlternateActionForSwitchIdentifier:switchIdentifier];
}

- (NSString *)accessibilityLabel
{
	return [[FSSwitchPanel sharedPanel] titleForSwitchIdentifier:switchIdentifier];
}

- (NSString *)accessibilityValue
{
	switch ([[FSSwitchPanel sharedPanel] stateForSwitchIdentifier:switchIdentifier]) {
		case FSSwitchStateOff:
			return @"Off";
		case FSSwitchStateOn:
			return @"On";
		default:
			return nil;
	}
}

- (void)didMoveToWindow
{
	[super didMoveToWindow];
	if (self.window)
		[[FSSwitchPanel sharedPanel] beginPrewarmingForSwitchIdentifier:switchIdentifier];
	else
		[[FSSwitchPanel sharedPanel] cancelPrewarmingForSwitchIdentifier:switchIdentifier];
}

@end

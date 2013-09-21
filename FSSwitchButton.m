#import "FSSwitchButton.h"
#import "FSSwitchPanel.h"

@implementation FSSwitchButton

- (id)initWithSwitchIdentifier:(NSString *)switchIdentifier_ template:(NSBundle *)template_
{
	CGFloat width = [[template_ objectForInfoDictionaryKey:@"width"] floatValue];
	CGFloat height = [[template_ objectForInfoDictionaryKey:@"height"] floatValue];
	if ((self = [super initWithFrame:CGRectMake(0.0f, 0.0f, width, height)])) {
		switchIdentifier = [switchIdentifier_ copy];
		template = [template_ retain];
		self.adjustsImageWhenHighlighted = NO;
		self.adjustsImageWhenDisabled = NO;
		CALayer *layer = self.layer;
		layer.needsDisplayOnBoundsChange = NO;
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
	[super dealloc];
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
	UIImage *image = [sharedPanel imageOfSwitchState:[sharedPanel stateForSwitchIdentifier:switchIdentifier] controlState:self.state forSwitchIdentifier:switchIdentifier usingTemplate:template];
	[self setImage:image forState:UIControlStateNormal];
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

@end

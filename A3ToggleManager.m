#import "A3ToggleManager.h"
#import "A3ToggleManagerMain.h"
#import "A3ToggleService.h"
#import "A3Toggle.h"

#import <dlfcn.h>
#import "LightMessaging/LightMessaging.h"

static LMConnection connection = {
	MACH_PORT_NULL,
	kA3ToggleServiceName
};

static A3ToggleManager *_toggleManager;

@implementation A3ToggleManager

+ (void)initialize
{
	if (self == [A3ToggleManager class]) {
		_toggleManager = [objc_getClass("SpringBoard") ? [A3ToggleManagerMain alloc] : [self alloc] init];
	}
}

+ (A3ToggleManager *)sharedInstance
{
    return _toggleManager;
}

- (A3ToggleManager *)init
{
    if ((self = [super init]))
    {

    }
    return self;
}

- (NSArray *)toggleIdentifiers
{
	LMResponseBuffer responseBuffer;
	if (LMConnectionSendTwoWay(&connection, A3ToggleServiceMessageGetIdentifiers, NULL, 0, &responseBuffer)) {
		return nil;
	}
	return LMResponseConsumePropertyList(&responseBuffer);
}

- (NSString *)titleForToggleID:(NSString *)toggleID
{
	LMResponseBuffer responseBuffer;
	if (LMConnectionSendTwoWayPropertyList(&connection, A3ToggleServiceMessageGetTitleForIdentifier, toggleID, &responseBuffer)) {
		return nil;
	}
	return LMResponseConsumePropertyList(&responseBuffer);
}

- (id)glyphImageIdentifierForToggleID:(NSString *)toggleID controlState:(UIControlState)controlState size:(CGFloat)size scale:(CGFloat)scale
{
 	NSDictionary *args = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:toggleID, [NSNumber numberWithFloat:size], [NSNumber numberWithFloat:scale], [NSNumber numberWithInteger:controlState], nil] forKeys:[NSArray arrayWithObjects:@"toggleID", @"size", @"scale", @"controlState", nil]];

	LMResponseBuffer responseBuffer;
	if (LMConnectionSendTwoWayPropertyList(&connection, A3ToggleServiceMessageGetImageIdentifierForToggle, args, &responseBuffer)) {
		return nil;
	}
	return LMResponseConsumePropertyList(&responseBuffer);
}

- (UIImage *)toggleImageForToggleID:(NSString *)toggleID controlState:(UIControlState)controlState scale:(CGFloat)scale usingTemplateBundle:(NSBundle *)templateBundle;
{
	// TODO: Define template format, read in template used to describe what background images to use and how to draw the glyphs
	id identifier = [self glyphImageIdentifierForToggleID:toggleID controlState:controlState size:29 scale:scale];
	if ([identifier isKindOfClass:[NSString class]]) {
		return [UIImage imageWithContentsOfFile:identifier];
	} else {
		// TODO: Allow glyph identifiers of data containing image bytes or UImage
		return nil;
	}
}

- (UIImage *)toggleImageForToggleID:(NSString *)toggleID controlState:(UIControlState)controlState usingTemplateBundle:(NSBundle *)templateBundle;
{
	CGFloat scale = [UIScreen instancesRespondToSelector:@selector(scale)] ? [UIScreen mainScreen].scale : 1.0f;
	return [self toggleImageForToggleID:toggleID controlState:controlState scale:scale usingTemplateBundle:templateBundle];
}

- (BOOL)toggleStateForToggleID:(NSString *)toggleID
{
	LMResponseBuffer responseBuffer;
	if (LMConnectionSendTwoWayPropertyList(&connection, A3ToggleServiceMessageGetStateForIdentifier, toggleID, &responseBuffer)) {
		return NO;
	}
	return LMResponseConsumeInteger(&responseBuffer);
}

- (void)setToggleState:(BOOL)state onToggleID:(NSString *)toggleID
{
	NSArray *propertyList = [NSArray arrayWithObjects:[NSNumber numberWithBool:state], toggleID, nil];
	LMConnectionSendOneWayData(&connection, A3ToggleServiceMessageSetStateForIdentifier, (CFDataRef)[NSPropertyListSerialization dataFromPropertyList:propertyList format:NSPropertyListBinaryFormat_v1_0 errorDescription:NULL]);
}

- (void)dealloc
{    
    [super dealloc];
}

@end

@implementation A3ToggleManager (SpringBoard)

- (void)registerToggle:(id<A3Toggle>)toggle forIdentifier:(NSString *)toggleIdentifier
{
	// TODO: Throw exception
}

- (void)unregisterToggleIdentifier:(NSString *)toggleIdentifier;
{
	// TODO: Throw exception
}

- (void)stateDidChangeForToggleIdentifier:(NSString *)toggleIdentifier
{
	// TODO: Throw exception
}

@end


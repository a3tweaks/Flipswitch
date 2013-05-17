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

- (UIImage *)toggleImageForIdentifier:(NSString *)toggleID withBackground:(UIImage *)backgroundImage overlay:(UIImage *)overlayMask andState:(BOOL)state
{
 	NSDictionary *args = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:toggleID, backgroundImage, overlayMask, state, nil] forKeys:[NSArray arrayWithObjects:@"toggleID", @"toggleBackground", @"toggleOverlay", @"toggleState", nil]];

	LMResponseBuffer responseBuffer;
	if (LMConnectionSendTwoWayPropertyList(&connection, A3ToggleServiceMessageGetImageForIdentifierAndState, args, &responseBuffer)) {
		return nil;
	}
	return LMResponseConsumeImage(&responseBuffer);
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


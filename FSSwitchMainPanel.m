#import "FSSwitchMainPanel.h"
#import "FSSwitchService.h"
#import "FSSwitchDataSource.h"
#import "FSPreferenceSwitchDataSource.h"
#import "FSLazySwitch.h"

#import "LightMessaging/LightMessaging.h"
#import "Internal.h"

#import <notify.h>

extern BOOL GSSystemHasCapability(NSString *capability);

#define kSwitchesPath @"/Library/Switches/"

@interface UIApplication (Private)
- (void)applicationOpenURL:(NSURL *)url;
@end

static NSInteger stateChangeCount;

@implementation FSSwitchMainPanel

- (void)registerDataSource:(id<FSSwitchDataSource>)dataSource forSwitchIdentifier:(NSString *)switchIdentifier;
{
	REQUIRE_MAIN_THREAD(FSSwitchPanel);
	if (!switchIdentifier) {
		[NSException raise:NSInvalidArgumentException format:@"Switch identifier passed to -[FSSwitchPanel registerSwitch:forIdentifier:] must not be nil"];
	}
	if (!dataSource) {
		[NSException raise:NSInvalidArgumentException format:@"Switch data source passed to -[FSSwitchPanel registerSwitch:forIdentifier:] must not be nil"];
	}
	// Verify that switchImplementation is either a valid action-like switchImplementation or setting-like switchImplementation
	if ([(NSObject *)dataSource methodForSelector:@selector(applyState:forSwitchIdentifier:)] == [NSObject instanceMethodForSelector:@selector(applyState:forSwitchIdentifier:)]) {
		if ([(NSObject *)dataSource methodForSelector:@selector(applyActionForSwitchIdentifier:)] == [NSObject instanceMethodForSelector:@selector(applyActionForSwitchIdentifier:)]) {
			[NSException raise:NSInvalidArgumentException format:@"Switch data source passed to -[FSSwitchPanel registerSwitch:forIdentifier] must override either applyState:forSwitchIdentifier: or applyActionForSwitchIdentifier:"];
		}
	} else {
		if ([(NSObject *)dataSource methodForSelector:@selector(stateForSwitchIdentifier:)] == [NSObject instanceMethodForSelector:@selector(stateForSwitchIdentifier:)]) {
			[NSException raise:NSInvalidArgumentException format:@"Switch data source passed to -[FSSwitchPanel registerSwitch:forIdentifier] must override stateForSwitchIdentifier:"];
		}
	}
	id<FSSwitchDataSource> oldSwitch = [[_switchImplementations objectForKey:switchIdentifier] retain];
	[_switchImplementations setObject:dataSource forKey:switchIdentifier];
	[dataSource switchWasRegisteredForIdentifier:switchIdentifier];
	[oldSwitch switchWasUnregisteredForIdentifier:switchIdentifier];
	[oldSwitch release];
	if (!hasUpdatedSwitches) {
		hasUpdatedSwitches = YES;
		[self performSelector:@selector(_sendSwitchesChanged) withObject:nil afterDelay:0.0];
	}
}

- (void)unregisterSwitchIdentifier:(NSString *)switchIdentifier
{
	REQUIRE_MAIN_THREAD(FSSwitchPanel);
	if (!switchIdentifier) {
		[NSException raise:NSInvalidArgumentException format:@"Switch identifier passed to -[FSSwitchPanel unregisterSwitchIdentifier:] must not be nil"];
	}
	id<FSSwitchDataSource> oldSwitch = [[_switchImplementations objectForKey:switchIdentifier] retain];
	[_switchImplementations removeObjectForKey:switchIdentifier];
	[oldSwitch switchWasUnregisteredForIdentifier:switchIdentifier];
	[oldSwitch release];
	if (!hasUpdatedSwitches) {
		hasUpdatedSwitches = YES;
		[self performSelector:@selector(_sendSwitchesChanged) withObject:nil afterDelay:0.0];
	}
}

- (void)_sendSwitchesChanged
{
	hasUpdatedSwitches = NO;
	notify_post([FSSwitchPanelSwitchesChangedNotification UTF8String]);
	[[NSNotificationCenter defaultCenter] postNotificationName:FSSwitchPanelSwitchesChangedNotification object:self userInfo:nil];
}

- (void)stateDidChangeForSwitchIdentifier:(NSString *)switchIdentifier
{
	REQUIRE_MAIN_THREAD(FSSwitchPanel);
	stateChangeCount++;
	NSDictionary *userInfo = switchIdentifier ? [NSDictionary dictionaryWithObject:switchIdentifier forKey:FSSwitchPanelSwitchIdentifierKey] : nil;
	[[NSNotificationCenter defaultCenter] postNotificationName:FSSwitchPanelSwitchStateChangedNotification object:self userInfo:userInfo];
}

- (NSArray *)switchIdentifiers
{
	REQUIRE_MAIN_THREAD(FSSwitchPanel);
	return [_switchImplementations allKeys];
}

- (NSString *)titleForSwitchIdentifier:(NSString *)switchIdentifier
{
	REQUIRE_MAIN_THREAD(FSSwitchPanel);
	id<FSSwitchDataSource> switchImplementation = [_switchImplementations objectForKey:switchIdentifier];
	return [switchImplementation titleForSwitchIdentifier:switchIdentifier];
}

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	REQUIRE_MAIN_THREAD(FSSwitchPanel);
	id<FSSwitchDataSource> switchImplementation = [_switchImplementations objectForKey:switchIdentifier];
	return [switchImplementation stateForSwitchIdentifier:switchIdentifier];
}

- (void)setState:(FSSwitchState)state forSwitchIdentifier:(NSString *)switchIdentifier
{
	REQUIRE_MAIN_THREAD(FSSwitchPanel);
	id<FSSwitchDataSource> switchImplementation = [_switchImplementations objectForKey:switchIdentifier];
	// Workaround switches that don't explicitly send state change notifications :(
	FSSwitchState oldState = [switchImplementation stateForSwitchIdentifier:switchIdentifier];
	NSInteger oldStateChangeCount = stateChangeCount;
	[switchImplementation applyState:state forSwitchIdentifier:switchIdentifier];
	if (oldStateChangeCount == stateChangeCount && oldState != [switchImplementation stateForSwitchIdentifier:switchIdentifier]) {
		[self stateDidChangeForSwitchIdentifier:switchIdentifier];
	}
}

- (void)applyActionForSwitchIdentifier:(NSString *)switchIdentifier
{
	REQUIRE_MAIN_THREAD(FSSwitchPanel);
	id<FSSwitchDataSource> switchImplementation = [_switchImplementations objectForKey:switchIdentifier];
	// Workaround switches that don't explicitly send state change notifications :(
	FSSwitchState oldState = [switchImplementation stateForSwitchIdentifier:switchIdentifier];
	NSInteger oldStateChangeCount = stateChangeCount;
	[switchImplementation applyActionForSwitchIdentifier:switchIdentifier];
	if (oldStateChangeCount == stateChangeCount && oldState != [switchImplementation stateForSwitchIdentifier:switchIdentifier]) {
		[self stateDidChangeForSwitchIdentifier:switchIdentifier];
	}
}

- (id)glyphImageDescriptorOfState:(FSSwitchState)switchState size:(CGFloat)size scale:(CGFloat)scale forSwitchIdentifier:(NSString *)switchIdentifier;
{
	REQUIRE_MAIN_THREAD(FSSwitchPanel);
	id<FSSwitchDataSource> switchImplementation = [_switchImplementations objectForKey:switchIdentifier];
	return [switchImplementation glyphImageDescriptorOfState:switchState size:size scale:scale forSwitchIdentifier:switchIdentifier];
}

- (BOOL)hasAlternateActionForSwitchIdentifier:(NSString *)switchIdentifier
{
	REQUIRE_MAIN_THREAD(FSSwitchPanel);
	id<FSSwitchDataSource> switchImplementation = [_switchImplementations objectForKey:switchIdentifier];
	return [switchImplementation hasAlternateActionForSwitchIdentifier:switchIdentifier];
}

- (void)applyAlternateActionForSwitchIdentifier:(NSString *)switchIdentifier
{
	REQUIRE_MAIN_THREAD(FSSwitchPanel);
	id<FSSwitchDataSource> switchImplementation = [_switchImplementations objectForKey:switchIdentifier];
	[switchImplementation applyAlternateActionForSwitchIdentifier:switchIdentifier];
}

- (void)openURLAsAlternateAction:(NSURL *)url
{
	REQUIRE_MAIN_THREAD(FSSwitchPanel);

	NSDictionary *userInfo = url ? [NSDictionary dictionaryWithObject:url forKey:@"url"] : nil;
	[[NSNotificationCenter defaultCenter] postNotificationName:FSSwitchPanelSwitchWillOpenURLNotification object:self userInfo:userInfo];

	[[UIApplication sharedApplication] applicationOpenURL:url];
}

static void processMessage(FSSwitchMainPanel *self, SInt32 messageId, mach_port_t replyPort, CFDataRef data)
{
	switch ((FSSwitchServiceMessage)messageId) {
		case FSSwitchServiceMessageGetIdentifiers:
			LMSendPropertyListReply(replyPort, self.switchIdentifiers);
			return;
		case FSSwitchServiceMessageGetTitleForIdentifier: {
			NSString *identifier = [NSPropertyListSerialization propertyListFromData:(NSData *)data mutabilityOption:0 format:NULL errorDescription:NULL];
			if ([identifier isKindOfClass:[NSString class]]) {
				NSString *title = [self titleForSwitchIdentifier:identifier];
				LMSendPropertyListReply(replyPort, title);
				return;
			}
			break;
		}
		case FSSwitchServiceMessageGetStateForIdentifier: {
			NSString *identifier = [NSPropertyListSerialization propertyListFromData:(NSData *)data mutabilityOption:0 format:NULL errorDescription:NULL];
			if ([identifier isKindOfClass:[NSString class]]) {
				LMSendIntegerReply(replyPort, [self stateForSwitchIdentifier:identifier]);
				return;
			}
			break;
		}
		case FSSwitchServiceMessageSetStateForIdentifier: {
			NSArray *args = [NSPropertyListSerialization propertyListFromData:(NSData *)data mutabilityOption:0 format:NULL errorDescription:NULL];
			if ([args isKindOfClass:[NSArray class]] && [args count] == 2) {
				NSNumber *state = [args objectAtIndex:0];
				NSString *identifier = [args objectAtIndex:1];
				if ([state isKindOfClass:[NSNumber class]] && [identifier isKindOfClass:[NSString class]]) {
					[self setState:[state integerValue] forSwitchIdentifier:identifier];
				}
			}
			break;
		}
		case FSSwitchServiceMessageGetImageDescriptorForSwitch: {
			NSDictionary *args = [NSPropertyListSerialization propertyListFromData:(NSData *)data mutabilityOption:0 format:NULL errorDescription:NULL];
			if ([args isKindOfClass:[NSDictionary class]]) {
				NSString *switchIdentifier = [args objectForKey:@"switchIdentifier"];
				CGFloat size = [[args objectForKey:@"size"] floatValue];
				CGFloat scale = [[args objectForKey:@"scale"] floatValue];
				FSSwitchState switchState = [[args objectForKey:@"switchState"] intValue];
				id imageDescriptor = [self glyphImageDescriptorOfState:switchState size:size scale:scale forSwitchIdentifier:switchIdentifier];
				if (imageDescriptor) {
					// TODO: Allow responding with a string representing file path, data containing image bytes, or UImage
					LMSendPropertyListReply(replyPort, imageDescriptor);
					return;
				}
			}
			break;
		}
		case FSSwitchServiceMessageApplyActionForIdentifier: {
			NSString *identifier = [NSPropertyListSerialization propertyListFromData:(NSData *)data mutabilityOption:0 format:NULL errorDescription:NULL];
			if ([identifier isKindOfClass:[NSString class]]) {
				[self applyActionForSwitchIdentifier:identifier];
			}
			break;
		}
		case FSSwitchServiceMessageHasAlternateActionForIdentifier: {
			NSString *identifier = [NSPropertyListSerialization propertyListFromData:(NSData *)data mutabilityOption:0 format:NULL errorDescription:NULL];
			if ([identifier isKindOfClass:[NSString class]]) {
				LMSendIntegerReply(replyPort, [self hasAlternateActionForSwitchIdentifier:identifier]);
				return;
			}
			break;
		}
		case FSSwitchServiceMessageApplyAlternateActionForIdentifier: {
			NSString *identifier = [NSPropertyListSerialization propertyListFromData:(NSData *)data mutabilityOption:0 format:NULL errorDescription:NULL];
			if ([identifier isKindOfClass:[NSString class]]) {
				[self applyAlternateActionForSwitchIdentifier:identifier];
			}
			break;
		}
	}
	LMSendReply(replyPort, NULL, 0);
}

static void machPortCallback(CFMachPortRef port, void *bytes, CFIndex size, void *info)
{
	LMMessage *request = bytes;
	if (size < sizeof(LMMessage)) {
		LMSendReply(request->head.msgh_remote_port, NULL, 0);
		LMResponseBufferFree(bytes);
		return;
	}
	// Send Response
	const void *data = LMMessageGetData(request);
	size_t length = LMMessageGetDataLength(request);
	mach_port_t replyPort = request->head.msgh_remote_port;
	CFDataRef cfdata = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, data ?: &data, length, kCFAllocatorNull);
	processMessage(info, request->head.msgh_id, replyPort, cfdata);
	if (cfdata)
		CFRelease(cfdata);
	LMResponseBufferFree(bytes);
}

- (void)_loadSwitchForBundle:(NSBundle *)bundle
{
	Class arrayClass = [NSArray class];
	NSArray *capabilities = [bundle objectForInfoDictionaryKey:@"required-capabilities"];
	if ([capabilities isKindOfClass:arrayClass])
		for (NSString *capability in capabilities)
			if ([capability isKindOfClass:[NSString class]])
				if (!GSSystemHasCapability(capability))
					return;
	NSArray *coreFoundationVersion = [bundle objectForInfoDictionaryKey:@"CoreFoundationVersion"];
	if ([coreFoundationVersion isKindOfClass:arrayClass] && coreFoundationVersion.count > 0) {
		NSNumber *lowerBound = [coreFoundationVersion objectAtIndex:0];
		if (kCFCoreFoundationVersionNumber < lowerBound.doubleValue)
			return;
		if (coreFoundationVersion.count > 1) {
			NSNumber *upperBound = [coreFoundationVersion objectAtIndex:1];
			if (kCFCoreFoundationVersionNumber >= upperBound.doubleValue)
				return;
		}
	}
	Class switchClass = [[bundle objectForInfoDictionaryKey:@"lazy-load"] boolValue] ? [FSLazySwitch class] : [bundle principalClass] ?: NSClassFromString([bundle objectForInfoDictionaryKey:@"NSPrincipalClass"]);
	id<FSSwitchDataSource> switchImplementation = [switchClass instancesRespondToSelector:@selector(initWithBundle:)] ? [[switchClass alloc] initWithBundle:bundle] : [[switchClass alloc] init];
	if (switchImplementation && [switchImplementation shouldShowSwitchIdentifier:bundle.bundleIdentifier])
		[self registerDataSource:switchImplementation forSwitchIdentifier:bundle.bundleIdentifier];
	[switchImplementation release];
}

- (id)init
{
	if ((self = [super init]))
	{
		mach_port_t bootstrap = MACH_PORT_NULL;
		task_get_bootstrap_port(mach_task_self(), &bootstrap);
		CFMachPortContext context = { 0, self, NULL, NULL, NULL };
		CFMachPortRef machPort = CFMachPortCreate(kCFAllocatorDefault, machPortCallback, &context, NULL);
		CFRunLoopSourceRef machPortSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, machPort, 0);
		CFRunLoopAddSource(CFRunLoopGetCurrent(), machPortSource, kCFRunLoopDefaultMode);
		mach_port_t port = CFMachPortGetPort(machPort);
		kern_return_t err = bootstrap_register(bootstrap, kFSSwitchServiceName, port);
		if (err) NSLog(@"FS Switch API: Connection Creation failed with Error: %x", err);
		_switchImplementations = [[NSMutableDictionary alloc] init];
		NSArray *switchDirectoryContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:kSwitchesPath error:nil];
		for (NSString *folder in switchDirectoryContents) {
			NSBundle *bundle = [NSBundle bundleWithPath:[kSwitchesPath stringByAppendingPathComponent:folder]];
			if (bundle)
				[self _loadSwitchForBundle:bundle];
		}

	}
	return self;
}

- (void)dealloc
{
	[_switchImplementations release];
	[super dealloc];
}

@end

__attribute__((constructor))
static void constructor(void)
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	// Initialize in SpringBoard automatically so that the bootstrap service gets registered
	if ([[NSBundle mainBundle].bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
		[FSSwitchPanel sharedPanel];
	}
	[pool drain];
}

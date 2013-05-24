#import "A3ToggleManagerMain.h"
#import "A3ToggleService.h"
#import "A3Toggle.h"
#import "A3PreferenceToggle.h"

#import "LightMessaging/LightMessaging.h"

#import <notify.h>

#define kTogglesPath @"/Library/Toggles/"

@implementation A3ToggleManagerMain

- (void)registerToggle:(id<A3Toggle>)toggle forIdentifier:(NSString *)toggleIdentifier
{
	if (!toggleIdentifier) {
		[NSException raise:NSInvalidArgumentException format:@"Toggle identifier passed to -[A3ToggleManager registerToggle:forIdentifier:] must not be nil"];
	}
	if (!toggle) {
		[NSException raise:NSInvalidArgumentException format:@"Toggle instance passed to -[A3ToggleManager] registerToggle:forIdentifier:] must not be nil"];
	}
	// Verify that toggle is either a valid action-like toggle or setting-like toggle
	if ([(NSObject *)toggle methodForSelector:@selector(applyState:forToggleIdentifier:)] == [NSObject instanceMethodForSelector:@selector(applyState:forToggleIdentifier:)]) {
		if ([(NSObject *)toggle methodForSelector:@selector(applyActionForToggleIdentifier:)] == [NSObject instanceMethodForSelector:@selector(applyActionForToggleIdentifier:)]) {
			[NSException raise:NSInvalidArgumentException format:@"Toggle instance passed to -[A3ToggleManager registerToggle:forIdentifier] must override either applyState:forToggleIdentifier: or applyActionForToggleIdentifier:"];
		}
	} else {
		if ([(NSObject *)toggle methodForSelector:@selector(stateForToggleIdentifier:)] == [NSObject instanceMethodForSelector:@selector(stateForToggleIdentifier:)]) {
			[NSException raise:NSInvalidArgumentException format:@"Toggle instance passed to -[A3ToggleManager registerToggle:forIdentifier] must override stateForToggleIdentifier:"];
		}
	}
	id<A3Toggle> oldToggle = [[_toggleImplementations objectForKey:toggleIdentifier] retain];
	[_toggleImplementations setObject:toggle forKey:toggleIdentifier];
	[toggle toggleWasRegisteredForIdentifier:toggleIdentifier];
	[oldToggle toggleWasUnregisteredForIdentifier:toggleIdentifier];
	[oldToggle release];
	if (!hasUpdatedToggles) {
		hasUpdatedToggles = YES;
		[self performSelector:@selector(_sendTogglesChanged) withObject:nil afterDelay:0.0];
	}
}

- (void)unregisterToggleIdentifier:(NSString *)toggleIdentifier
{
	if (!toggleIdentifier) {
		[NSException raise:NSInvalidArgumentException format:@"Toggle identifier passed to -[A3ToggleManager unregisterToggle:forIdentifier:] must not be nil"];
	}
	id<A3Toggle> oldToggle = [[_toggleImplementations objectForKey:toggleIdentifier] retain];
	[_toggleImplementations removeObjectForKey:toggleIdentifier];
	[oldToggle toggleWasUnregisteredForIdentifier:toggleIdentifier];
	[oldToggle release];
	if (!hasUpdatedToggles) {
		hasUpdatedToggles = YES;
		[self performSelector:@selector(_sendTogglesChanged) withObject:nil afterDelay:0.0];
	}
}

- (void)_sendTogglesChanged
{
	hasUpdatedToggles = NO;
	notify_post([A3ToggleManagerTogglesChangedNotification UTF8String]);
	[[NSNotificationCenter defaultCenter] postNotificationName:A3ToggleManagerTogglesChangedNotification object:self userInfo:nil];
}

- (void)stateDidChangeForToggleIdentifier:(NSString *)toggleIdentifier
{
	NSDictionary *userInfo = toggleIdentifier ? [NSDictionary dictionaryWithObject:toggleIdentifier forKey:A3ToggleManagerToggleIdentifierKey] : nil;
	[[NSNotificationCenter defaultCenter] postNotificationName:A3ToggleManagerToggleStateChangedNotification object:self userInfo:userInfo];
}

- (NSArray *)toggleIdentifiers
{
	return [_toggleImplementations allKeys];
}

- (NSString *)titleForToggleIdentifier:(NSString *)toggleIdentifier
{
	id<A3Toggle> toggle = [_toggleImplementations objectForKey:toggleIdentifier];
	return [toggle titleForToggleIdentifier:toggleIdentifier];
}

- (BOOL)shouldShowToggleForToggleIdentifier:(NSString *)toggleIdentifier
{
	id<A3Toggle> toggle = [_toggleImplementations objectForKey:toggleIdentifier];
	return [toggle shouldShowToggleForToggleIdentifier:toggleIdentifier];
}

- (A3ToggleState)toggleStateForToggleIdentifier:(NSString *)toggleIdentifier
{
	id<A3Toggle> toggle = [_toggleImplementations objectForKey:toggleIdentifier];
	return [toggle stateForToggleIdentifier:toggleIdentifier];
}

- (void)setToggleState:(A3ToggleState)state onToggleIdentifier:(NSString *)toggleIdentifier
{
	id<A3Toggle> toggle = [_toggleImplementations objectForKey:toggleIdentifier];
	[toggle applyState:state forToggleIdentifier:toggleIdentifier];
}

- (void)applyActionForToggleIdentifier:(NSString *)toggleIdentifier
{
	id<A3Toggle> toggle = [_toggleImplementations objectForKey:toggleIdentifier];
	[toggle applyActionForToggleIdentifier:toggleIdentifier];
}

- (id)glyphImageDescriptorOfToggleState:(A3ToggleState)toggleState size:(CGFloat)size scale:(CGFloat)scale forToggleIdentifier:(NSString *)toggleIdentifier;
{
	id<A3Toggle> toggle = [_toggleImplementations objectForKey:toggleIdentifier];
	return [toggle glyphImageDescriptorOfToggleState:toggleState size:size scale:scale forToggleIdentifier:toggleIdentifier];
}

- (BOOL)hasAlternateActionForToggleIdentifier:(NSString *)toggleIdentifier
{
	id<A3Toggle> toggle = [_toggleImplementations objectForKey:toggleIdentifier];
	return [toggle hasAlternateActionForToggleIdentifier:toggleIdentifier];
}

- (void)applyAlternateActionForToggleIdentifier:(NSString *)toggleIdentifier
{
	id<A3Toggle> toggle = [_toggleImplementations objectForKey:toggleIdentifier];
	[toggle applyAlternateActionForToggleIdentifier:toggleIdentifier];
}

static void processMessage(A3ToggleManagerMain *self, SInt32 messageId, mach_port_t replyPort, CFDataRef data)
{
	switch ((A3ToggleServiceMessage)messageId) {
		case A3ToggleServiceMessageGetIdentifiers:
			LMSendPropertyListReply(replyPort, self.toggleIdentifiers);
			return;
		case A3ToggleServiceMessageGetTitleForIdentifier: {
			NSString *identifier = [NSPropertyListSerialization propertyListFromData:(NSData *)data mutabilityOption:0 format:NULL errorDescription:NULL];
			if ([identifier isKindOfClass:[NSString class]]) {
				NSString *title = [self titleForToggleIdentifier:identifier];
				LMSendPropertyListReply(replyPort, title);
				return;
			}
			break;
		}
		case A3ToggleServiceMessageGetStateForIdentifier: {
			NSString *identifier = [NSPropertyListSerialization propertyListFromData:(NSData *)data mutabilityOption:0 format:NULL errorDescription:NULL];
			if ([identifier isKindOfClass:[NSString class]]) {
				LMSendIntegerReply(replyPort, [self toggleStateForToggleIdentifier:identifier]);
				return;
			}
			break;
		}
		case A3ToggleServiceMessageSetStateForIdentifier: {
			NSArray *args = [NSPropertyListSerialization propertyListFromData:(NSData *)data mutabilityOption:0 format:NULL errorDescription:NULL];
			if ([args isKindOfClass:[NSArray class]] && [args count] == 2) {
				NSNumber *state = [args objectAtIndex:0];
				NSString *identifier = [args objectAtIndex:1];
				if ([state isKindOfClass:[NSNumber class]] && [identifier isKindOfClass:[NSString class]]) {
					[self setToggleState:[state integerValue] onToggleIdentifier:identifier];
				}
			}
			break;
		}
		case A3ToggleServiceMessageGetImageDescriptorForToggle: {
			NSDictionary *args = [NSPropertyListSerialization propertyListFromData:(NSData *)data mutabilityOption:0 format:NULL errorDescription:NULL];
			if ([args isKindOfClass:[NSDictionary class]]) {
				NSString *toggleIdentifier = [args objectForKey:@"toggleIdentifier"];
				CGFloat size = [[args objectForKey:@"size"] floatValue];
				CGFloat scale = [[args objectForKey:@"scale"] floatValue];
				A3ToggleState toggleState = [[args objectForKey:@"toggleState"] intValue];
				id imageDescriptor = [self glyphImageDescriptorOfToggleState:toggleState size:size scale:scale forToggleIdentifier:toggleIdentifier];
				if (imageDescriptor) {
					// TODO: Allow responding with a string representing file path, data containing image bytes, or UImage
					LMSendPropertyListReply(replyPort, imageDescriptor);
					return;
				}
			}
			break;
		}
		case A3ToggleServiceMessageApplyActionForIdentifier: {
			NSString *identifier = [NSPropertyListSerialization propertyListFromData:(NSData *)data mutabilityOption:0 format:NULL errorDescription:NULL];
			if ([identifier isKindOfClass:[NSString class]]) {
				[self applyActionForToggleIdentifier:identifier];
			}
			break;
		}
		case A3ToggleServiceMessageHasAlternateActionForIdentifier: {
			NSString *identifier = [NSPropertyListSerialization propertyListFromData:(NSData *)data mutabilityOption:0 format:NULL errorDescription:NULL];
			if ([identifier isKindOfClass:[NSString class]]) {
				LMSendIntegerReply(replyPort, [self hasAlternateActionForToggleIdentifier:identifier]);
				return;
			}
			break;
		}
		case A3ToggleServiceMessageApplyAlternateActionForIdentifier: {
			NSString *identifier = [NSPropertyListSerialization propertyListFromData:(NSData *)data mutabilityOption:0 format:NULL errorDescription:NULL];
			if ([identifier isKindOfClass:[NSString class]]) {
				[self applyAlternateActionForToggleIdentifier:identifier];
			}
			break;
		}
		case A3ToggleServiceMessageShouldToggleBeShown: {
			NSString *identifier = [NSPropertyListSerialization propertyListFromData:(NSData *)data mutabilityOption:0 format:NULL errorDescription:NULL];
			if ([identifier isKindOfClass:[NSString class]]) {
				LMSendIntegerReply(replyPort, [self shouldShowToggleForToggleIdentifier:identifier]);
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
		kern_return_t err = bootstrap_register(bootstrap, kA3ToggleServiceName, port);
		if (err) NSLog(@"A3 Toggle API: Connection Creation failed with Error: %x", err);

		_toggleImplementations = [[NSMutableDictionary alloc] init];
		NSArray *toggleDirectoryContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:kTogglesPath error:nil];
		for (NSString *folder in toggleDirectoryContents)
		{
			NSBundle *bundle = [NSBundle bundleWithPath:[kTogglesPath stringByAppendingPathComponent:folder]];
			if (bundle != nil)
			{
				Class toggleClass = [bundle principalClass];
				if ([toggleClass conformsToProtocol:@protocol(A3Toggle)])
				{
					id<A3Toggle> toggle = [toggleClass respondsToSelector:@selector(initWithBundle:)] ? [[toggleClass alloc] initWithBundle:bundle] : [[toggleClass alloc] init];
					if (toggle != nil) [_toggleImplementations setObject:toggle forKey:[bundle bundleIdentifier]];
					[toggle release];
				}
				else NSLog(@"Bundle with Identifier %@ doesn't conform to the defined Toggle Protocol", [bundle bundleIdentifier]);
			}
		}

	}
	return self;
}

- (void)dealloc
{
	[_toggleImplementations release];
	[super dealloc];
}

@end

__attribute__((constructor))
static void constructor(void)
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	// Initialize in SpringBoard automatically so that the bootstrap service gets registered
	if ([[NSBundle mainBundle].bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
		[A3ToggleManager sharedToggleManager];
	}
	[pool drain];
}

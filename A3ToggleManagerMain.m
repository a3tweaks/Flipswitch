#import "A3ToggleManagerMain.h"
#import "A3ToggleService.h"

#import "LightMessaging/LightMessaging.h"

@implementation A3ToggleManagerMain

- (void)registerToggle:(id<A3Toggle>)toggle forIdentifier:(NSString *)toggleIdentifier
{
	[_toggleImplementations setObject:toggle forKey:toggleIdentifier];
}

- (void)unregisterToggleIdentifier:(NSString *)toggleIdentifier
{
	[_toggleImplementations removeObjectForKey:toggleIdentifier];
}

- (void)stateDidChangeForToggleIdentifier:(NSString *)toggleIdentifier
{
	// TODO: Notify others of state changes
}

- (NSArray *)toggleIdentifiers
{
	return [_toggleImplementations allKeys];
}

- (BOOL)toggleStateForToggleID:(NSString *)toggleID
{
	id<A3Toggle> toggle = [_toggleImplementations objectForKey:toggleID];
	return [toggle stateForToggleIdentifier:toggleID];
}

- (void)setToggleState:(BOOL)state onToggleID:(NSString *)toggleID
{
	id<A3Toggle> toggle = [_toggleImplementations objectForKey:toggleID];
	[toggle applyState:state forToggleIdentifier:toggleID];
}


static void processMessage(SInt32 messageId, mach_port_t replyPort, CFDataRef data)
{
	switch ((A3ToggleServiceMessage)messageId) {
		case A3ToggleServiceMessageGetIdentifiers:
			LMSendPropertyListReply(replyPort, [A3ToggleManager sharedInstance].toggleIdentifiers);
			return;
		case A3ToggleServiceMessageGetNameForIdentifier: {
			NSString *identifier = [NSPropertyListSerialization propertyListFromData:(NSData *)data mutabilityOption:0 format:NULL errorDescription:NULL];
			if ([identifier isKindOfClass:[NSString class]]) {
				NSString *name = [[A3ToggleManager sharedInstance] toggleNameForToggleID:identifier];
				LMSendPropertyListReply(replyPort, name);
				return;
			}
			break;
		}
		case A3ToggleServiceMessageGetStateForIdentifier: {
			NSString *identifier = [NSPropertyListSerialization propertyListFromData:(NSData *)data mutabilityOption:0 format:NULL errorDescription:NULL];
			if ([identifier isKindOfClass:[NSString class]]) {
				LMSendIntegerReply(replyPort, [[A3ToggleManager sharedInstance] toggleStateForToggleID:identifier]);
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
					[[A3ToggleManager sharedInstance] setToggleState:[state integerValue] onToggleID:identifier];
				}
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
	processMessage(request->head.msgh_id, replyPort, cfdata);
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
		CFMachPortContext context = { 0, NULL, NULL, NULL, NULL };
		CFMachPortRef machPort = CFMachPortCreate(kCFAllocatorDefault, machPortCallback, &context, NULL);
		CFRunLoopSourceRef machPortSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, machPort, 0);
		CFRunLoopAddSource(CFRunLoopGetCurrent(), machPortSource, kCFRunLoopDefaultMode);
		mach_port_t port = CFMachPortGetPort(machPort);
		kern_return_t err = bootstrap_register(bootstrap, kA3ToggleServiceName, port);
		if (err) NSLog(@"A3 Toggle API: Connection Creation failed with Error: %x", err);
		_toggleImplementations = [[NSMutableDictionary alloc] init];
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
		[A3ToggleManager sharedInstance];
	}
	[pool drain];
}

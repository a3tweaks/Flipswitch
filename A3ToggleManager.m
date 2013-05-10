#import "A3ToggleManager.h"

#import <dlfcn.h>
#import "LightMessaging/LightMessaging.h"

enum {
	A3AllToggles,
	A3TogggleName,
	A3ToggleImage,
	A3ToggleState,
	A3ToggleSetState
};

static LMConnection connection = {
	MACH_PORT_NULL,
	"a3api.togglecomm"
};

__attribute__((visibility("hidden")))
@interface A3ToggleManagerMain : A3ToggleManager
@end

#define kTogglesPath @"/Library/Toggles/"

static A3ToggleManager *_toggleManager = nil;

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

- (NSArray *)allToggles
{
	return nil;
}

- (NSString *)toggleNameForToggleID:(NSString *)toggleID
{
	return nil;
}

- (UIImage *)toggleImageWithBackground:(UIImage *)backgroundImage overlay:(UIImage *)overlayMask andState:(BOOL)state
{
	return nil;
}

- (BOOL)toggleStateForToggleID:(NSString *)toggleID
{
	return NO;
}

- (void)setToggleState:(BOOL)state onToggleID:(NSString *)toggleID
{

}

- (void)dealloc
{    
    [super dealloc];
}

@end

@implementation A3ToggleManagerMain

static void processMessage(SInt32 messageId, mach_port_t replyPort, CFDataRef data)
{
	switch (messageId)
	{
		case A3AllToggles:
		{
			return;
		}
		case A3TogggleName:
		{
			
			return;
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
		kern_return_t err = bootstrap_register(bootstrap, connection.serverName, port);
		if (err) NSLog(@"A3 Toggle API: Connection Creation failed with Error: %x", err);
	}
	return self;
}

@end

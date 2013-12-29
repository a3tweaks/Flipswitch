#import "FSSwitchMainPanel.h"
#import "FSSwitchPanel+Internal.h"
#import "FSSwitchService.h"
#import "FSSwitchDataSource.h"
#import "FSPreferenceSwitchDataSource.h"
#import "FSLazySwitch.h"
#import "FSCapability.h"

#define ROCKETBOOTSTRAP_LOAD_DYNAMIC
#import "LightMessaging/LightMessaging.h"
#import "Internal.h"

#import <notify.h>
#import <sys/stat.h>
#import <libkern/OSAtomic.h>

#define kSwitchesPath @"/Library/Switches/"

@interface UIApplication (Private)
- (void)applicationOpenURL:(NSURL *)url;
- (void)applicationOpenURL:(NSURL *)url publicURLsOnly:(BOOL)publicURLsOnly;
@end

static volatile int32_t stateChangeCount;

@implementation FSSwitchMainPanel

- (void)_registerDataSourceForSwitchIdentifier:(NSArray *)args
{
	[self registerDataSource:[args objectAtIndex:0] forSwitchIdentifier:[args objectAtIndex:1]];
}

- (void)registerDataSource:(id<FSSwitchDataSource>)dataSource forSwitchIdentifier:(NSString *)switchIdentifier;
{
	if (!switchIdentifier) {
		[NSException raise:NSInvalidArgumentException format:@"Switch identifier passed to -[FSSwitchPanel registerSwitch:forIdentifier:] must not be nil"];
	}
	if (!dataSource) {
		[NSException raise:NSInvalidArgumentException format:@"Switch data source passed to -[FSSwitchPanel registerSwitch:forIdentifier:] must not be nil"];
	}
	if (![NSThread isMainThread]) {
		[self performSelectorOnMainThread:@selector(_registerDataSourceForSwitchIdentifier:) withObject:[NSArray arrayWithObjects:dataSource, switchIdentifier, nil] waitUntilDone:YES];
		return;		
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
	if (!switchIdentifier) {
		[NSException raise:NSInvalidArgumentException format:@"Switch identifier passed to -[FSSwitchPanel unregisterSwitchIdentifier:] must not be nil"];
	}
	if (![NSThread isMainThread]) {
		[self performSelectorOnMainThread:@selector(unregisterSwitchIdentifier:) withObject:switchIdentifier waitUntilDone:YES];
		return;
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
	[self postNotificationName:FSSwitchPanelSwitchesChangedNotification userInfo:nil];
}

- (void)_postNotificationForStateDidChangeForSwitchIdentifier:(NSString *)switchIdentifier
{
	NSDictionary *userInfo = switchIdentifier ? [NSDictionary dictionaryWithObject:switchIdentifier forKey:FSSwitchPanelSwitchIdentifierKey] : nil;
	[self postNotificationName:FSSwitchPanelSwitchStateChangedNotification userInfo:userInfo];
}

- (void)stateDidChangeForSwitchIdentifier:(NSString *)switchIdentifier
{
	OSAtomicIncrement32(&stateChangeCount);
	if ([NSThread isMainThread])
		[self _postNotificationForStateDidChangeForSwitchIdentifier:switchIdentifier];
	else
		[self performSelectorOnMainThread:@selector(_postNotificationForStateDidChangeForSwitchIdentifier:) withObject:switchIdentifier waitUntilDone:NO];
}

- (NSArray *)switchIdentifiers
{
	if (![NSThread isMainThread]) {
		return [super switchIdentifiers];
	}
	return [_switchImplementations allKeys];
}

- (NSString *)titleForSwitchIdentifier:(NSString *)switchIdentifier
{
	if (![NSThread isMainThread]) {
		return [super titleForSwitchIdentifier:switchIdentifier];
	}
	id<FSSwitchDataSource> switchImplementation = [_switchImplementations objectForKey:switchIdentifier];
	return [switchImplementation titleForSwitchIdentifier:switchIdentifier];
}

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	if (![NSThread isMainThread]) {
		return [super stateForSwitchIdentifier:switchIdentifier];
	}
	id<FSSwitchDataSource> switchImplementation = [_switchImplementations objectForKey:switchIdentifier];
	return [switchImplementation stateForSwitchIdentifier:switchIdentifier];
}

- (void)setState:(FSSwitchState)state forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (![NSThread isMainThread]) {
		return [super setState:state forSwitchIdentifier:switchIdentifier];
	}
	id<FSSwitchDataSource> switchImplementation = [_switchImplementations objectForKey:switchIdentifier];
	// Workaround switches that don't explicitly send state change notifications :(
	FSSwitchState oldState = [switchImplementation stateForSwitchIdentifier:switchIdentifier];
	int32_t oldStateChangeCount = stateChangeCount;
	[switchImplementation applyState:state forSwitchIdentifier:switchIdentifier];
	if (oldStateChangeCount == stateChangeCount && oldState != [switchImplementation stateForSwitchIdentifier:switchIdentifier]) {
		[self stateDidChangeForSwitchIdentifier:switchIdentifier];
	}
}

- (void)applyActionForSwitchIdentifier:(NSString *)switchIdentifier
{
	if (![NSThread isMainThread]) {
		return [super applyActionForSwitchIdentifier:switchIdentifier];
	}
	id<FSSwitchDataSource> switchImplementation = [_switchImplementations objectForKey:switchIdentifier];
	// Workaround switches that don't explicitly send state change notifications :(
	FSSwitchState oldState = [switchImplementation stateForSwitchIdentifier:switchIdentifier];
	int32_t oldStateChangeCount = stateChangeCount;
	[switchImplementation applyActionForSwitchIdentifier:switchIdentifier];
	if (oldStateChangeCount == stateChangeCount && oldState != [switchImplementation stateForSwitchIdentifier:switchIdentifier]) {
		[self stateDidChangeForSwitchIdentifier:switchIdentifier];
	}
}

- (id)glyphImageDescriptorOfState:(FSSwitchState)switchState size:(CGFloat)size scale:(CGFloat)scale forSwitchIdentifier:(NSString *)switchIdentifier;
{
	if (![NSThread isMainThread]) {
		return [super glyphImageDescriptorOfState:switchState size:size scale:scale forSwitchIdentifier:switchIdentifier];
	}
	id<FSSwitchDataSource> switchImplementation = [_switchImplementations objectForKey:switchIdentifier];
	return [switchImplementation glyphImageDescriptorOfState:switchState size:size scale:scale forSwitchIdentifier:switchIdentifier];
}

- (BOOL)hasAlternateActionForSwitchIdentifier:(NSString *)switchIdentifier
{
	if (![NSThread isMainThread]) {
		return [super hasAlternateActionForSwitchIdentifier:switchIdentifier];
	}
	id<FSSwitchDataSource> switchImplementation = [_switchImplementations objectForKey:switchIdentifier];
	return [switchImplementation hasAlternateActionForSwitchIdentifier:switchIdentifier];
}

- (void)applyAlternateActionForSwitchIdentifier:(NSString *)switchIdentifier
{
	if (![NSThread isMainThread]) {
		return [super applyAlternateActionForSwitchIdentifier:switchIdentifier];
	}
	id<FSSwitchDataSource> switchImplementation = [_switchImplementations objectForKey:switchIdentifier];
	[switchImplementation applyAlternateActionForSwitchIdentifier:switchIdentifier];
}

- (void)postNotificationName:(NSString *)notificationName userInfo:(NSDictionary *)userInfo
{
	[userInfo retain];
	[pendingNotificationUserInfo release];
	pendingNotificationUserInfo = userInfo;
	[[NSNotificationCenter defaultCenter] postNotificationName:notificationName object:self userInfo:userInfo];
	notify_post([notificationName UTF8String]);
}

- (void)openURLAsAlternateAction:(NSURL *)url
{
	if (![NSThread isMainThread]) {
		[self performSelectorOnMainThread:_cmd withObject:url waitUntilDone:YES];
		return;
	}
	NSDictionary *userInfo = url ? [NSDictionary dictionaryWithObject:[url absoluteString] forKey:@"url"] : nil;
	[self postNotificationName:FSSwitchPanelSwitchWillOpenURLNotification userInfo:userInfo];
	UIApplication *app = [UIApplication sharedApplication];
	if ([app respondsToSelector:@selector(applicationOpenURL:publicURLsOnly:)])
		[app applicationOpenURL:url publicURLsOnly:NO];
	else
		[app applicationOpenURL:url];
}

- (BOOL)switchWithIdentifierIsEnabled:(NSString *)switchIdentifier
{
	if (![NSThread isMainThread]) {
		return [super switchWithIdentifierIsEnabled:switchIdentifier];
	}
	id<FSSwitchDataSource> switchImplementation = [_switchImplementations objectForKey:switchIdentifier];
	return [switchImplementation switchWithIdentifierIsEnabled:switchIdentifier];
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
		case FSSwitchServiceMessageGetPendingNotificationUserInfo: {
			LMSendPropertyListReply(replyPort, self->pendingNotificationUserInfo);
			return;
		}
		case FSSwitchServiceMessageGetEnabledForIdentifier: {
			NSString *identifier = [NSPropertyListSerialization propertyListFromData:(NSData *)data mutabilityOption:0 format:NULL errorDescription:NULL];
			if ([identifier isKindOfClass:[NSString class]]) {
				LMSendIntegerReply(replyPort, [self switchWithIdentifierIsEnabled:identifier]);
				return;
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
				if (!FSSystemHasCapability(capability))
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
	Class switchClass = nil;
	if ([[bundle objectForInfoDictionaryKey:@"lazy-load"] boolValue]) {
		switchClass = [FSLazySwitch class];
	} else if ([bundle objectForInfoDictionaryKey:@"CFBundleExecutable"]) {
		NSError *error = nil;
		if ([bundle loadAndReturnError:&error]) {
			NSString *principalClass = [bundle objectForInfoDictionaryKey:@"NSPrincipalClass"];
			if (principalClass) {
				switchClass = NSClassFromString(principalClass);
			}
		} else {
			NSLog(@"Flipswitch: Failed to load bundle with error: %@", error);
		}
	} else {
		NSString *principalClass = [bundle objectForInfoDictionaryKey:@"NSPrincipalClass"];
		if (principalClass) {
			switchClass = NSClassFromString(principalClass);
		}
	}
	if (switchClass) {
		id<FSSwitchDataSource> switchImplementation = [switchClass instancesRespondToSelector:@selector(initWithBundle:)] ? [[switchClass alloc] initWithBundle:bundle] : [[switchClass alloc] init];
		if (switchImplementation) {
			[self registerDataSource:switchImplementation forSwitchIdentifier:bundle.bundleIdentifier];
			[switchImplementation release];
		}
	}
}

- (void)_loadBuiltInSwitches
{
	NSArray *switchDirectoryContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:kSwitchesPath error:nil];
	for (NSString *folder in switchDirectoryContents) {
		NSBundle *bundle = [NSBundle bundleWithPath:[kSwitchesPath stringByAppendingPathComponent:folder]];
		if (bundle) {
			[self _loadSwitchForBundle:bundle];
		}
	}
}

- (id)init
{
	if ((self = [super init]))
	{
		kern_return_t err = LMStartServiceWithUserInfo(kFSSwitchServiceName, CFRunLoopGetCurrent(), machPortCallback, self);
		if (err) NSLog(@"FS Switch API: Connection Creation failed with Error: %x", err);
		_switchImplementations = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[_switchImplementations release];
	[super dealloc];
}

@end

static struct timespec GetFileModifiedTime(const char *path)
{
	struct stat temp;
	if (stat(path, &temp) == 0)
		return temp.st_mtimespec;
	struct timespec distantPast;
	distantPast.tv_sec = 0;
	distantPast.tv_nsec = 0;
	return distantPast;
}

__attribute__((constructor))
static void constructor(void)
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	// Initialize in SpringBoard automatically so that the bootstrap service gets registered
	if ([[NSBundle mainBundle].bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
		// Clear the cache if a new WinterBoard theme has been applied
		struct timespec cacheModified = GetFileModifiedTime("/tmp/FlipswitchCache");
		if (cacheModified.tv_sec != 0) {
			struct timespec winterboardModified = GetFileModifiedTime("/var/mobile/Library/Preferences/com.saurik.WinterBoard.plist");
			if ((cacheModified.tv_sec < winterboardModified.tv_sec) || (cacheModified.tv_sec == winterboardModified.tv_sec && cacheModified.tv_nsec < winterboardModified.tv_nsec)) {
				NSLog(@"Flipswitch: Clearing image cache!");
				[[NSFileManager defaultManager] removeItemAtPath:@"/tmp/FlipswitchCache" error:NULL];
			}
		}
		[FSSwitchPanel sharedPanel];
	}
	[pool drain];
}

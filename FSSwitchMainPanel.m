#import <UIKit/UIKit.h>
#import "FSSwitchMainPanel.h"
#import "FSSwitchPanel+Internal.h"
#import "FSSwitchService.h"
#import "FSSwitchDataSource.h"
#import "FSPreferenceSwitchDataSource.h"
#import "FSLazySwitch.h"
#import "FSCapability.h"
#import "FSLaunchURL.h"
#import "ModifiedTime.h"
#import "FSSwitchPanel+Internal.h"

#define ROCKETBOOTSTRAP_LOAD_DYNAMIC
#import "LightMessaging/LightMessaging.h"
#import "Internal.h"
#import "audit_lookup.h"

#import <objc/runtime.h>
#import <notify.h>
#import <sys/stat.h>
#import <libkern/OSAtomic.h>
#import <CoreFoundation/CFUserNotification.h>
#import <UIKit/UIKit.h>

#define kSwitchesPath @"/Library/Switches/"

static volatile int32_t stateChangeCount;
NSMutableDictionary *_switchImplementations;
static BOOL hasUpdatedSwitches;
static NSDictionary *pendingNotificationUserInfo;

@interface FSSwitchMainPanel ()
- (void)_postNotificationName:(NSString *)notificationName userInfo:(NSDictionary *)userInfo;
@end

@implementation FSSwitchMainPanel

- (void)_registerDataSourceForSwitchIdentifier:(NSArray *)args
{
	[self registerDataSource:[args objectAtIndex:0] forSwitchIdentifier:[args objectAtIndex:1]];
}

- (void)registerDataSource:(id<FSSwitchDataSource>)dataSource forSwitchIdentifier:(NSString *)switchIdentifier;
{
	if (!switchIdentifier) {
		[NSException raise:NSInvalidArgumentException format:@"Switch identifier passed to -[FSSwitchPanel registerDataSource:forSwitchIdentifier:] must not be nil"];
	}
	if (!dataSource) {
		[NSException raise:NSInvalidArgumentException format:@"Switch data source passed to -[FSSwitchPanel registerDataSource:forSwitchIdentifier:] must not be nil"];
	}
	if (![NSThread isMainThread]) {
		[self performSelectorOnMainThread:@selector(_registerDataSourceForSwitchIdentifier:) withObject:[NSArray arrayWithObjects:dataSource, switchIdentifier, nil] waitUntilDone:YES];
		return;		
	}
	// Verify that switchImplementation is either a valid action-like switchImplementation or setting-like switchImplementation
	if ([(NSObject *)dataSource methodForSelector:@selector(applyState:forSwitchIdentifier:)] == [NSObject instanceMethodForSelector:@selector(applyState:forSwitchIdentifier:)]) {
		if ([(NSObject *)dataSource methodForSelector:@selector(applyActionForSwitchIdentifier:)] == [NSObject instanceMethodForSelector:@selector(applyActionForSwitchIdentifier:)]) {
			[NSException raise:NSInvalidArgumentException format:@"Switch data source passed to -[FSSwitchPanel registerDataSource:forSwitchIdentifier:] must override either applyState:forSwitchIdentifier: or applyActionForSwitchIdentifier:"];
		}
	} else {
		if ([(NSObject *)dataSource methodForSelector:@selector(stateForSwitchIdentifier:)] == [NSObject instanceMethodForSelector:@selector(stateForSwitchIdentifier:)]) {
			[NSException raise:NSInvalidArgumentException format:@"Switch data source passed to -[FSSwitchPanel registerDataSource:forSwitchIdentifier:] must override stateForSwitchIdentifier:"];
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
	[self _postNotificationName:FSSwitchPanelSwitchesChangedNotification userInfo:nil];
}

- (void)_postNotificationForStateDidChangeForSwitchIdentifier:(NSString *)switchIdentifier
{
	NSDictionary *userInfo = switchIdentifier ? [NSDictionary dictionaryWithObject:switchIdentifier forKey:FSSwitchPanelSwitchIdentifierKey] : nil;
	[self _postNotificationName:FSSwitchPanelSwitchStateChangedNotification userInfo:userInfo];
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
	return [switchImplementation titleForSwitchIdentifier:switchIdentifier] ?: @"";
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

- (id)glyphImageDescriptorOfState:(FSSwitchState)switchState variant:(NSString *)variant size:(CGFloat)size scale:(CGFloat)scale forSwitchIdentifier:(NSString *)switchIdentifier;
{
	if (![NSThread isMainThread]) {
		return [super glyphImageDescriptorOfState:switchState variant:variant size:size scale:scale forSwitchIdentifier:switchIdentifier];
	}
	id<FSSwitchDataSource> switchImplementation = [_switchImplementations objectForKey:switchIdentifier];
	if (switchImplementation) {
		return [switchImplementation glyphImageDescriptorOfState:switchState variant:variant size:size scale:scale forSwitchIdentifier:switchIdentifier];
	} else if ([[NSFileManager defaultManager] fileExistsAtPath:switchIdentifier]) {
		return [switchIdentifier stringByResolvingSymlinksInPath];
	} else {
		return nil;
	}
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

#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_7_0
- (void)_postNotificationHelper:(NSArray *)data
{
	[self _postNotificationName:[data objectAtIndex:0] userInfo:[data objectAtIndex:1]];
}
#endif

- (void)_postNotificationName:(NSString *)notificationName userInfo:(NSDictionary *)userInfo
{
	if (![NSThread isMainThread]) {
#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_7_0
		[self performSelectorOnMainThread:@selector(_postNotificationHelper:) withObject:[NSArray arrayWithObjects:notificationName, userInfo ?: [NSDictionary dictionary], nil] waitUntilDone:NO];
#else
		dispatch_async(dispatch_get_main_queue(), ^{
			[self _postNotificationName:notificationName userInfo:userInfo];
		});
#endif
		return;
	}
	[userInfo retain];
	[pendingNotificationUserInfo release];
	pendingNotificationUserInfo = userInfo;
	[[NSNotificationCenter defaultCenter] postNotificationName:notificationName object:self userInfo:userInfo];
	notify_post([notificationName UTF8String]);
}

- (void)openURLAsAlternateAction:(NSURL *)url
{
	if (![NSThread isMainThread]) {
		[self performSelectorOnMainThread:_cmd withObject:url waitUntilDone:NO];
		return;
	}
	NSDictionary *userInfo = url ? [NSDictionary dictionaryWithObject:[url absoluteString] forKey:@"url"] : nil;
	[self _postNotificationName:FSSwitchPanelSwitchWillOpenURLNotification userInfo:userInfo];
	FSLaunchURL(url);
}

- (BOOL)switchWithIdentifierIsEnabled:(NSString *)switchIdentifier
{
	if (![NSThread isMainThread]) {
		return [super switchWithIdentifierIsEnabled:switchIdentifier];
	}
	id<FSSwitchDataSource> switchImplementation = [_switchImplementations objectForKey:switchIdentifier];
	return [switchImplementation switchWithIdentifierIsEnabled:switchIdentifier];
}

- (void)beginPrewarmingForSwitchIdentifier:(NSString *)switchIdentifier
{
	if (![NSThread isMainThread]) {
		return [super beginPrewarmingForSwitchIdentifier:switchIdentifier];
	}
	id<FSSwitchDataSource> switchImplementation = [_switchImplementations objectForKey:switchIdentifier];
	return [switchImplementation beginPrewarmingForSwitchIdentifier:switchIdentifier];
}

- (void)cancelPrewarmingForSwitchIdentifier:(NSString *)switchIdentifier;
{
	if (![NSThread isMainThread]) {
		return [super cancelPrewarmingForSwitchIdentifier:switchIdentifier];
	}
	id<FSSwitchDataSource> switchImplementation = [_switchImplementations objectForKey:switchIdentifier];
	return [switchImplementation cancelPrewarmingForSwitchIdentifier:switchIdentifier];
}

- (NSString *)descriptionOfState:(FSSwitchState)state forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (![NSThread isMainThread]) {
		return [super descriptionOfState:state forSwitchIdentifier:switchIdentifier];
	}
	id<FSSwitchDataSource> switchImplementation = [_switchImplementations objectForKey:switchIdentifier];
	return [switchImplementation descriptionOfState:state forSwitchIdentifier:switchIdentifier];
}

- (Class <FSSwitchSettingsViewController>)settingsViewControllerClassForSwitchIdentifier:(NSString *)switchIdentifier
{
	if (![NSThread isMainThread]) {
		return [super settingsViewControllerClassForSwitchIdentifier:switchIdentifier];
	}
	id<FSSwitchDataSource> switchImplementation = [_switchImplementations objectForKey:switchIdentifier];
	Class _class = [switchImplementation settingsViewControllerClassForSwitchIdentifier:switchIdentifier];
	if (!_class)
		return nil;
	if (![_class isSubclassOfClass:[UIViewController class]]) {
		NSLog(@"Flipswitch: %@ is not a UIViewController (for switch %@)", _class, switchIdentifier);
		return nil;
	}
	if (![_class conformsToProtocol:@protocol(FSSwitchSettingsViewController)]) {
		NSLog(@"Flipswitch: %@ does not conform to FSSwitchSettingsViewController (for switch %@)", _class, switchIdentifier);
		return nil;
	}
	return _class;
}

- (BOOL)switchWithIdentifierIsSimpleAction:(NSString *)switchIdentifier
{
	if (![NSThread isMainThread]) {
		return [super switchWithIdentifierIsSimpleAction:switchIdentifier];
	}
	id<FSSwitchDataSource> switchImplementation = [_switchImplementations objectForKey:switchIdentifier];
	return [switchImplementation switchWithIdentifierIsSimpleAction:switchIdentifier];
}

- (UIColor *)primaryColorForSwitchIdentifier:(NSString *)switchIdentifier
{
	if (![NSThread isMainThread]) {
		return [super primaryColorForSwitchIdentifier:switchIdentifier];
	}
	id<FSSwitchDataSource> switchImplementation = [_switchImplementations objectForKey:switchIdentifier];
	return [switchImplementation primaryColorForSwitchIdentifier:switchIdentifier];
}

typedef enum {
	FSApprovalStateUnknown = -1,
	FSApprovalStateDenied = 0,
	FSApprovalStateAllowed = 1,
} FSApprovalState;

static NSMutableSet *deniedDisplayIdentifiers;

static FSApprovalState approvalStateForDisplayIdentifier(NSString *displayIdentifier)
{
	if (!displayIdentifier || [displayIdentifier isEqualToString:@"com.apple.Preferences"] || [displayIdentifier isEqualToString:@"com.apple.springboard"])
		return FSApprovalStateAllowed;
	NSString *key = [@"APIAccessApproved-" stringByAppendingString:displayIdentifier];
	if (CFPreferencesGetAppBooleanValue((CFStringRef)key, CFSTR("com.a3tweaks.flipswitch"), NULL)) {
		return FSApprovalStateAllowed;
	}
	return [deniedDisplayIdentifiers containsObject:displayIdentifier] ? FSApprovalStateDenied : FSApprovalStateUnknown;
}

static void processMessage(FSSwitchMainPanel *self, SInt32 messageId, mach_port_t replyPort, CFDataRef data, const audit_token_t *token);
static void ApproveCFUserNotificationCallback(CFUserNotificationRef userNotification, CFOptionFlags responseFlags);

typedef struct {
	FSSwitchServiceMessage messageId;
	mach_port_t replyPort;
	CFDataRef data;
	NSString *displayIdentifier;
	NSString *displayName;
} FSQueuedMessage;

static struct {
	CFMutableArrayRef queue;
	CFUserNotificationRef userNotification;
	CFRunLoopSourceRef runLoopSource;
} pendingApproval;

static void displayAlertForMessage(FSQueuedMessage *message)
{
	const CFTypeRef keys[] = {
		kCFUserNotificationAlertTopMostKey,
		kCFUserNotificationAlertHeaderKey,
		kCFUserNotificationAlertMessageKey,
		kCFUserNotificationDefaultButtonTitleKey,
		kCFUserNotificationOtherButtonTitleKey,
	};
	const CFTypeRef values[] = {
		kCFBooleanTrue,
		CFSTR("Flipswitch"),
		(CFStringRef)[NSString stringWithFormat:@"%@ is requesting permission to adjust your device settings", message->displayName],
		CFSTR("Grant Access"),
		CFSTR("Deny"),
	};
	CFDictionaryRef dict = CFDictionaryCreate(kCFAllocatorDefault, (const void **)keys, (const void **)values, sizeof(keys) / sizeof(*keys), &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
	SInt32 err = 0;
	pendingApproval.userNotification = CFUserNotificationCreate(kCFAllocatorDefault, 0.0, kCFUserNotificationPlainAlertLevel, &err, dict);
	pendingApproval.runLoopSource = CFUserNotificationCreateRunLoopSource(kCFAllocatorDefault, pendingApproval.userNotification, ApproveCFUserNotificationCallback, 0);
	CFRunLoopAddSource(CFRunLoopGetMain(), pendingApproval.runLoopSource, kCFRunLoopCommonModes);
	CFRelease(dict);
}

static void CleanupQueuedMessage(FSQueuedMessage *message)
{
	if (message->data) {
		CFRelease(message->data);
	}
	[message->displayIdentifier release];
	[message->displayName release];
	free(message);
}

static void ApproveCFUserNotificationCallback(CFUserNotificationRef userNotification, CFOptionFlags responseFlags)
{
	// Cleanup the alert
	CFRunLoopSourceInvalidate(pendingApproval.runLoopSource);
	CFRelease(pendingApproval.runLoopSource);
	CFRelease(pendingApproval.userNotification);
	pendingApproval.userNotification = NULL;
	// Handle the message, if approved
	FSQueuedMessage *message = (FSQueuedMessage *)CFArrayGetValueAtIndex(pendingApproval.queue, 0);
	NSString *displayIdentifier = message->displayIdentifier;
	if (displayIdentifier) {
		if (responseFlags == kCFUserNotificationDefaultResponse) {
			NSString *key = [@"APIAccessApproved-" stringByAppendingString:displayIdentifier];
			CFPreferencesSetAppValue((CFStringRef)key, (id)kCFBooleanTrue, CFSTR("com.a3tweaks.flipswitch"));
			CFPreferencesAppSynchronize(CFSTR("com.a3tweaks.flipswitch"));
		} else {
			if (!deniedDisplayIdentifiers) {
				deniedDisplayIdentifiers = [[NSMutableSet alloc] init];
			}
			[deniedDisplayIdentifiers addObject:displayIdentifier];
		}
	}
	// Process more incoming messages, stopping when we hit one that needs to alert
	do {
		message = (FSQueuedMessage *)CFArrayGetValueAtIndex(pendingApproval.queue, 0);
		switch (approvalStateForDisplayIdentifier(message->displayIdentifier)) {
			case FSApprovalStateUnknown:
				if (!pendingApproval.userNotification) {
					displayAlertForMessage(message);
				}
				return;
			case FSApprovalStateAllowed:
				CFArrayRemoveValueAtIndex(pendingApproval.queue, 0);
				processMessage((FSSwitchMainPanel *)[FSSwitchPanel sharedPanel], message->messageId, message->replyPort, message->data, NULL);
				CleanupQueuedMessage(message);
				break;
			case FSApprovalStateDenied:
				CFArrayRemoveValueAtIndex(pendingApproval.queue, 0);
				LMSendReply(message->replyPort, NULL, 0);
				CleanupQueuedMessage(message);
				break;
			default:
				return;
		}
	} while (CFArrayGetCount(pendingApproval.queue));
}

static BOOL handleApproveOfMessage(FSSwitchServiceMessage messageId, mach_port_t replyPort, CFDataRef data, FSSwitchMainPanel *self, const audit_token_t *token)
{
	NSString *displayIdentifier = nil;
	if (!token || !audit_lookup_by_token(*token, &displayIdentifier, NULL))
		return NO;
	switch (approvalStateForDisplayIdentifier(displayIdentifier)) {
		case FSApprovalStateUnknown: {
			FSQueuedMessage *message = malloc(sizeof(*message));
			message->messageId = messageId;
			message->replyPort = replyPort;
			message->data = (CFDataRef)[[NSData alloc] initWithData:(NSData *)data];
			message->displayIdentifier = [displayIdentifier retain];
			audit_lookup_by_token(*token, NULL, &message->displayName);
			[message->displayName retain];
			if (!pendingApproval.queue) {
				pendingApproval.queue = CFArrayCreateMutable(kCFAllocatorDefault, 0, NULL);
			}
			CFArrayAppendValue(pendingApproval.queue, message);
			if (!pendingApproval.userNotification) {
				displayAlertForMessage(message);
			}
			return YES;
		}
		case FSApprovalStateAllowed:
			return NO;
		case FSApprovalStateDenied:
			LMSendReply(replyPort, NULL, 0);
			return YES;
		default:
			return NO;
	}
}

#define PROTECT_MESSAGE() do { \
	if (handleApproveOfMessage((FSSwitchServiceMessage)messageId, replyPort, data, self, token)) \
		return; \
} while (0)

static void processMessage(FSSwitchMainPanel *self, SInt32 messageId, mach_port_t replyPort, CFDataRef data, const audit_token_t *token)
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
			PROTECT_MESSAGE();
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
				NSString *variant = [args objectForKey:@"variant"];
				id imageDescriptor = [self glyphImageDescriptorOfState:switchState variant:variant size:size scale:scale forSwitchIdentifier:switchIdentifier];
				if (imageDescriptor) {
					// TODO: Allow responding with a string representing file path, data containing image bytes, or UImage
					LMSendPropertyListReply(replyPort, imageDescriptor);
					return;
				}
			}
			break;
		}
		case FSSwitchServiceMessageApplyActionForIdentifier: {
			PROTECT_MESSAGE();
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
			PROTECT_MESSAGE();
			NSString *identifier = [NSPropertyListSerialization propertyListFromData:(NSData *)data mutabilityOption:0 format:NULL errorDescription:NULL];
			if ([identifier isKindOfClass:[NSString class]]) {
				[self applyAlternateActionForSwitchIdentifier:identifier];
			}
			break;
		}
		case FSSwitchServiceMessageGetPendingNotificationUserInfo: {
			LMSendPropertyListReply(replyPort, pendingNotificationUserInfo);
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
		case FSSwitchServiceMessageBeginPrewarmingForIdentifier: {
			PROTECT_MESSAGE();
			NSString *identifier = [NSPropertyListSerialization propertyListFromData:(NSData *)data mutabilityOption:0 format:NULL errorDescription:NULL];
			if ([identifier isKindOfClass:[NSString class]]) {
				[self beginPrewarmingForSwitchIdentifier:identifier];
				break;
			}
			break;
		}
		case FSSwitchServiceMessageCancelPrewarmingForIdentifier: {
			PROTECT_MESSAGE();
			NSString *identifier = [NSPropertyListSerialization propertyListFromData:(NSData *)data mutabilityOption:0 format:NULL errorDescription:NULL];
			if ([identifier isKindOfClass:[NSString class]]) {
				[self cancelPrewarmingForSwitchIdentifier:identifier];
				break;
			}
			break;
		}
		case FSSwitchServiceMessageOpenURLAsAlternateAction: {
			PROTECT_MESSAGE();
			NSString *url = [NSPropertyListSerialization propertyListFromData:(NSData *)data mutabilityOption:0 format:NULL errorDescription:NULL];
			if ([url isKindOfClass:[NSString class]]) {
				[self openURLAsAlternateAction:[NSURL URLWithString:url]];
				break;
			}
			break;
		}
		case FSSwitchServiceMessageSettingsViewControllerForIdentifier: {
			NSString *identifier = [NSPropertyListSerialization propertyListFromData:(NSData *)data mutabilityOption:0 format:NULL errorDescription:NULL];
			if ([identifier isKindOfClass:[NSString class]]) {
				Class _class = [self settingsViewControllerClassForSwitchIdentifier:identifier];
				if (_class) {
					const char *imageName = class_getImageName(_class);
					NSArray *response = [NSArray arrayWithObjects:NSStringFromClass(_class), imageName ? [NSString stringWithUTF8String:imageName] : nil, nil];
					LMSendPropertyListReply(replyPort, response);
					return;
				}
			}
			break;
		}
		case FSSwitchServiceMessageDescriptionOfStateForIdentifier: {
			NSArray *args = [NSPropertyListSerialization propertyListFromData:(NSData *)data mutabilityOption:0 format:NULL errorDescription:NULL];
			if ([args isKindOfClass:[NSArray class]] && [args count] == 2) {
				NSString *identifier = [args objectAtIndex:0];
				if ([identifier isKindOfClass:[NSString class]]) {
					NSNumber *state = [args objectAtIndex:1];
					if ([state isKindOfClass:[NSNumber class]]) {
						NSString *description = [self descriptionOfState:[state intValue] forSwitchIdentifier:identifier];
						if (description) {
							LMSendPropertyListReply(replyPort, description);
							return;
						}
					}
				}
			}
			break;
		}
		case FSSwitchServiceMessageGetIsSimpleActionForIdentifier: {
			NSString *identifier = [NSPropertyListSerialization propertyListFromData:(NSData *)data mutabilityOption:0 format:NULL errorDescription:NULL];
			if ([identifier isKindOfClass:[NSString class]]) {
				LMSendIntegerReply(replyPort, [self switchWithIdentifierIsSimpleAction:identifier]);
				return;
			}
			break;
		}
		case FSSwitchServiceMessageGetPrimaryColorForIdentifier: {
			NSString *identifier = [NSPropertyListSerialization propertyListFromData:(NSData *)data mutabilityOption:0 format:NULL errorDescription:NULL];
			if ([identifier isKindOfClass:[NSString class]]) {
				UIColor *color = [self primaryColorForSwitchIdentifier:identifier];
				if (color) {
					double components[4];
#if CGFLOAT_IS_DOUBLE
					if ([color getRed:&components[0] green:&components[1] blue:&components[2] alpha:&components[3]]) {
#else
					CGFloat cgComponents[4];
					if ([color getRed:&cgComponents[0] green:&cgComponents[1] blue:&cgComponents[2] alpha:&cgComponents[3]]) {
						for (int i = 0; i < 4; i++) {
							components[i] = cgComponents[i];
						}
#endif
						LMSendReply(replyPort, &components, sizeof(components));
						return;
					}
				}
			}
			break;
		}
	}
	LMSendReply(replyPort, NULL, 0);
}

static const audit_token_t *extract_audit_token(mach_msg_header_t *request)
{
	mach_msg_audit_trailer_t *trailer = (mach_msg_audit_trailer_t *)((vm_offset_t)request + round_msg(request->msgh_size));
	if ((trailer->msgh_trailer_type == MACH_MSG_TRAILER_FORMAT_0) && (trailer->msgh_trailer_size >= MACH_MSG_TRAILER_FORMAT_0_SIZE)) {
		return &trailer->msgh_audit;
	} else {
		return NULL;
	}
}

static void machPortCallback(CFMachPortRef port, void *bytes, CFIndex size, void *info)
{
	LMMessage *request = bytes;
	if (!LMDataWithSizeIsValidMessage(bytes, size)) {
		LMSendReply(request->head.msgh_remote_port, NULL, 0);
		LMResponseBufferFree(bytes);
		return;
	}
	// Send Response
	const void *data = LMMessageGetData(request);
	size_t length = LMMessageGetDataLength(request);
	mach_port_t replyPort = request->head.msgh_remote_port;
	CFDataRef cfdata = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, data ?: &data, length, kCFAllocatorNull);
	processMessage((FSSwitchMainPanel *)[FSSwitchPanel sharedPanel], request->head.msgh_id, replyPort, cfdata, extract_audit_token(bytes));
	if (cfdata)
		CFRelease(cfdata);
	LMResponseBufferFree(bytes);
}

- (void)_loadSwitchForBundle:(NSBundle *)bundle
{
	Class arrayClass = [NSArray class];
	if ([[bundle objectForInfoDictionaryKey:@"wait-for-application"] boolValue] && (UIApp == nil)) {
		[self performSelector:_cmd withObject:bundle afterDelay:0.0];
		return;
	}
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
		switchClass = [_FSLazySwitch class];
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
#ifdef DEBUG
	NSLog(@"Flipswitch: Loading built in switches");
#endif
	dlopen("/Library/Flipswitch/libFlipswitchSwitches.dylib", RTLD_LAZY);
#ifdef DEBUG
	const char *error = dlerror();
	if (error) {
		NSLog(@"Flipswitch: Loading bundled switches failed with: %s", error);
	}
#endif
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

__attribute__((constructor))
static void constructor(void)
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	// Clear the cache if a new WinterBoard theme has been applied
	struct timespec cacheModified = GetFileModifiedTime("/tmp/FlipswitchCache");
	if (cacheModified.tv_sec != 0) {
		struct timespec winterboardModified = GetFileModifiedTime("/var/mobile/Library/Preferences/com.saurik.WinterBoard.plist");
		if ((cacheModified.tv_sec < winterboardModified.tv_sec) || (cacheModified.tv_sec == winterboardModified.tv_sec && cacheModified.tv_nsec < winterboardModified.tv_nsec)) {
			NSLog(@"Flipswitch: Clearing image cache!");
			[[NSFileManager defaultManager] removeItemAtPath:@"/tmp/FlipswitchCache" error:NULL];
		}
	}
	kern_return_t err = LMStartService(kFSSwitchServiceName, CFRunLoopGetCurrent(), machPortCallback);
	if (err) NSLog(@"Flipswitch: Unable to bootstrap service with error: %x", err);
	[pool drain];
}

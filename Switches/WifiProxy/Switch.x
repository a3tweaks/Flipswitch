#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>

#import <Foundation/Foundation.h>
#undef __OSX_AVAILABLE_STARTING
#define __OSX_AVAILABLE_STARTING(mac,ios)
#import <SystemConfiguration/SystemConfiguration.h>

@interface SBWiFiManager
+ (id)sharedInstance;
- (BOOL)wiFiEnabled;
- (void)setWiFiEnabled:(BOOL)enabled;
@end

@interface NSNetworkSettings : NSObject
+ (NSNetworkSettings *)sharedNetworkSettings;
- (void)setProxyDictionary:(NSDictionary *)dictionary;
- (BOOL)connectedToInternet:(BOOL)unknown;
- (void)setProxyPropertiesForURL:(NSURL *)url onStream:(CFReadStreamRef)stream;
- (BOOL)isProxyNeededForURL:(NSURL *)url;
- (NSDictionary *)proxyPropertiesForURL:(NSURL *)url;
- (NSDictionary *)proxyDictionary;
- (void)_listenForProxySettingChanges;
- (void)_updateProxySettings;
@end

@interface WifiProxySwitch : NSObject <FSSwitchDataSource>
+ (void)stateDidChange;
- (id)_init;
@end

static BOOL wiFiEnabled;

%hook SBWiFiManager

- (void)_powerStateDidChange
{
	%orig();
	wiFiEnabled = [self wiFiEnabled];
	[WifiProxySwitch performSelectorOnMainThread:@selector(stateDidChange) withObject:nil waitUntilDone:NO];
}

%end

static SCNetworkServiceRef CopyWiFiNetworkService(SCPreferencesRef prefs)
{
	SCNetworkServiceRef result = NULL;
	SCNetworkSetRef currentSet = SCNetworkSetCopyCurrent(prefs);
	if (currentSet) {
		CFArrayRef services = SCNetworkSetCopyServices(currentSet);
		if (services) {
			for (CFIndex i = 0, count = CFArrayGetCount(services); i < count; i++) {
				SCNetworkServiceRef service = CFArrayGetValueAtIndex(services, i);
				if (service) {
					SCNetworkInterfaceRef interface = SCNetworkServiceGetInterface(service);
					if (interface) {
						CFStringRef bsdName = SCNetworkInterfaceGetBSDName(interface);
						if (bsdName && CFEqual(bsdName, CFSTR("en0"))) {
							result = CFRetain(service);
							break;
						}
					}
				}
			}
			CFRelease(services);
		}
		CFRelease(currentSet);
	}
	return result;
}

static BOOL IsEnabled(void)
{
	BOOL result = NO;
	if (wiFiEnabled) {
		SCPreferencesRef prefs = SCPreferencesCreateWithAuthorization(NULL, CFSTR("com.apple.settings.wi-fi"), NULL, NULL);
		if (prefs) {
			SCNetworkServiceRef wifiService = CopyWiFiNetworkService(prefs);
			if (wifiService) {
				SCNetworkProtocolRef proxyProtocol = SCNetworkServiceCopyProtocol(wifiService, kSCNetworkProtocolTypeProxies);
				if (proxyProtocol) {
					CFDictionaryRef configuration = SCNetworkProtocolGetConfiguration(proxyProtocol);
					if (configuration && CFDictionaryGetValue(configuration, kSCPropNetProxiesHTTPProxy) && CFDictionaryGetValue(configuration, kSCPropNetProxiesHTTPPort)) {
						result = YES;
					}
				}
				CFRelease(wifiService);
			}
			CFRelease(prefs);
		}
	}
	return result;
}

%hook NSNetworkSettings

- (void)_updateProxySettings
{
	%orig();
	[WifiProxySwitch performSelectorOnMainThread:@selector(stateDidChange) withObject:nil waitUntilDone:NO];
}

%end

@implementation WifiProxySwitch

+ (void)stateDidChange
{
	static WifiProxySwitch *sharedSwitch;
	if (sharedSwitch) {
		[[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:[NSBundle bundleForClass:self].bundleIdentifier];
	} else if (IsEnabled()) {
		sharedSwitch = [[self alloc] _init];
		[[FSSwitchPanel sharedPanel] registerDataSource:sharedSwitch forSwitchIdentifier:[NSBundle bundleForClass:self].bundleIdentifier];
	}
}

static void PreferencesCallBack(SCPreferencesRef _prefs, SCPreferencesNotification notificationType, void *info)
{
	if ((notificationType & kSCPreferencesNotificationApply) == kSCPreferencesNotificationApply) {
		[WifiProxySwitch performSelectorOnMainThread:@selector(stateDidChange) withObject:nil waitUntilDone:NO];
	}
}

- (id)init
{
	[self release];
	SCPreferencesRef prefs = SCPreferencesCreateWithAuthorization(NULL, CFSTR("com.apple.settings.wi-fi"), NULL, NULL);
	if (prefs) {
		if ([%c(NSNetworkSettings) respondsToSelector:@selector(sharedNetworkSettings)]) {
			[%c(NSNetworkSettings) sharedNetworkSettings];
		}
		SCPreferencesContext context = {
			0,
			NULL,
			NULL,
			NULL,
			NULL
		};
		SCPreferencesSetCallback(prefs, PreferencesCallBack, &context);
		SCPreferencesScheduleWithRunLoop(prefs, CFRunLoopGetMain(), kCFRunLoopCommonModes);
		wiFiEnabled = [[%c(SBWiFiManager) sharedInstance] wiFiEnabled];
		[WifiProxySwitch stateDidChange];
	}
	return nil;
}

- (id)_init
{
	return [super init];
}

- (BOOL)switchWithIdentifierIsEnabled:(NSString *)switchIdentifier
{
	return IsEnabled();
}

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	FSSwitchState result = FSSwitchStateIndeterminate;
	if (wiFiEnabled) {
		SCPreferencesRef prefs = SCPreferencesCreateWithAuthorization(NULL, CFSTR("com.apple.settings.wi-fi"), NULL, NULL);
		if (prefs) {
			SCNetworkServiceRef wifiService = CopyWiFiNetworkService(prefs);
			if (wifiService) {
				SCNetworkProtocolRef proxyProtocol = SCNetworkServiceCopyProtocol(wifiService, kSCNetworkProtocolTypeProxies);
				if (proxyProtocol) {
					CFDictionaryRef configuration = SCNetworkProtocolGetConfiguration(proxyProtocol);
					if (configuration && CFDictionaryGetValue(configuration, kSCPropNetProxiesHTTPProxy) && CFDictionaryGetValue(configuration, kSCPropNetProxiesHTTPPort)) {
						result = [[(NSDictionary *)configuration objectForKey:(id)kSCPropNetProxiesHTTPEnable] boolValue];
					}
				}
				CFRelease(wifiService);
			}
			CFRelease(prefs);
		}
	}
	return result;
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (newState == FSSwitchStateIndeterminate)
		return;
	if (!wiFiEnabled)
		return;
	SCPreferencesRef prefs = SCPreferencesCreateWithAuthorization(NULL, CFSTR("com.apple.settings.wi-fi"), NULL, NULL);
	if (!SCPreferencesLock(prefs, NO)) {
		CFRelease(prefs);
		return;
	}
	SCNetworkServiceRef wifiService = CopyWiFiNetworkService(prefs);
	if (wifiService) {
		SCNetworkProtocolRef proxyProtocol = SCNetworkServiceCopyProtocol(wifiService, kSCNetworkProtocolTypeProxies);
		if (proxyProtocol) {
			CFDictionaryRef configuration = SCNetworkProtocolGetConfiguration(proxyProtocol);
			if (configuration && CFDictionaryGetValue(configuration, kSCPropNetProxiesHTTPProxy) && CFDictionaryGetValue(configuration, kSCPropNetProxiesHTTPPort)) {
				NSMutableDictionary *config = [(NSDictionary *)configuration mutableCopy];
				NSNumber *enabled = [NSNumber numberWithInt:newState == FSSwitchStateOn];
				[config setObject:enabled forKey:(id)kSCPropNetProxiesHTTPEnable];
				[config setObject:enabled forKey:(id)kSCPropNetProxiesHTTPSEnable];
				SCNetworkProtocolSetConfiguration(proxyProtocol, (CFDictionaryRef)config);
				[config release];
				SCPreferencesCommitChanges(prefs);
				SCPreferencesApplyChanges(prefs);
			}
		}
		CFRelease(wifiService);
	}
	SCPreferencesUnlock(prefs);
	CFRelease(prefs);
}

@end

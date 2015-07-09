#import <SpringBoard/SpringBoard.h>
#import <objc/runtime.h>
#import <bsm/libbsm.h>
#import <libproc/libproc.h>

@interface LSBundleProxy : NSObject
+ (instancetype)bundleProxyForURL:(NSURL *)url;
@property (nonatomic, readonly) NSString *bundleIdentifier;
@property (nonatomic, readonly) NSString *localizedShortName;
@end

static bool audit_lookup_by_pid(pid_t pid, NSString **bundleIdentifier, NSString **displayName)
{
	Class LSBundleProxyClass = objc_getClass("LSBundleProxy");
	if (LSBundleProxyClass) {
		// Support modern iOS versions that have LSBundleProxy
		char path[PROC_PIDPATHINFO_MAXSIZE];
		if (proc_pidpath(pid, path, sizeof(path)) > 0) {
			NSURL *bundleURL = [NSURL fileURLWithPath:[[NSString stringWithUTF8String:path] stringByDeletingLastPathComponent]];
			if (bundleURL) {
				LSBundleProxy *bundle = [LSBundleProxyClass bundleProxyForURL:bundleURL];
				if (bundle) {
					if (bundleIdentifier) {
						*bundleIdentifier = [bundle bundleIdentifier];
					}
					if (displayName) {
						*displayName = [bundle localizedShortName];
					}
					return true;
				}
			}
		}
	} else {
		// Support older iOS versions that don't have LaunchServices
		SBApplicationController *ac = (SBApplicationController *)[objc_getClass("SBApplicationController") sharedInstance];
		if ([ac respondsToSelector:@selector(applicationWithPid:)]) {
			SBApplication *app = [ac applicationWithPid:pid];
			if (app) {
				if (bundleIdentifier) {
					*bundleIdentifier = [app respondsToSelector:@selector(displayIdentifier)] ? [app displayIdentifier] : [app bundleIdentifier];
				}
				if (displayName) {
					*displayName = [app displayName];
				}
				return true;
			}
		}
	}
	return false;
}

static bool audit_lookup_by_token(audit_token_t token, NSString **bundleIdentifier, NSString **displayName)
{
	pid_t pid = 0;
	audit_token_to_au32(token, NULL, NULL, NULL, NULL, NULL, &pid, NULL, NULL);
	return audit_lookup_by_pid(pid, bundleIdentifier, displayName);
}

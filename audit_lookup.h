#import <SpringBoard/SpringBoard.h>
#import <objc/runtime.h>
#import <bsm/libbsm.h>

static bool audit_lookup_by_pid(pid_t pid, NSString **bundleIdentifier, NSString **displayName)
{
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
	return false;
}

static bool audit_lookup_by_token(audit_token_t token, NSString **bundleIdentifier, NSString **displayName)
{
	pid_t pid = 0;
	audit_token_to_au32(token, NULL, NULL, NULL, NULL, NULL, &pid, NULL, NULL);
	return audit_lookup_by_pid(pid, bundleIdentifier, displayName);
}

#import <Foundation/Foundation.h>
#import <bsm/libbsm.h>
#import <libproc/libproc.h>

static bool audit_lookup_by_pid(pid_t pid, NSString **bundleIdentifier, NSString **displayName)
{
	char path[PROC_PIDPATHINFO_MAXSIZE];
	if (proc_pidpath(pid, path, sizeof(path)) > 0) {
		NSBundle *bundle = [NSBundle bundleWithPath:[[NSString stringWithUTF8String:path] stringByDeletingLastPathComponent]];
		if (bundle) {
			if (bundleIdentifier) {
				*bundleIdentifier = [bundle bundleIdentifier];
			}
			if (displayName) {
				NSString *result = [bundle objectForInfoDictionaryKey:@"CFBundleDisplayName"];
				if (!result) {
					result = [bundle objectForInfoDictionaryKey:@"CFBundleName"];
					if (!result) {
						result = [bundle bundleIdentifier];
					}
				}
				*displayName = result;
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

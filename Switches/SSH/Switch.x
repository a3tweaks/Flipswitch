#import "FSSwitchDataSource.h"
#import "FSSwitchPanel.h"


@interface SSHSwitch : NSObject <FSSwitchDataSource>
@end


@implementation SSHSwitch

- (BOOL)shouldShowSwitchIdentifier:(NSString *)switchIdentifier
{
    return [[NSFileManager defaultManager] fileExistsAtPath:@"/Library/LaunchDaemons/com.openssh.sshd.plist"];
}

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	int pid = fork();
    if (pid < 0) {
        NSLog(@"%@", @"Flipswitch SSH Switch Fork Error");
        exit(0);
    } else if (pid == 0) {
        execl("/bin/sh", "sh", "-c", "/bin/launchctl list | grep -q com.openssh.sshd && echo \"1\" > /var/tmp/sshstate || echo \"0\" > /var/tmp/sshstate", NULL);
        _exit(0);
    } else {
        waitpid(pid, NULL, 0);
    }
    
    if ([[NSString stringWithContentsOfFile:@"/var/tmp/sshstate" encoding:NSUTF8StringEncoding error:nil] intValue] == 1) {
        return FSSwitchStateOn;
    }
    return FSSwitchStateOff;
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (newState == FSSwitchStateIndeterminate)
		return;
    
    NSString *command = [NSString stringWithFormat:@"/Library/Switches/SSH.bundle/%@", newState==FSSwitchStateOn? @"enable" : @"disable"];
    
    int pid = fork();
    if (pid < 0) {
        NSLog(@"%@", @"Flipswitch SSH Switch Fork Error");
        exit(0);
    } else if (pid == 0) {
        execl("/Library/Switches/SSH.bundle/feedMe", "feedMe", [command UTF8String], NULL);
        _exit(0);
    } else {
        waitpid(pid, NULL, 0);
    }
}

- (NSString *)titleForSwitchIdentifier:(NSString *)switchIdentifier
{
    return @"SSH";
}

@end
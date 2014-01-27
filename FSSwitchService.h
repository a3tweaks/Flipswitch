#define kFSSwitchServiceName "a3api.switchcomm"

typedef enum {
	FSSwitchServiceMessageGetIdentifiers = 0,
	FSSwitchServiceMessageGetTitleForIdentifier = 1,
	FSSwitchServiceMessageGetStateForIdentifier = 2,
	FSSwitchServiceMessageSetStateForIdentifier = 3,
	FSSwitchServiceMessageGetImageDescriptorForSwitch = 4,
	FSSwitchServiceMessageApplyActionForIdentifier = 5,
	FSSwitchServiceMessageHasAlternateActionForIdentifier = 6,
	FSSwitchServiceMessageApplyAlternateActionForIdentifier = 7,
	FSSwitchServiceMessageGetPendingNotificationUserInfo = 8,
	FSSwitchServiceMessageGetEnabledForIdentifier = 9,
	FSSwitchServiceMessageBeginPrewarmingForIdentifier = 10,
	FSSwitchServiceMessageCancelPrewarmingForIdentifier = 11,
	FSSwitchServiceMessageOpenURLAsAlternateAction = 12,
} FSSwitchServiceMessage;

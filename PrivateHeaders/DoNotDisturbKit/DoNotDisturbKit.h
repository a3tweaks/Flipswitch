#import <Foundation/Foundation.h>

@interface DNDState : NSObject
@property (getter=isActive, nonatomic, readonly) BOOL active;
@property (nonatomic, copy, readonly) NSArray *activeModeIdentifiers; 
@property (nonatomic, readonly) BOOL willSuppressInterruptions;
@property (nonatomic, copy, readonly) NSArray *activeModeAssertionMetadata;
@end

@class DNDStateService;

@protocol DNDStateUpdateListener <NSObject>
@required
- (void)stateService:(DNDStateService *)stateService didReceiveDoNotDisturbStateUpdate:(DNDState *)state;
@end

@interface DNDStateService : NSObject 
@property (nonatomic, copy, readonly) NSString *clientIdentifier;
+ (DNDStateService *)serviceForClientIdentifier:(NSString *)clientIdentifier;
- (DNDState *)queryCurrentStateWithError:(NSError **)error;
- (BOOL)addStateUpdateListener:(id<DNDStateUpdateListener>)listener error:(NSError **)error;
- (BOOL)removeStateUpdateListener:(id<DNDStateUpdateListener>)listener error:(NSError **)error;
@end

@class DNDModeAssertionLifetime;

@interface DNDModeAssertionDetails : NSObject
+ (id)userRequestedAssertionDetailsWithIdentifier:(NSString *)identifier modeIdentifier:(NSString *)modeIdentifier lifetime:(DNDModeAssertionLifetime *)lifetime;
@end

@interface DNDModeAssertionService : NSObject
+ (id)serviceForClientIdentifier:(NSString *)clientIdentifier;
- (BOOL)invalidateAllActiveModeAssertionsWithError:(NSError **)error;
- (id)takeModeAssertionWithDetails:(DNDModeAssertionDetails *)assertionDetails error:(NSError **)error;
@end

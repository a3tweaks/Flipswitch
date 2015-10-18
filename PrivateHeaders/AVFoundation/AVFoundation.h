#include_next <AVFoundation/AVFoundation.h>

@interface AVFlashlight : NSObject

+ (BOOL)hasFlashlight;

@property(readonly, nonatomic) float flashlightLevel;
- (BOOL)setFlashlightLevel:(float)level withError:(NSError **)error;

- (void)turnPowerOff;
- (BOOL)turnPowerOnWithError:(NSError **)error;
@property(readonly, nonatomic, getter=isOverheated) BOOL overheated;
@property(readonly, nonatomic, getter=isAvailable) BOOL available;

- (void)teardownFigRecorder;
- (BOOL)ensureFigRecorderWithError:(NSError **)error;
- (BOOL)bringupFigRecorderWithError:(NSError **)error;

@end


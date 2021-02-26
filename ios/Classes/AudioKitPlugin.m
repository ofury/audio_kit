#import "AudioKitPlugin.h"
#if __has_include(<audio_kit/audio_kit-Swift.h>)
#import <audio_kit/audio_kit-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "audio_kit-Swift.h"
#endif

@implementation AudioKitPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftAudioKitPlugin registerWithRegistrar:registrar];
}
@end

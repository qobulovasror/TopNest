#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include "TopNestMediaBridge.h"

typedef void (*GetInfoFn)(dispatch_queue_t, void (^)(CFDictionaryRef));
typedef void (*GetBoolFn)(dispatch_queue_t, void (^)(Boolean));
typedef void (*GetPIDFn)(dispatch_queue_t, void (^)(int));
typedef void (*RegisterFn)(dispatch_queue_t);
typedef Boolean (*SendCommandFn)(int, CFDictionaryRef);
typedef void (*SetElapsedFn)(double);

static void *framework(void) {
    static void *handle;
    if (!handle) handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW);
    return handle;
}

static uint64_t emitSequence;
static NSUInteger lastArtworkLength;
static NSString *lastArtworkKey;

// JSON NaN/cheksiz sonni qabul qilmaydi (jonli efir davomiyligi): faqat chekli qiymatlar yoziladi.
static void putNumber(NSMutableDictionary *out, NSString *key, id value) {
    if ([value isKindOfClass:[NSNumber class]] && isfinite([(NSNumber *)value doubleValue])) out[key] = value;
}

// Har o'zgarishda bitta JSON qator chiqariladi; TopNest uni stdout orqali o'qiydi.
static void emit(void) {
    uint64_t sequence = ++emitSequence;
    void *h = framework();
    GetInfoFn getInfo = (GetInfoFn)dlsym(h, "MRMediaRemoteGetNowPlayingInfo");
    GetBoolFn isPlaying = (GetBoolFn)dlsym(h, "MRMediaRemoteGetNowPlayingApplicationIsPlaying");
    GetPIDFn getPID = (GetPIDFn)dlsym(h, "MRMediaRemoteGetNowPlayingApplicationPID");
    if (!getInfo || !isPlaying || !getPID) return;
    dispatch_queue_t queue = dispatch_get_main_queue();
    getInfo(queue, ^(CFDictionaryRef raw) {
        NSDictionary *info = (__bridge NSDictionary *)raw;
        isPlaying(queue, ^(Boolean playing) {
            getPID(queue, ^(int pid) {
                // Keyinroq boshlangan emit bo'lsa, eski ma'lumot oxirgi bo'lib chiqmasin.
                if (sequence != emitSequence) return;
                NSMutableDictionary *out = [NSMutableDictionary dictionary];
                out[@"playing"] = @(playing);
                out[@"pid"] = @(pid);
                NSString *bundle = [NSRunningApplication runningApplicationWithProcessIdentifier:pid].bundleIdentifier;
                if (bundle) out[@"bundle"] = bundle;
                id title = info[@"kMRMediaRemoteNowPlayingInfoTitle"];
                if ([title isKindOfClass:[NSString class]]) out[@"title"] = title;
                id artist = info[@"kMRMediaRemoteNowPlayingInfoArtist"];
                if ([artist isKindOfClass:[NSString class]]) out[@"artist"] = artist;
                id album = info[@"kMRMediaRemoteNowPlayingInfoAlbum"];
                if ([album isKindOfClass:[NSString class]]) out[@"album"] = album;
                putNumber(out, @"duration", info[@"kMRMediaRemoteNowPlayingInfoDuration"]);
                putNumber(out, @"elapsed", info[@"kMRMediaRemoteNowPlayingInfoElapsedTime"]);
                putNumber(out, @"rate", info[@"kMRMediaRemoteNowPlayingInfoPlaybackRate"]);
                id stamp = info[@"kMRMediaRemoteNowPlayingInfoTimestamp"];
                if ([stamp isKindOfClass:[NSDate class]]) putNumber(out, @"timestamp", @([(NSDate *)stamp timeIntervalSince1970]));
                // Rasm faqat o'zgarganda yuboriladi; TopNest shu trek uchun oldingisini saqlab turadi.
                // Kalit TopNest'dagi bilan bir xil (nom + ijrochi); rasm yo'q xabarda holat tozalanadi.
                id artwork = info[@"kMRMediaRemoteNowPlayingInfoArtworkData"];
                NSString *key = [NSString stringWithFormat:@"%@\n%@", out[@"title"] ?: @"", out[@"artist"] ?: @""];
                if ([artwork isKindOfClass:[NSData class]] && [(NSData *)artwork length] < 4 * 1024 * 1024 && out[@"title"]) {
                    NSData *data = artwork;
                    if (data.length != lastArtworkLength || ![key isEqualToString:lastArtworkKey ?: @""]) {
                        out[@"artwork"] = [data base64EncodedStringWithOptions:0];
                        lastArtworkLength = data.length;
                        lastArtworkKey = key;
                    }
                } else {
                    lastArtworkLength = 0;
                    lastArtworkKey = nil;
                }
                if (![NSJSONSerialization isValidJSONObject:out]) return;
                NSData *json = [NSJSONSerialization dataWithJSONObject:out options:0 error:nil];
                if (json) {
                    fwrite(json.bytes, 1, json.length, stdout);
                    fputc('\n', stdout);
                    fflush(stdout);
                }
            });
        });
    });
}

// Bildirishnomalar odatda to'da keladi: 120 ms ichidagilari bitta emit'ga birlashtiriladi.
static void scheduleEmit(void) {
    static BOOL pending;
    if (pending) return;
    pending = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 120 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        pending = NO;
        emit();
    });
}

void tn_stream(void *interpreter, void *cv) {
    @autoreleasepool {
        void *h = framework();
        RegisterFn registerFn = (RegisterFn)dlsym(h, "MRMediaRemoteRegisterForNowPlayingNotifications");
        if (!registerFn) exit(2);
        registerFn(dispatch_get_main_queue());
        NSArray *names = @[@"kMRMediaRemoteNowPlayingInfoDidChangeNotification",
                           @"kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
                           @"kMRMediaRemoteNowPlayingApplicationDidChangeNotification"];
        for (NSString *name in names) {
            [[NSNotificationCenter defaultCenter] addObserverForName:name object:nil queue:[NSOperationQueue mainQueue]
                                                          usingBlock:^(NSNotification *note) { scheduleEmit(); }];
        }
        emit();
        // TopNest yopilsa stdin yopiladi: shunda yordamchi ham to'xtaydi.
        dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, STDIN_FILENO, 0, dispatch_get_main_queue());
        dispatch_source_set_event_handler(source, ^{
            char buffer[64];
            if (read(STDIN_FILENO, buffer, sizeof buffer) <= 0) exit(0);
        });
        dispatch_resume(source);
        CFRunLoopRun();
    }
}

// TN_COMMAND: MediaRemote buyruq raqami; TN_SEEK_MS: millisekunddagi pozitsiya (lokalga bog'liq emas).
void tn_command(void *interpreter, void *cv) {
    @autoreleasepool {
        void *h = framework();
        const char *seek = getenv("TN_SEEK_MS");
        if (seek) {
            SetElapsedFn setElapsed = (SetElapsedFn)dlsym(h, "MRMediaRemoteSetElapsedTime");
            if (setElapsed) setElapsed((double)strtoll(seek, NULL, 10) / 1000.0);
        }
        const char *command = getenv("TN_COMMAND");
        if (command) {
            SendCommandFn send = (SendCommandFn)dlsym(h, "MRMediaRemoteSendCommand");
            if (send) send(atoi(command), NULL);
        }
        // Buyruq asinxron yuboriladi; jarayon darhol tugasa yo'qolishi mumkin.
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.3, false);
    }
}

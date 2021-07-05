#import <ApplicationServices/ApplicationServices.h>
#import <AppKit/NSRunningApplication.h>
#import <AppKit/NSWorkspace.h>

#define SIGN(x) (((x) > 0) - ((x) < 0))

#define DEFAULT_LINES 3

static NSDictionary<NSString *, NSNumber *> *linesForApplications;
static NSWorkspace *workspace;
static pid_t lastProcess = 0;
static int64_t lastLines;

CGEventRef
cgEventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    if (CGEventGetIntegerValueField(event, kCGScrollWheelEventIsContinuous)) {
        return event;
    }

    NSRunningApplication* app = [workspace frontmostApplication];
    if (app == NULL) {
        return event;
    }

    pid_t pid = [app processIdentifier];

    if (lastProcess != pid) {
        lastProcess = pid;
        NSString *bid = [app bundleIdentifier];
        //NSLog(@"%@", bid);
        NSNumber *lines = linesForApplications[bid];
        lastLines = lines ? [lines longLongValue] : DEFAULT_LINES;
    };

    int64_t delta = CGEventGetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1);
    int64_t newDelta = SIGN(delta) * lastLines;

    CGEventSetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1, newDelta);

    return event;
}

int
main(void) {
    workspace = [NSWorkspace sharedWorkspace];

    linesForApplications = @{
                   @"com.apple.dt.Xcode" : @5,  /* About 3 lines on Big Sur. */
                  @"org.mozilla.firefox" : @7,  /* Match the scroll speed on Chrome and Safari. */
        @"com.parallels.desktop.console" : @1,  /* The VM will do its own multiplication. */
    };

    CFMachPortRef eventTap;
    CFRunLoopSourceRef runLoopSource;

    eventTap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, 0,
                                1 << kCGEventScrollWheel, cgEventCallback, NULL);
    runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
    
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
    CGEventTapEnable(eventTap, true);
    CFRunLoopRun();

    CFRelease(eventTap);
    CFRelease(runLoopSource);

    return 0;
}

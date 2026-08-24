#import <UIKit/UIKit.h>
#include <sys/stat.h>
#include <stdio.h>

#define NOSEP_LOG_PATH "/var/mobile/nosep_debug.log"

static void nosepLog(NSString *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);

    FILE *f = fopen(NOSEP_LOG_PATH, "a");
    if (f) {
        fprintf(f, "%s\n", [msg UTF8String]);
        fclose(f);
        chmod(NOSEP_LOG_PATH, 0666);
    }
}

// Minimal forward declaration — PSSpecifier is a private Preferences.framework
// class, but `identifier` and `name` are its standard accessors across iOS 15.x.
@interface PSSpecifier : NSObject
- (NSString *)identifier;
- (NSString *)name;
@end

@interface PSListController : UIViewController
- (NSMutableArray *)specifiers;
- (PSSpecifier *)specifierForID:(NSString *)specifierID;
- (void)removeSpecifier:(PSSpecifier *)specifier animated:(BOOL)animated;
@end

@interface PSUIPrefsListController : PSListController
@end

// Matches on identifier / class-name / title substrings rather than one
// exact private string, since Apple's naming can shift between iOS 15.x
// point releases and can't be verified without the live binary.
static NSArray *matchKeywords() {
    static NSArray *keywords = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        keywords = @[@"PASSCODE", @"FACEID", @"FACE ID", @"TOUCHID", @"TOUCH ID", @"BIOMETRIC"];
    });
    return keywords;
}

static BOOL stringMatchesKeywords(NSString *s) {
    if (s.length == 0) return NO;
    for (NSString *kw in matchKeywords()) {
        if ([s rangeOfString:kw options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return YES;
        }
    }
    return NO;
}

static BOOL isSensitiveController(UIViewController *vc) {
    return stringMatchesKeywords(NSStringFromClass([vc class]));
}

// --- Primary: strip the "Face ID & Passcode" / "Touch ID & Passcode" row
// out of Settings entirely, so there's nothing to tap. ---
//
// The list-controller base class name has varied across iOS/Preferences.framework
// versions (PSListController vs PSUIPrefsListController on 15.4.1) — hook both,
// Logos silently no-ops a %hook whose target class doesn't exist at runtime.
static NSMutableArray *nosepFilterSpecifiers(id self, NSMutableArray *orig) {
    nosepLog(@"[specifiers] %@ called, count=%lu",
             NSStringFromClass([self class]), (unsigned long)orig.count);

    if (!orig) return orig;

    NSMutableArray *filtered = [NSMutableArray arrayWithCapacity:orig.count];
    for (PSSpecifier *specifier in orig) {
        NSString *identifier = @"";
        NSString *name = @"";
        @try {
            identifier = [specifier identifier] ?: @"";
            name = [specifier name] ?: @"";
        } @catch (...) {}

        nosepLog(@"  specifier id=%@ name=%@", identifier, name);

        if (stringMatchesKeywords(identifier) || stringMatchesKeywords(name)) {
            nosepLog(@"  -> DROPPED (matched keyword)");
            continue; // drop this row
        }
        [filtered addObject:specifier];
    }
    return filtered;
}

// PSUIPrefsListController's -specifiers is a cache accessor: overriding what
// it *returns* doesn't rebuild the already-populated table. Actively removing
// the specifier via -removeSpecifier:animated: (the API PSListController's own
// row-hiding uses internally) does.
static void nosepRemoveSensitiveSpecifiers(id self) {
    NSMutableArray *current = [[self specifiers] copy];
    for (PSSpecifier *specifier in current) {
        NSString *identifier = @"";
        NSString *name = @"";
        @try {
            identifier = [specifier identifier] ?: @"";
            name = [specifier name] ?: @"";
        } @catch (...) {}

        if (stringMatchesKeywords(identifier) || stringMatchesKeywords(name)) {
            nosepLog(@"[removeSpecifier] removing id=%@ name=%@ from %@",
                     identifier, name, NSStringFromClass([self class]));
            [self removeSpecifier:specifier animated:NO];
        }
    }
}

%hook PSListController
- (NSMutableArray *)specifiers {
    NSMutableArray *orig = %orig;
    return nosepFilterSpecifiers(self, orig);
}
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    nosepRemoveSensitiveSpecifiers(self);
}
%end

%hook PSUIPrefsListController
- (NSMutableArray *)specifiers {
    NSMutableArray *orig = %orig;
    return nosepFilterSpecifiers(self, orig);
}
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    nosepRemoveSensitiveSpecifiers(self);
}
%end

// --- Safety net: if the page is still reached some other way (a
// prefs:root=... deep link from another app, Setup Assistant, etc.),
// silently back out before any passcode/biometric action can complete. ---
%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;

    nosepLog(@"[viewDidAppear] %@ (proc=%@)", NSStringFromClass([self class]), [[NSProcessInfo processInfo] processName]);

    if (isSensitiveController(self)) {
        nosepLog(@"  -> MATCHED, dismissing");
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.navigationController && self.navigationController.viewControllers.count > 1) {
                [self.navigationController popViewControllerAnimated:NO];
            } else if (self.presentingViewController) {
                [self dismissViewControllerAnimated:NO completion:nil];
            }
        });
    }
}

%end

%ctor {
    nosepLog(@"=== NoSEPBootloop loaded in process %@ ===",
             [[NSProcessInfo processInfo] processName]);
}

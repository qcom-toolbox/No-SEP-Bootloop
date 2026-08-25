# No SEP Bootloop

A Theos-based iOS tweak (jailbreak) that removes the "Face ID & Passcode" / "Touch ID &
Passcode" entry from Settings entirely, and blocks any passcode/biometric enrollment screen
if reached another way (e.g. a `prefs:root=...` deep link). Intended to prevent SEP/AP
desync bootloops that can occur on some jailbroken devices when a passcode or Face ID/Touch ID
is set up post-jailbreak.

Targets all SEP-equipped devices (iPhone 5s / A7 onward) across iOS 12 through current
releases. See [Version coverage](#version-coverage) below for how that's achieved and its
real limits.

# Disclamer
By using No SEP Bootloop, you accept full responsibility for whatever happens to your device.
I am not responsible for: bricked devices, missing recovery partitions, dead Apple  ̶x̶i̶a̶o̶m̶i̶ factoryline  ̶w̶o̶r̶k̶e̶r̶s̶ cowboys, dead pmics, data loss, dead SD cards, dead ram, dead sim cards, dead display ics, dead cpus, any Apple shenanigans, exploding batteries, dead cats, dogs, goldfish, nuclear war, you getting fired because you the tweak somehow tweaked your alarm. Also not responsible for sleepless nights, marriage crises, or general existential dread.

## How it works

- Hooks `PSListController`, `PSUIPrefsListController`, and `PSUIPrefsRootController`
  (Preferences.framework's Settings list controllers — the exact class used has changed across
  iOS/Preferences.framework versions) and calls `removeSpecifier:animated:` in both
  `viewDidLoad` and `viewWillAppear:` to strip any row whose specifier `identifier` or `name`
  matches "Passcode", "Face ID", "Touch ID", or "Biometric". Logos silently no-ops a `%hook`
  whose target class doesn't exist at runtime, so hooking multiple candidate classes is safe
  even on iOS versions where only some of them exist.
- As a fallback, hooks `UIViewController`'s `viewDidAppear:` globally within SpringBoard and
  Preferences, and silently dismisses/pops any view controller whose class name matches those
  same keywords — in case the settings page is reached some other way, or the list-controller
  hooks above don't apply on a given iOS version.

## Version coverage

- **Deployment target:** iOS 12.0, `arm64` + `arm64e`, so the package installs on anything
  from the iPhone 5s/6 generation through current arm64e devices.
- **Verified:** iOS 15.4.1 (rootless, Dopamine) — confirmed the row disappears and the
  fallback dismiss fires correctly.
- **Best-effort, unverified:** everything else. The multi-class + keyword-substring approach
  is deliberately version-resilient (it doesn't depend on one exact private class or string),
  but Apple has reworked Settings' internals before and may again — if a future iOS version
  moves off this `PSSpecifier`/`PSListController`-based architecture entirely (e.g. a SwiftUI
  rewrite), these hooks could stop matching anything. If the row doesn't disappear on your
  iOS version, see [Debugging](#debugging) below — the fix so far, each time this has come up,
  has been adding one more class name or keyword to match what that OS version actually uses.

## Building

Requires [Theos](https://theos.dev).

```bash
export THEOS=~/theos
./build.sh
```

Produces two files in `packages/`:
- `..._rootful.deb` — classic `/Library/MobileSubstrate/DynamicLibraries` layout, for
  checkra1n, unc0ver, Taurine, Odyssey, Chimera, palera1n "rootful" mode, and other iOS
  12–16-era jailbreaks.
- `..._rootless.deb` — `/var/jb`-prefixed layout, for Dopamine and palera1n rootless mode.

Install whichever one matches your jailbreak — they are not interchangeable.

## Installing

```bash
scp packages/com.qcom-toolbox.no-sep-bootloop_*-rootless.deb root@<device-ip>:/var/mobile/
ssh root@<device-ip>
dpkg -i /var/mobile/com.qcom-toolbox.no-sep-bootloop_*-rootless.deb
killall -9 SpringBoard
```

(swap `-rootless.deb` for `-rootful.deb` if that's what your jailbreak needs)

## Debugging

The tweak logs to `/var/mobile/nosep_debug.log` — useful if the row isn't disappearing on
your iOS version. It logs every list-controller `specifiers` call (with each row's
`identifier`/`name`) and every `viewDidAppear:` it sees, so you can find the actual class name
and specifier `identifier` your iOS version uses and add it to the keyword list / hooked
classes in `Tweak.xm` if it's not already covered.

```bash
rm -f /var/mobile/nosep_debug.log
# reproduce: open Settings, scroll to the row, tap it, go back
cat /var/mobile/nosep_debug.log
```

## Caveats

- This is a UI-layer mitigation, not a kernel/SEP-layer fix. It does not repair the underlying
  SEP/AP desync bug itself.
- Private class/method names (`PSListController`, `PSUIPrefsListController`,
  `PSUIPrefsRootController`, `specifierForID:`, `removeSpecifier:animated:`) are Apple internals,
  not a stable public API — they can change in any iOS release.

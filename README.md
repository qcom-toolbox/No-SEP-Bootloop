# No SEP Bootloop

A Theos-based iOS tweak (jailbreak, MobileSubstrate/rootless-compatible) that removes the
"Face ID & Passcode" / "Touch ID & Passcode" entry from Settings entirely, and blocks any
passcode/biometric enrollment screen if reached another way (e.g. a `prefs:root=...` deep
link). Intended to prevent SEP/AP desync bootloops that can occur on some jailbroken devices
when a passcode or Face ID/Touch ID is set up post-jailbreak.

## How it works

- Hooks `PSListController` / `PSUIPrefsListController` (Preferences.framework's Settings list
  controllers — the class name differs across iOS/Preferences.framework versions) and calls
  `removeSpecifier:animated:` in `viewWillAppear:` to strip any row whose specifier `identifier`
  or `name` matches "Passcode", "Face ID", "Touch ID", or "Biometric".
- As a fallback, hooks `UIViewController`'s `viewDidAppear:` globally within SpringBoard and
  Preferences, and silently dismisses/pops any view controller whose class name matches those
  same keywords — in case the settings page is reached some other way.

## Building

Requires [Theos](https://theos.dev).

```bash
export THEOS=~/theos
make package
```

Produces a `.deb` in `packages/`.

## Installing

```bash
scp packages/com.qcom-toolbox.no-sep-bootloop_*.deb root@<device-ip>:/var/mobile/
ssh root@<device-ip>
dpkg -i /var/mobile/com.qcom-toolbox.no-sep-bootloop_*.deb
killall -9 SpringBoard
```

Rootless jailbreaks (Dopamine, palera1n rootless) are supported via
`THEOS_PACKAGE_SCHEME = rootless` in the Makefile.

## Caveats

- Private class/method names (`PSListController`, `PSUIPrefsListController`,
  `specifierForID:`, `removeSpecifier:animated:`) are not guaranteed stable across all iOS 15.x
  point releases. This has been confirmed working against iOS 15.4.1. Other versions may need
  the keyword list or hooked class names adjusted.
- This is a UI-layer mitigation, not a kernel/SEP-layer fix. It does not repair the underlying
  SEP/AP desync bug itself.

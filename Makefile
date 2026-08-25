ARCHS = arm64 arm64e
TARGET := iphone:clang:16.5:12.0
# THEOS_PACKAGE_SCHEME is intentionally not hardcoded here — see build.sh,
# which builds both a rootful (classic /Library/MobileSubstrate) package for
# iOS 12–16-era jailbreaks and a rootless (/var/jb) package for Dopamine /
# palera1n rootless, since a single .deb can't target both layouts.

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = NoSEPBootloop

NoSEPBootloop_FILES = Tweak.xm
NoSEPBootloop_CFLAGS = -fobjc-arc
NoSEPBootloop_FRAMEWORKS = UIKit

include $(THEOS_MAKE_PATH)/tweak.mk

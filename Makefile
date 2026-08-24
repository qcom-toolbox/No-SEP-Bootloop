ARCHS = arm64 arm64e
TARGET := iphone:clang:16.5:15.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = NoSEPBootloop

NoSEPBootloop_FILES = Tweak.xm
NoSEPBootloop_CFLAGS = -fobjc-arc
NoSEPBootloop_FRAMEWORKS = UIKit

include $(THEOS_MAKE_PATH)/tweak.mk

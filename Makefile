PACKAGE_VERSION = $(THEOS_PACKAGE_BASE_VERSION)
ARCHS = arm64
TARGET = iphone:clang:latest:14.0
THEOS_PACKAGE_SCHEME = rootless
THEOS_DEVICE_IP = 192.168.3.144

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = UIStatusBar
$(TWEAK_NAME)_FILES = Tweak.xm
$(TWEAK_NAME)_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

BUNDLE_NAME = uipre

$(BUNDLE_NAME)_FILES = PreferencesUI/ptrfixRootListController.m
$(BUNDLE_NAME)_FRAMEWORKS = UIKit 
$(BUNDLE_NAME)_PRIVATE_FRAMEWORKS = Preferences
$(BUNDLE_NAME)_INSTALL_PATH = /Library/PreferenceBundles
uipre_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
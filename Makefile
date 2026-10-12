TARGET := iphone:clang:latest:14.0
ARCHS = arm64 arm64e
# 越狱默认用 ellekit/theos; TrollStore 走静态注入见 README
INSTALL_TARGET_PROCESSES = Remini

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ReminiPro
ReminiPro_FILES = Tweak.x
ReminiPro_CFLAGS = -fobjc-arc -Wno-unused-function
# ellekit 提供 MSHookFunction; 若用 Substrate 改 -lsubstrate
ReminiPro_LIBRARIES = ellekit

include $(THEOS)/makefiles/tweak.mk

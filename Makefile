# Universal (Intel + Apple Silicon) by default.
# Intel only: make ARCHS=x86_64
# Apple Silicon only: make ARCHS=arm64
ARCHS ?= arm64 x86_64
ARCH_FLAGS = $(foreach arch,$(ARCHS),--arch $(arch))
SWIFT_BUILD = swift build -c release --product Overwatch $(ARCH_FLAGS)
APP = Overwatch.app
BUILD_BIN = .build/release/Overwatch

.PHONY: all build app run clean icon

all: app

build:
	$(SWIFT_BUILD)

icon:
	swift Scripts/GenerateIcon.swift

app: build icon
	bash Scripts/package-app.sh

run: app
	open "$(APP)"

clean:
	rm -rf .build "$(APP)" Resources/AppIcon.icns Resources/AppIcon.png

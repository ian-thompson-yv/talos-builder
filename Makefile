PKG_VERSION = v1.11.0
TALOS_VERSION = v1.11.5
SBCOVERLAY_VERSION = main

PUSH ?= true
REGISTRY ?= autinf-registry-dev.dev.youview.co.uk

ifndef RPI_MODEL
$(error RPI_MODEL is required but not set, ie rpi5 or rpi4)
endif
REGISTRY_USERNAME := talos-$(RPI_MODEL)
TAG ?= $(shell git describe --tags --exact-match)

SED ?= sed

ASSET_TYPE ?= installer
CONFIG_TXT = dtparam=i2c_arm=on

PKG_REPOSITORY = https://github.com/siderolabs/pkgs.git
TALOS_REPOSITORY = https://github.com/siderolabs/talos.git
SBCOVERLAY_REPOSITORY = https://github.com/talos-rpi5/sbc-raspberrypi5.git

CHECKOUTS_DIRECTORY := $(PWD)/checkouts
PATCHES_DIRECTORY := $(PWD)/patches

#
# Help
#
.PHONY: help
help:
	@echo "checkouts : Clone repositories required for the build"
	@echo "patches   : Apply all patches"
	@echo "kernel    : Build kernel"
	@echo "overlay   : Build Raspberry Pi 5 overlay"
	@echo "installer : Build installer docker image and disk image"
	@echo "release   : Use only when building the final release, this will tag relevant images with the current Git tag."
	@echo "clean     : Clean up any remains"

#
# Checkouts
#
.PHONY: checkouts checkouts-clean
checkouts:
	git clone -c advice.detachedHead=false --branch "$(PKG_VERSION)" "$(PKG_REPOSITORY)" "$(CHECKOUTS_DIRECTORY)/pkgs"
	git clone -c advice.detachedHead=false --branch "$(TALOS_VERSION)" "$(TALOS_REPOSITORY)" "$(CHECKOUTS_DIRECTORY)/talos"
	git clone -c advice.detachedHead=false --branch "$(SBCOVERLAY_VERSION)" "$(SBCOVERLAY_REPOSITORY)" "$(CHECKOUTS_DIRECTORY)/sbc-raspberrypi5"

checkouts-clean:
	rm -rf "$(CHECKOUTS_DIRECTORY)/pkgs"
	rm -rf "$(CHECKOUTS_DIRECTORY)/talos"
	rm -rf "$(CHECKOUTS_DIRECTORY)/sbc-raspberrypi5"



#
# Patches
#
.PHONY: patches-pkgs patches-talos patches patches-pkgs-4 patches-pi4
patches-pkgs:
	cd "$(CHECKOUTS_DIRECTORY)/pkgs" && \
		git am "$(PATCHES_DIRECTORY)/siderolabs/pkgs/0001-Patched-for-Raspberry-Pi-5.patch"
	cd "$(CHECKOUTS_DIRECTORY)/pkgs" && \
		git apply $(PATCHES_DIRECTORY)/siderolabs/pkgs/0003-nf-bridge.patch

patches-talos:
	cd "$(CHECKOUTS_DIRECTORY)/talos" && \
		git am "$(PATCHES_DIRECTORY)/siderolabs/talos/0001-Patched-for-Raspberry-Pi-5.patch"
	cd "$(CHECKOUTS_DIRECTORY)/talos" && \
		git apply "$(PATCHES_DIRECTORY)/siderolabs/talos/0002-Makefile.patch"

patches-pi5: patches-pkgs patches-talos

patches-pkgs-4:
	cd "$(CHECKOUTS_DIRECTORY)/pkgs" && \
		git apply "$(PATCHES_DIRECTORY)/siderolabs/pkgs/0002-Patched-for-Raspberry-Pi-4.patch"

patches-pi4: patches-pkgs patches-pkgs-4 patches-talos

#
# Kernel
#
.PHONY: kernel
kernel:
	cd "$(CHECKOUTS_DIRECTORY)/pkgs" && \
		$(MAKE) \
			REGISTRY=$(REGISTRY) USERNAME=$(REGISTRY_USERNAME) PUSH=$(PUSH) \
			PLATFORM=linux/arm64 TAG=$(TAG)\
			kernel

#
# Overlay
#
.PHONY: overlay
overlay:
	cd "$(CHECKOUTS_DIRECTORY)/sbc-raspberrypi5" && \
		$(MAKE) \
			REGISTRY=$(REGISTRY) USERNAME=$(REGISTRY_USERNAME) IMAGE_TAG=$(TAG) PUSH=$(PUSH) \
			PKGS_PREFIX=$(REGISTRY)/$(REGISTRY_USERNAME) PKGS=$(TAG) \
			INSTALLER_ARCH=arm64 PLATFORM=linux/arm64 \
			sbc-raspberrypi5

.PHONY: imager
imager:
	cd "$(CHECKOUTS_DIRECTORY)/talos" && \
		$(MAKE) \
			REGISTRY=$(REGISTRY) USERNAME=$(REGISTRY_USERNAME) PUSH=$(PUSH) \
			PKG_KERNEL=$(REGISTRY)/$(REGISTRY_USERNAME)/kernel:$(TAG) \
			INSTALLER_ARCH=arm64 PLATFORM=linux/arm64 SED=$(SED) IMAGE_TAG=$(TAG) \
			imager

.PHONY: installer-base
installer-base:
	cd "$(CHECKOUTS_DIRECTORY)/talos" && \
		$(MAKE) \
			REGISTRY=$(REGISTRY) USERNAME=$(REGISTRY_USERNAME) PUSH=$(PUSH) \
			PKG_KERNEL=$(REGISTRY)/$(REGISTRY_USERNAME)/kernel:$(TAG) \
			INSTALLER_ARCH=arm64 PLATFORM=linux/arm64 SED=$(SED) IMAGE_TAG=$(TAG) \
			installer-base

.PHONY: kern_initramfs
kern_initramfs:
	cd "$(CHECKOUTS_DIRECTORY)/talos" && \
		$(MAKE) \
			REGISTRY=$(REGISTRY) USERNAME=$(REGISTRY_USERNAME) PUSH=$(PUSH) \
			PKG_KERNEL=$(REGISTRY)/$(REGISTRY_USERNAME)/kernel:$(TAG) \
			INSTALLER_ARCH=arm64 PLATFORM=linux/arm64 SED=$(SED) \
			kernel initramfs


#
# Installer/Image
#

.PHONY: installer-pi5
installer-pi5:
	cd "$(CHECKOUTS_DIRECTORY)/talos" && \
		docker \
			run --rm -t -v ./_out:/out -v /dev:/dev --privileged $(REGISTRY)/$(REGISTRY_USERNAME)/imager:$(TAG) \
			$(ASSET_TYPE) --arch arm64 \
			--base-installer-image="$(REGISTRY)/$(REGISTRY_USERNAME)/installer-base:$(TAG)" \
			--overlay-name="rpi5" \
			--overlay-image="$(REGISTRY)/$(REGISTRY_USERNAME)/sbc-raspberrypi5:$(TAG)" \
    		--system-extension-image autinf-registry-dev.dev.youview.co.uk/autinf/talos/yvrig-control:universal


.PHONY: installer-pi4
installer-pi4:
	cd "$(CHECKOUTS_DIRECTORY)/talos" && \
		docker \
			run --rm -t -v ./_out:/out -v /dev:/dev --privileged $(REGISTRY)/$(REGISTRY_USERNAME)/imager:$(TAG) \
			$(ASSET_TYPE) --arch arm64 \
			--base-installer-image="$(REGISTRY)/$(REGISTRY_USERNAME)/installer-base:$(TAG)" \
			--overlay-name="rpi_generic" \
			--overlay-image="autinf-registry-dev.dev.youview.co.uk/siderolabs/sbc-raspberrypi:v0.1.5" \
			--overlay-option="configTxtAppend=$(CONFIG_TXT)" \
			--system-extension-image autinf-registry-dev.dev.youview.co.uk/autinf/talos/yvrig-control:universal

#
# Release
#
.PHONY: release
release:
	docker pull $(REGISTRY)/$(REGISTRY_USERNAME)/installer:$(TAG) && \
		docker tag $(REGISTRY)/$(REGISTRY_USERNAME)/installer:$(TAG) $(REGISTRY)/$(REGISTRY_USERNAME)/installer:$(TAG) && \
		docker push $(REGISTRY)/$(REGISTRY_USERNAME)/installer:$(TAG)



.PHONY: pi5
pi5: checkouts-clean checkouts patches-pi5 kernel kern_initramfs installer-base imager overlay

.PHONY: pi4
pi4: checkouts-clean checkouts patches-pi4 kernel kern_initramfs installer-base imager

#
# Clean
#
.PHONY: clean
clean: checkouts-clean

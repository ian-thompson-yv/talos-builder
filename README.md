# Raspberry Pi 5 Talos Builder
This repository serves as the glue to build custom Talos images for the Raspberry Pi 5. It patches the Kernel and Talos build process to use the Linux Kernel source provided by [raspberrypi/linux](https://github.com/raspberrypi/linux).

## Tested on
So far, this release has been verified on:

| ✅ Hardware                                                |
|------------------------------------------------------------|
| Raspberry Pi Compute Module 5 on Compute Module 5 IO Board |
| Raspberry Pi Compute Module 5 Lite on [DeskPi Super6C](https://wiki.deskpi.com/super6c/) |
| Raspberry Pi 5b with [RS-P11 for RS-P22 RPi5](https://wiki.52pi.com/index.php?title=EP-0234) |

## What's not working?
* Booting from USB: USB is only available once LINUX has booted up but not in U-Boot.

## How to use?
The releases on this repository align with the corresponding Talos version. There is a raw disk image (initial setup) and an installer image (upgrades) provided.

### Examples
Initial:
```
unzstd metal-arm64-rpi.raw.zst
dd if=metal-arm64-rpi.raw of=<disk> bs=4M status=progress
sync
```

Upgrade:
```
talosctl upgrade \
  --nodes <node IP> \
  --image ghcr.io/talos-rpi5/installer:<version>
```

## Building

If you'd like to make modifications, it is possible to create your own build. Bellow is an example of the standard build. The Makefile needs the model specifying in order to label the produced images properly, model should be `rpi4` or `rpi5`.

On a Mac use `gmake` not `make` and set `SED=gsed` on the command line

```
# To build all assets from the kernel up to (not including the installer) for the RPi4
make RPI_MODEL=rpi4 pi4

# For the pi4 installer image
make RPI_MODEL=rpi4 pi4-installer

# Similarly for the pi5
make RPI_MODEL=rpi5 pi5
make RPI_MODEL=rpi5 pi5-installer

# For the builds on Mac
gmake RPI_MODEL=<model> SED=gsed <TARGET>

# To make SD card images set ASSET_TYPE=metal
make RPI_MODEL=<model> [SED=gsed] ASSET_TYPE=metal <TARGET>
```

### Production builds

Production installer and boot drive images should be built using the [talos-k8s](https://github.dev.youview.co.uk/autinf/talos-k8s) repo and the build profiles specified under th4 `talos-images` directory.

1. A commit on the main branch of this repo should be tagged with a version and then the pre-requisite iamges built and pushed (the build target `pi4` or `pi5`). This should push tagged images for the `imager`, `installer-base` and the pi5 overlay if needed.

1. In `talos-k8s` the build profiles should be updated with the new tag for the installer-base and (for pi5) overlay.

1. In `talos-k8s` the `build-assets.sh` script should be updated with the new imager tag.

1. Build according to the instructions in the `talos-k8s` repo.

## License
See [LICENSE](LICENSE).

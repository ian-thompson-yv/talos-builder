# Notes from AutInf fork

## What this repo does

This repo is forked from [upstream](https://github.com/talos-rpi5/talos-builder) and doesn't change how that repo builds things.
Instead we add patches to change some of the inputs to the build process to add extra kernel modules and specify our own u-boot tarball.
The output of the build process is four container images:
- the `kernel` image that is built from `pkgs` and has kernel modules etc. This is required for the other 3 images.
- the `sbc-raspberrypi5` image that is the overlay image for Pi 5s, this has the hardware specific binaries and consumes our u-boot tarball.
- the `installer-base` image, this is a basic version of the Talos OS.
- the `imager` image, this is a utility image used to build the real installer.

A final bootable `installer` image is not produced by this repo. 
The `sbc-raspberrypi5`, `installer-base` and `imager` are not dependent on one another.
The `talos-k8s` repo has a build script that takes the three images and together with any system extensions and build-args make a bootable asset to use on nodes.

The changes in our fork are to change inputs to the build process or to manage the outputs (registry, naming convention etc).

## Make a patch

To make a git compatible patch easily a dev can either:

For files that are tracked:
`git diff file.txt > file.patch`

For new files that are not tracked:
```
git add file.txt
git diff --cached file.txt > file.patch
git restore --staged file.txt
```

## U-Boot

We supply and build our own u-boot fork from https://github.dev.youview.co.uk/autinf/talos-u-boot
This has some EFI flags changed compared to the upstream talos-builder fork of U-Boot.
The repo is tarballed up and placed onto testaut-nfs-2 to allow the build process to access it with no authentication. The checksum protects the integrity of the tarball.

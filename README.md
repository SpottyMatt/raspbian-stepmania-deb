StepMania Binaries for Raspberry Pi
==============================

![Packaging StepMania on Raspberry Pi](stepmania-deb.png)

These scripts can build `.deb` binary packages to install StepMania on a Raspberry Pi.
This repository's [releases](https://github.com/SpottyMatt/raspbian-stepmania-deb/releases/)
hosts some pre-built StepMania binaries.

There is a lot more required to make StepMania actually _playable_ on a Raspberry Pi.
If all you want to do is play StepMania, check out
[`raspbian-stepmania-arcade`](https://github.com/SpottyMatt/raspbian-stepmania-arcade) instead.

1. [Download Binaries](#download-binaries)
	1. [Installation Instructions](#installation-instructions)
2. [Building Binaries](#building-binaries)

Download Binaries
==============================

Head over to the [releases](https://github.com/SpottyMatt/stepmania-raspi-deb/releases).

Installation Instructions
-------------------------

1. Download the correct `.deb` package for your Raspbian distribution & Raspberry Pi hardware
	* You run `cat /etc/os-release` and look for the `VERSION_CODENAME` to check the Raspbian distro
	* Hopefully you know which Raspberry Pi you have!
2. Run `sudo apt-get install -f ./stepmania.deb`
3. Done!

Building Binaries
==============================

This tooling builds `.deb` packages of StepMania binaries for distribution to Raspberry Pi systems.
It should be used on a Raspberry Pi system that has successfully compiled StepMania from source.

Pre-Requisites
-------------------------

1. Your Raspberry Pi system has successfully [compiled StepMania from source](https://github.com/SpottyMatt/raspbian-stepmania-build).
2. Your Raspberry Pi system uses `dpkg` to manage packages.
3. You are able to clone from GitHub.com

Usage
-------------------------

1. Ensure that `/usr/local` contains one or more `stepmania-X.X` directories from successful compilation of StepMania
	1. This path is not configurable; if you compiled StepMania somewhere else, copy it to `/usr/local`
2. Run `make`
3. One binary package will be generated in the `target` directory for each `/usr/local/stepmania-X.X` directory

### Versioning

Packages will be named following the pattern

	stepmania-RPI-MODEL_VERSION_DATE_DISTRO.deb

For example, if you built StepMania 5.0.1 beta2, as it stood on July 23, 2018, and packaged it with this tool on a Raspberry Pi 4B, you would get

	stepmania-4b_5.1.0-b2_20180723_stretch.deb

The version number, source control revision, and revision date used in the binary package
will be determined automatically by looking at the `stepmania` binary that you compiled.

The Raspberry Pi model will be determined by the [SpottyMatt/rpi-hw-info](https://github.com/SpottyMatt/rpi-hw-info) repository.

If you want to package and distribute a different version, just compile a different version first!

By default, all binary packages will be labelled with a `YYYY-MM-DD` datestamp.

If you are packaging a "real release" of StepMania,
run `make RELEASE=true` to generate the packge with just a version number, e.g.

	stepmania-4b_5.1.0-b2_stretch.deb

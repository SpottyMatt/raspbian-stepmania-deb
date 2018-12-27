#!/usr/bin/env python3
import argparse
import re
import subprocess

# given a comma-separated string of key=value pairs, extract a dict.
def parse_csv_dict(_csv_dict):
	return {pair[0] : pair[1] for pair in [joined_pair.split("=") for joined_pair in _csv_dict.split(",") ]}

parser = argparse.ArgumentParser(description="Locate the debian packages & versions that provide the shared libraries required by one or more binaries. Assumes that this is a debian system & the binaries all correctly run on this system." )

parser.add_argument("--hints", help="csv of so=pkg hints, csv", type=parse_csv_dict)
parser.add_argument("--display", help="libraries, packages, package-versions, or deb-control", default="package-versions", type=str)
parser.add_argument("binary", nargs="*", type=str)

args = parser.parse_args()

if not args.binary:
	parser.print_help()

readelf_check = subprocess.Popen( ["which", "readelf" ], stdout=subprocess.PIPE, stderr=subprocess.PIPE )
readelf_check.communicate()
if 0 != readelf_check.returncode:
	raise RuntimeError( "The `readelf' tool is not on the PATH. Consider installing it with `apt-get install binutils'" )

shared_libraries=set()
packages={}
package_versions={}

# find needed shared libraries
for binary in args.binary:
	shlibs_from_elf =""
	elf_reader = subprocess.Popen( ["readelf", "-d", binary], stdin=None, stdout=subprocess.PIPE, stderr=subprocess.PIPE )
	elf_out, elf_err = elf_reader.communicate()

	if elf_err:
		raise RuntimeError("Couldn't read ELF data from binary {}".format(binary))

	pattern = re.compile(".*?\(NEEDED\)\s*Shared library: \[([^\]]+)\]")
	shared_libraries |= set( pattern.findall(elf_out.decode()) )

if "libraries" == args.display:
	print( "\n".join( sorted( shared_libraries ) ) )
	exit(0)

# find packages that provide those libraries
for library in shared_libraries:
	libpkg_finder = subprocess.Popen( ["dpkg", "--search", library ], stdout=subprocess.PIPE, stderr=subprocess.PIPE )
	libpkg_out, libpkg_err = libpkg_finder.communicate()
	if 0 != libpkg_finder.returncode:
		raise RuntimeError( "No installed package provides {}. Can't help you...".format(library) )
	package = libpkg_out.decode().split("\n")[0].split(":")[0]
	if library in packages and packages[library] != package and not args.hints[library]:
		raise RuntimeError( "Library {} is found in multiple packages: [{}, {}]. Please provide a hint as to which package is correct for this library." )
	elif library in packages and packages[library] != package and args.hints[library]:
		packages[library] = args.hints[library]
	else:
		packages[library] = package

if "packages" == args.display:
	print( "\n".join( sorted( set( packages.values() ) ) ) )
	exit(0)


# find the versions of those packages that are on this system
for package in set( packages.values() ):
	version_finder = subprocess.Popen( [ "dpkg-query", "--show", "--showformat", "${Version}", package ], stdout=subprocess.PIPE, stderr=subprocess.PIPE )
	vf_out, vf_err = version_finder.communicate()
	if 0 != version_finder.returncode:
		raise RuntimeError( "Failed to locate installed version of package {}".format(package) )
	package_versions[package] = vf_out.decode()

if "package-versions" == args.display:
	print( "\n".join( "{} {}".format(package, version) for package, version in sorted( package_versions.items() ) ) )
	exit(0)
elif "debian-control" == args.display:
	print( ",\n ".join( "{} (>= {})".format(package, version) for package, version in sorted( package_versions.items() ) ) )
	exit(0)

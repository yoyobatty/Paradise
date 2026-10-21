#!/bin/bash
# Builds the prebuilt Rust libraries the game loads.
# Usage: tools/ci/build_all_rustlibs.sh [linux|windows]
#   linux:   tools/ci/librustlibs_ci.so, used by CI. Build it on Linux.
#   windows: rustlibs.dll and rustlibs_prod.dll, used by servers. Build them on Windows, they need the MSVC toolchain.
# With no argument it builds the ones for the system you're on.
# The !build_rust bot runs the same commands, see .github/workflows/build_rust.yml.

# Make is fail early if theres a problem
set -euo pipefail

if [[ $# -gt 0 ]]; then
	WHAT="$1"
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
	WHAT="windows"
else
	WHAT="linux"
fi

# Get to our folder first. From here rustup and cargo use the Rust version in rust/rust-toolchain.toml.
cd rust

if [[ "$WHAT" == "linux" ]]; then
	# Build it for CI
	rustup target add i686-unknown-linux-gnu
	cargo build --release --target i686-unknown-linux-gnu
	cp target/i686-unknown-linux-gnu/release/librustlibs.so ../tools/ci/librustlibs_ci.so
elif [[ "$WHAT" == "windows" ]]; then
	# Build it for Windows
	rustup target add i686-pc-windows-msvc
	cargo build --release --target i686-pc-windows-msvc
	cp target/i686-pc-windows-msvc/release/rustlibs.dll ../rustlibs.dll

	# Build the para-specific version
	export RUSTFLAGS='-C target-cpu=znver5'
	cargo build --release --target i686-pc-windows-msvc
	cp target/i686-pc-windows-msvc/release/rustlibs.dll ../rustlibs_prod.dll
else
	echo "Don't know how to build '$WHAT', use linux or windows."
	exit 1
fi

#!/bin/bash
# Installs the Rust version from rust/rust-toolchain.toml on a CI runner,
# plus what's needed to build the 32-bit Linux library.
# Usage: tools/ci/install_rust.sh [extra rustup components, like clippy rustfmt]
set -euo pipefail

sudo dpkg --add-architecture i386
sudo apt-get update
sudo apt-get install -y gcc-multilib zlib1g-dev:i386

cd "$(dirname "$0")/../../rust"
rustup toolchain install
rustup target add i686-unknown-linux-gnu
if [[ $# -gt 0 ]]; then
	rustup component add "$@"
fi

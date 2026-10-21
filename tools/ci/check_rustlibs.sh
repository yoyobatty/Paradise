#!/bin/bash
# Checks that the prebuilt Rust libraries were built from the Rust code in this commit,
# and that rust/rust-toolchain.toml and _build_dependencies.sh ask for the same Rust version.
set -euo pipefail

cd "$(dirname "$0")/../.."

# The Rust version
source _build_dependencies.sh
toolchain_version="$(grep -E '^channel *=' rust/rust-toolchain.toml | cut -d '"' -f 2)"
if [[ "$toolchain_version" != "$RUST_VERSION" ]]; then
	echo "::error::rust/rust-toolchain.toml uses Rust $toolchain_version, but _build_dependencies.sh says $RUST_VERSION. Make them the same."
	exit 1
fi

# The prebuilt libraries. The !build_rust bot writes this file whenever it builds them.
hash_file="tools/ci/rustlibs_source_hash.txt"
if [[ ! -f "$hash_file" ]]; then
	echo "::warning::$hash_file doesn't exist yet, so the prebuilt Rust libraries can't be checked. The !build_rust bot makes it the next time it runs."
	exit 0
fi
built_from="$(tr -d '[:space:]' < "$hash_file")"
current="$(bash tools/ci/rustlibs_source_hash.sh)"
if [[ "$built_from" != "$current" ]]; then
	echo "::error::The Rust code changed, but rustlibs.dll, rustlibs_prod.dll and tools/ci/librustlibs_ci.so weren't rebuilt from it. A maintainer needs to comment !build_rust on this PR."
	exit 1
fi
echo "The prebuilt Rust libraries were built from this Rust code, using Rust $RUST_VERSION."

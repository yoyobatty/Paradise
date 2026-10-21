#!/bin/bash
# Prints a hash of the Rust code the prebuilt libraries are built from.
# It's made from git's own file hashes, so line endings in your checkout don't change it.
# .github/workflows/build_rust.yml runs the same command, keep the two the same.
set -euo pipefail

cd "$(dirname "$0")/../.."
git ls-tree -r HEAD -- rust | grep -v -i "readme" | sha256sum | cut -d " " -f 1

#!/bin/bash
# Checks that .tgs.yml asks TGS for the same BYOND version CI builds with.
set -euo pipefail

cd "$(dirname "$0")/../.."
source _build_dependencies.sh
wanted="$STABLE_BYOND_MAJOR.$STABLE_BYOND_MINOR"
if ! grep -q "^byond: '$wanted'" .tgs.yml; then
	echo "::error file=.tgs.yml::.tgs.yml should use BYOND $wanted, the same as _build_dependencies.sh."
	exit 1
fi
echo ".tgs.yml uses BYOND $wanted."

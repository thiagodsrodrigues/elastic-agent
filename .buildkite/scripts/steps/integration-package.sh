#!/usr/bin/env bash
set -euo pipefail

source .buildkite/scripts/common.sh

AGENT_PACKAGE_VERSION="$(cat .package-version)" PACKAGES=tar.gz,zip,rpm,deb PLATFORMS=linux/amd64,linux/arm64,windows/amd64  SNAPSHOT=true EXTERNAL=true  DEV=true mage package

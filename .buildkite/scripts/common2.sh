#!/bin/bash

set -euo pipefail

source .buildkite/scripts/retry.sh

if [[ -z "${WORKSPACE-""}" ]]; then
    WORKSPACE=$(git rev-parse --show-toplevel)
    export WORKSPACE
fi
PIPELINE="${WORKSPACE}/.buildkite/pipeline.elastic-agent-package.yml"
if [[ -z "${SETUP_MAGE_VERSION-""}" ]]; then
    SETUP_MAGE_VERSION=$(grep -oe "SETUP_MAGE_VERSION\: [\"'].*[\"']" "$PIPELINE" | awk '{print $2}' | sed "s/'//g" )
fi
if [[ -z "${SETUP_GVM_VERSION-""}" ]]; then
    SETUP_GVM_VERSION=$(grep -oe "SETUP_GVM_VERSION\: [\"'].*[\"']" "$PIPELINE" | awk '{print $2}' | sed "s/'//g" )
fi
BEAT_VERSION=$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+(\-[a-zA-Z]+[0-9]+)?' "${WORKSPACE}/version/version.go")
export BEAT_VERSION

getOSOptions() {
  case $(uname | tr '[:upper:]' '[:lower:]') in
    linux*)
      export AGENT_OS_NAME=linux
      ;;
    darwin*)
      export AGENT_OS_NAME=darwin
      ;;
    msys*)
      export AGENT_OS_NAME=windows
      ;;
    *)
      export AGENT_OS_NAME=notset
      ;;
  esac
  case $(uname -m | tr '[:upper:]' '[:lower:]') in
    aarch64*)
      export AGENT_OS_ARCH=arm64
      ;;
    arm64*)
      export AGENT_OS_ARCH=arm64
      ;;
    amd64*)
      export AGENT_OS_ARCH=amd64
      ;;
    x86_64*)
      export AGENT_OS_ARCH=amd64
      ;;
    *)
      export AGENT_OS_ARCH=notset
      ;;
  esac
}

# Wrapper function for executing mage
install_mage() {
    go version
    if ! [ -x "$(type -P mage | sed 's/mage is //g')" ];
    then
        echo "installing mage ${SETUP_MAGE_VERSION}"
        make mage
    fi
    pushd "$WORKSPACE"
}

install_go() {
    # Search for the go in the Path
    if ! [ -x "$(type -P go | sed 's/go is //g')" ];
    then
        getOSOptions
        echo "installing golang "${GO_VERSION}" for "${AGENT_OS_NAME}/${AGENT_OS_ARCH}" "
        local _bin="${WORKSPACE}/bin"
        mkdir -p "${_bin}"
        retry 5 curl -sL -o "${_bin}/gvm" "https://github.com/andrewkroh/gvm/releases/download/${SETUP_GVM_VERSION}/gvm-${AGENT_OS_NAME}-${AGENT_OS_ARCH}"
        chmod +x "${_bin}/gvm"
        eval "$(command "${_bin}/gvm" "${GO_VERSION}" )"
        export GOPATH=$(command go env GOPATH)
        export PATH="${PATH}:${GOPATH}/bin"
    fi
    pushd "$WORKSPACE"
}

google_cloud_auth() {
    local keyFile=$1

    gcloud auth activate-service-account --key-file ${keyFile} 2> /dev/null

    export GOOGLE_APPLICATION_CREDENTIALS=${secretFileLocation}
}

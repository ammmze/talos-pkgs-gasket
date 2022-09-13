#!/usr/bin/env bash

set -euxo pipefail

GITHUB_USERNAME="${GITHUB_USERNAME:-ammmze}"
DOCKER_REGISTRY="ghcr.io/${GITHUB_USERNAME}"
# renovate: datasource=github-releases depName=siderolabs/pkgs
PKGS_VERSION=v1.2.0
# renovate: datasource=github-releases depName=siderolabs/talos
TALOS_VERSION=v1.2.2
PUSH="${PUSH:-false}"

# todo: get whereever script is
INIT_DIR="${PWD}"

function check_installed {
    for arg in "$@"; do
        if ! command -v "$arg" &> /dev/null; then
            echo "$arg was not found. Please install $arg."
            exit 1
        fi
    done
}

function checkout {
    local url="$1"
    local dest="$2"
    local ref="$3"
    local type="${4:-full}"

    if [ ! -d "${dest}" ]; then
        if [ "${type}" = 'shallow' ]; then
            git clone --depth 1 --branch "${ref}" "${url}" "${dest}"
        else
            git clone "${url}" "${dest}"
        fi
        cd "${dest}"
    else
        cd "${dest}"
        # git fetch origin
        git reset --hard
    fi

    git checkout "${ref}"
}

function get_pkgs_kernel_version {
    PKGS_DIR="$1"
    KERNEL_PREPARE_PKG_YAML="${PKGS_DIR}/kernel/prepare/pkg.yaml"
    if [ ! -f "${KERNEL_PREPARE_PKG_YAML}" ]; then
        echo "Could not find ${KERNEL_PREPARE_PKG_YAML}."
        exit 1
    fi
    LINUX_MAJOR_MINOR=$(grep 'https://cdn.kernel.org/pub/linux/kernel' "${KERNEL_PREPARE_PKG_YAML}" | sed -En 's/^.*linux-([0-9]+\.[0-9]+)\.[0-9]+\.tar.xz/\1/p')

    if [ -z "${LINUX_MAJOR_MINOR}" ]; then
        echo "Could not extract linux version from ${KERNEL_PREPARE_PKG_YAML}"
        exit 1
    fi
    echo "${LINUX_MAJOR_MINOR}"
}

# check if dependencies are installed
check_installed wget git make docker

# ensure work directory is present
WORK_DIR="${INIT_DIR}/work"
mkdir -p "${WORK_DIR}"

# grab talos pkgs at the requested version
checkout https://github.com/talos-systems/pkgs "${WORK_DIR}/pkgs" "${PKGS_VERSION}" shallow

# extract the major.minor version from the kernel/prepare/pkg.yaml
LINUX_MAJOR_MINOR="$(get_pkgs_kernel_version "${WORK_DIR}/pkgs")"

# add our script (add-gasket.sh) that adds gasket drivers to pkgs/kernel/prepare/scripts
mkdir -p "${WORK_DIR}/pkgs/kernel/prepare/scripts"
cp -f "${INIT_DIR}/add-gasket.sh" "${WORK_DIR}/pkgs/kernel/prepare/scripts"

# patch the pkgs kerne/prepare/pkg.yaml to run the script to add gasket
# see create-pkgs-patch.sh for now this was created
cd "${WORK_DIR}/pkgs"
patch -p0 < ../../prepare.gasket.patch

# enable gasket in the build configs
echo 'CONFIG_STAGING_GASKET_FRAMEWORK=y' >> "${WORK_DIR}/pkgs/kernel/build/config-amd64"
echo 'CONFIG_STAGING_APEX_DRIVER=y' >> "${WORK_DIR}/pkgs/kernel/build/config-amd64"
echo 'CONFIG_STAGING_GASKET_FRAMEWORK=y' >> "${WORK_DIR}/pkgs/kernel/build/config-arm64"
echo 'CONFIG_STAGING_APEX_DRIVER=y' >> "${WORK_DIR}/pkgs/kernel/build/config-arm64"

TIMESTAMP=$(date '+%Y%m%d%H%M%S')
KERNEL_IMAGE_TAG="v${LINUX_MAJOR_MINOR}-${TIMESTAMP}"

# build kernel image
make kernel PLATFORM=linux/amd64 USERNAME="${GITHUB_USERNAME}" TAG="${KERNEL_IMAGE_TAG}" PUSH="${PUSH}"

# build installer
cd "${INIT_DIR}"
IMAGE_NAME="${DOCKER_REGISTRY}/talos-gasket-installer:${TALOS_VERSION}-${TIMESTAMP}"
DOCKER_BUILDKIT=0 docker build \
    --build-arg TALOS_VERSION="${TALOS_VERSION}" \
    --build-arg KERNEL_REGISTRY="${DOCKER_REGISTRY}" \
    --build-arg KERNEL_IMAGE_TAG="${KERNEL_IMAGE_TAG}" \
    --build-arg RM="/lib/modules" \
    -t "$IMAGE_NAME" \
    .

if [ "${PUSH}" = 'true' ]; then
    docker push "$IMAGE_NAME"
fi
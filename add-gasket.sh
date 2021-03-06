#!/usr/bin/env bash

set -ex

KERNEL_DIR="${1:-$PWD}"
# renovate: datasource=git-refs branch=main depName=https://github.com/google/gasket-driver versioning=git
GASKET_VERSION=97aeba584efd18983850c36dcf7384b0185284b3

TMP_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t 'gasket')

git clone https://github.com/google/gasket-driver "${TMP_DIR}/gasket"
cd "${TMP_DIR}/gasket"
git checkout "${GASKET_VERSION}"

# add gasket to source files to kernel (in same location they were added in 4.19...and later removed)
cp -fr "${TMP_DIR}/gasket/src" "${KERNEL_DIR}/drivers/staging/gasket"

sed -i.bak 's/obj-m/obj-y/' "${KERNEL_DIR}/drivers/staging/gasket/Makefile"
rm -f "${KERNEL_DIR}/drivers/staging/gasket/Makefile.bak"

# include gasket in the drivers menu
sed -i.bak '/endmenu/i \
\
source "drivers/staging/gasket/Kconfig"\
\
' "${KERNEL_DIR}/drivers/Kconfig"
rm -f "${KERNEL_DIR}/drivers/Kconfig.bak"

# add gasket to the drivers Makefile
echo 'obj-$(CONFIG_STAGING_GASKET_FRAMEWORK)	+= staging/gasket/' >> "${KERNEL_DIR}/drivers/Makefile"

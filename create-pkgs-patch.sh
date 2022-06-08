#!/usr/bin/env bash

# re-creates the ./prepare.gasket.patch from the modified work/pkgs/kernel/prepare/
# this should be run manually and the updated prepare.gasket.patch should be committed
(cd work/pkgs && git diff --no-prefix kernel/prepare > ../../prepare.gasket.patch)

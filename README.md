# talos-pkgs-gasket
Builds talos installer with google gasket kernel module. This repo aims to build the latest stable release of Talos with the gasket driver required to run PCI based [Coral](https://coral.ai) devices.

To install, just upgrade using the installer built from this repo rather than the official one. The latest build can be found [here](https://github.com/ammmze/talos-pkgs-gasket/pkgs/container/talos-gasket-installer).


Example:
```shell
talosctl --node my-coral-node upgrade --image ghcr.io/ammmze/talos-gasket-installer:v1.0.6-20220608175417
```
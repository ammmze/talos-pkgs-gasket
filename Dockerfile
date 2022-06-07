ARG TALOS_VERSION
ARG KERNEL_REGISTRY
ARG KERNEL_IMAGE_TAG

# create a stage named kernel because we can't use build args in the "--from" for COPY instructions
FROM ${KERNEL_REGISTRY}/kernel:${KERNEL_IMAGE_TAG} as kernel

FROM scratch AS customization
COPY --from=kernel /lib/modules /lib/modules

FROM ghcr.io/siderolabs/installer:${TALOS_VERSION}
COPY --from=kernel /boot/vmlinuz /usr/install/${TARGETARCH}/vmlinuz

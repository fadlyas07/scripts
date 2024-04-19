#!/usr/bin/env bash
# Simple Kernel Build Script
# Copyright (C) 2020-2024 Muhammad Fadlyas (fadlyas07)
# SPDX-License-Identifier: GPL-3.0-or-later
export DIR="$(pwd)"
if [[ $# -eq 0 ]]; then
    echo "No parameter specified!"
    exit 1
fi
if ! [[ -f "${DIR}/Makefile" && -d "${DIR}/kernel" ]]; then
    echo "Please run this script inside kernel source folder!"
    exit 1
fi
echo "Cloning toolchain dependencies..."
wget https://github.com/greenforce-project/greenforce_clang/raw/main/latest_url.txt && source latest_url.txt
[[ ! -d "${DIR}/AnyKernel3" ]] && git clone --single-branch https://github.com/greenforce-project/AnyKernel3 --depth=1 &>/dev/null
[[ ! -d "${DIR}/greenforce_clang" ]] && mkdir -p "${DIR}/greenforce_clang" &&
    wget -c "$latest_url" -O - | tar --use-compress-program=unzstd -xf - -C "${DIR}/greenforce_clang" &>/dev/null
[[ ! -d "${DIR}/gcc-arm64" ]] && git clone --single-branch https://github.com/greenforce-project/gcc-arm64.git -b main --depth=1 &>/dev/null
echo "All dependencies cloned!"
export ARCH=arm64
export TZ=Asia/Jakarta
export KBUILD_BUILD_USER=MuhammadFadlyArdhianS
export KBUILD_BUILD_HOST=personal-build
export kernel_branch="$(git rev-parse --abbrev-ref HEAD)"
source <(grep -E '^(VERSION|PATCHLEVEL)' Makefile | sed -e s/[[:space:]]//g)
if ! [[ -n "$VERSION" && -n "$PATCHLEVEL" ]]; then
    echo "Unable to get kernel version from Makefile!"
    exit 1
fi
export codename="${2}"
if [[ -z "${codename}" ]]; then
    echo "codename is empty, please provide a codename."
    exit 1
fi
export kernelversion="$VERSION.$PATCHLEVEL"
for version in 3.18 4.4 4.9; do
    if [[ "$version" == "${kernelversion}" ]]; then
        export defconfig="${codename}-perf_defconfig"
    else
        export defconfig="vendor/${codename}-perf_defconfig"
    fi
done
export PATH="${DIR}/greenforce_clang/bin:${DIR}/gcc-arm64/bin:${PATH}"
export IMG_PATH="${DIR}/out/arch/$ARCH/boot"
build_flags="ARCH=$ARCH CC=clang CROSS_COMPILE=aarch64-linux-gnu- "
build_flags+="AR=llvm-ar OBJDUMP=llvm-objdump STRIP=llvm-strip NM=llvm-nm "
[[ "${3}" == llvm || "${3}" == full ]] && build_flags+="LLVM=1 "
echo "Regenerating ${defconfig}..."
make -j$(nproc --all) -l$(nproc --all) -C "${DIR}" O=out ${build_flags} "${defconfig}" 2>&1 | build.log
echo "Regenerating ${defconfig}... done!"
echo "Build kernel started..."
make -j$(nproc --all) -l$(nproc --all) -C "${DIR}" O=out ${build_flags} 2>&1 | build.log
if ! [[ -f "${IMG_PATH}/Image.gz-dtb" || -f "${IMG_PATH}/Image.gz" ]]; then
    echo "Build failed, please check build log and fix it!"
    exit 1
else
    echo "Build Complete, find kernel image in ${IMG_PATH}"
fi
anykernel_string="${kernel_branch} - $(date +'%A'), $(date +'%d %B %Y')"
sed -i "s/kernel.string=/kernel.string=${anykernel_string}/g" "${DIR}/AnyKernel3/anykernel.sh"
sed -i "s/device.name1=/device.name1=${codename}/g" "${DIR}/AnyKernel3/anykernel.sh"
[[ -e "${IMG_PATH}/Image.gz-dtb" ]] && mv "${IMG_PATH}/Image.gz-dtb" "${DIR}/AnyKernel3"
[[ -e "${IMG_PATH}/Image.gz" ]] && mv "${IMG_PATH}/Image.gz" "${DIR}/AnyKernel3"
[[ -e "${IMG_PATH}/dtb.img" ]] && mv "${IMG_PATH}/dtb.img" "${DIR}/AnyKernel3"
[[ -e "${IMG_PATH}/dtb.img" ]] && mv "${IMG_PATH}/dtbo.img" "${DIR}/AnyKernel3"
echo "Compress flashable kernel..."
zip -r9 "GF~${KBUILD_BUILD_USER}-${codename}-$(date +'%d%m%y').zip" "${DIR}/AnyKernel3/*"
echo "complete!"
echo "Build complete! find kernel zip in $(find "${DIR}/AnyKernel3"/*.zip)."

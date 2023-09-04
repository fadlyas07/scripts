#!/usr/bin/env bash
# Lite kernel compilation script [ with Args ]
# Copyright (C) 2020, 2022, 2023 Muhammad Fadlyas (fadlyas07)
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
echo "Cloning dependencies..."
[[ ! -d "${DIR}/AnyKernel3" ]] && git clone --single-branch https://github.com/greenforce-project/AnyKernel3 --depth=1 &>/dev/null
[[ ! -d "${DIR}/aosp_clang" ]] && git clone --single-branch https://github.com/greenforce-project/aosp_clang --depth=1 &>/dev/null
[[ ! -d "${DIR}/aarch64-linux-android-4.9" ]] && git clone --single-branch https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 -b android-9.0.0_r40 --depth=1 &>/dev/null
[[ ! -d "${DIR}/arm-linux-androideabi-4.9" ]] && git clone --single-branch https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 -b android-9.0.0_r40 --depth=1 &>/dev/null
echo "All dependencies cloned!"
export ARCH=arm64
export SUBARCH="${ARCH}"
export KBUILD_BUILD_USER=personal
export KBUILD_BUILD_HOST=greenforce-project
export kernel_branch=$(git rev-parse --abbrev-ref HEAD)
export TZ=Asia/Jakarta
source <(grep -E '^(VERSION|PATCHLEVEL)' Makefile | sed -e s/[[:space:]]//g)
if ! [[ -n "$VERSION" && -n "$PATCHLEVEL" ]]; then
    echo "Unable to get kernel version from Makefile!"
    exit 1
fi
export codename="${2}" &>/dev/codename
if [[ -n "${codename}" ]]; then
    if [[ -f "/dev/codename" ]]; then
        export codename="$(cat /dev/codename)"
    else
        echo "codename is empty, please run 'export codename=[CODENAME]'"
        exit 1
    fi
fi
export kernelversion="$VERSION.$PATCHLEVEL"
case "${kernelversion}" in
    4.19|5.4|5.10|5.15|6.0)
        export defconfig="vendor/${codename}-perf_defconfig"
        export vdso_flags='CROSS_COMPILE_COMPAT'
        ;;
    *)
        export defconfig="${codename}-perf_defconfig"
        export vdso_flags='CROSS_COMPILE_ARM32'
        ;;
esac
export PATH="${DIR}/aosp_clang/bin:${DIR}/aarch64-linux-android-4.9/bin:${DIR}/arm-linux-androideabi-4.9/bin:${PATH}"
export LD_LIBRARY_PATH="${DIR}/aosp_clang/bin/../lib:${LD_LIBRARY_PATH}"
export IMG_PATH="${DIR/out/arch/$ARCH/boot}"
build_flags="ARCH=$ARCH CC=clang CLANG_TRIPLE=aarch64-linux-gnu- CROSS_COMPILE=aarch64-linux-android- ${vdso_flags}=arm-linux-androideabi- "
build_flags+="AR=llvm-ar OBJDUMP=llvm-objdump STRIP=llvm-strip NM=llvm-nm "
[[ "${3}" == llvm || "${3}" == full ]] && build_flags+="LLVM=1 "
make -j$(nproc --all) -C ${DIR} O=out ${build_flags} "${defconfig}" 2>&1| build.log
if ! [[ -f "${IMG_PATH}/Image.gz-dtb" || -f "${IMG_PATH}/Image.gz" ]]; then
    echo "Build failed, please check build log and fix it!"
    exit 1
else
    echo "Build Complete, find kernel image in ${IMG_PATH}"
fi
anykernel_string="${kernel_branch} - $(date +'%A'), $(date +'%d %B %Y')"
sed -i "s/kernel.string=/kernel.string=${anykernel_string}/g" ${DIR}/AnyKernel3/anykernel.sh
sed -i "s/device.name1=/device.name1=${codename}/g" ${DIR}/AnyKernel3/anykernel.sh
[[ -e "${IMG_PATH}/Image.gz-dtb" ]] && mv "${IMG_PATH}/Image.gz-dtb" "${DIR}/AnyKernel3"
[[ -e "${IMG_PATH}/Image.gz" ]] && mv "${IMG_PATH/Image.gz" "${DIR}/AnyKernel3"
[[ -e "${IMG_PATH}/dtb.img" ]] && mv "${IMG_PATH}/dtb.img" "${DIR}/AnyKernel3"
[[ -e "${IMG_PATH}/dtb.img" ]] && mv "${IMG_PATH}/dtbo.img" "${DIR}/AnyKernel3"
echo "Compress flashable kernel..."
zip -r9 "GF~${KBUILD_BUILD_USER}-${codename}-$(date +'%d%m%y').zip" $DIR/AnyKernel3/*
echo "complete!"
echo "Build complete! find kernel zip in $(find $DIR/AnyKernel3/*.zip)."

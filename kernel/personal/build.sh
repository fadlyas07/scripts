#!/usr/bin/env bash
# Lite kernel compilation script [ with Args ]
# Copyright (C) 2020 - 2022 Muhammad Fadlyas (fadlyas07)
# SPDX-License-Identifier: GPL-3.0-or-later
if [[ $# -eq 0 ]]; then
    echo "No parameter specified!"
    exit 1
fi
if ! [[ -f Makefile && -d kernel ]]; then
    echo "Please run this script inside kernel source folder!"
    exit 1
fi
export DIR="$(pwd)"
echo "Cloning dependencies..."
[[ ! -d "$DIR/AnyKernel3" ]] && git clone --single-branch https://github.com/greenforce-project/AnyKernel3 --depth=1 &>/dev/null
[[ ! -d "$DIR/aosp_clang" ]] && git clone --single-branch https://github.com/greenforce-project/aosp_clang --depth=1 &>/dev/null
[[ ! -d "$DIR/aarch64-linux-android-4.9" ]] && git clone --single-branch https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 -b android-9.0.0_r40 --depth=1 &>/dev/null
[[ ! -d "$DIR/arm-linux-androideabi-4.9" ]] && git clone --single-branch https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 -b android-9.0.0_r40 --depth=1 &>/dev/null
echo "All dependencies cloned!"
export ARCH=arm64
export SUBARCH="$ARCH"
export KBUILD_BUILD_USER=personal
export KBUILD_BUILD_HOST=greenforce-project
export kernel_branch=$(git rev-parse --abbrev-ref HEAD)
export TZ=Asia/Jakarta
DATE=$(date)
export KBUILD_BUILD_TIMESTAMP="$DATE"
source <(grep -E '^(VERSION|PATCHLEVEL)' Makefile | sed -e s/[[:space:]]//g)
if ! [[ -n "$VERSION" && -n "$PATCHLEVEL" ]]; then
    echo "Unable to get kernel version from Makefile!"
    exit 1
fi
export kernelversion="$VERSION.$PATCHLEVEL"
if [[ "$kernelversion" == 4.19 ]]; then
    export vdso_flags='CROSS_COMPILE_COMPAT'
else
    export vdso_flags='CROSS_COMPILE_ARM32'
fi
export codename="$2" &>/dev/codename
if [[ -n "$codename" ]]; then
    if [[ -f "/dev/codename" ]]; then
        export codename=$(cat /dev/codename)
    else
        echo "codename is empty, please run 'export codename=[CODENAME]'"
        exit 1
    fi
fi
export defconfig="$codename"-perf_defconfig
export PATH="$DIR/aosp_clang/bin:$DIR/aarch64-linux-android-4.9/bin:$DIR/arm-linux-androideabi-4.9/bin:$PATH"
export LD_LIBRARY_PATH="$DIR/aosp_clang/bin/../lib:$LD_LIBRARY_PATH"
export IMG_PATH="$DIR/out/arch/$ARCH/boot"
build_flags="ARCH=$ARCH "
build_flags+="CC=clang "
build_flags+="CLANG_TRIPLE=aarch64-linux-gnu- "
build_flags+="CROSS_COMPILE=aarch64-linux-android- "
build_flags+="${vdso_flags}=arm-linux-androideabi- "
make -j"$(nproc --all)" -C "$DIR" O=out "$build_flags" "$defconfig" 2>&1| build.log
if ! [[ -f "$IMG_PATH/Image.gz-dtb" || -f "$IMG_PATH/Image" ]]; then
    echo "Build failed, please check build log and fix it!"
    exit 1
else
    echo "Build Complete, find kernel image in $IMG_PATH"
fi
anykernel_string="$kernel_branch - $(date +'%A'), $(date +'%d %B %Y')"
sed -i "s/kernel.string=/kernel.string=$anykernel_string/g" $DIR/AnyKernel3/anykernel.sh
sed -i "s/device.name1=/device.name1=$codename/g" $DIR/AnyKernel3/anykernel.sh
cp "$IMG_PATH/Image.gz-dtb" "$DIR/AnyKernel3" || cp "$IMG_PATH/Image" "$DIR/AnyKernel3"
cp "$IMG_PATH/dtb.img" "$DIR/AnyKernel3" || echo "dtb.img not found!"
cp "$IMG_PATH/dtbo.img" "$DIR/AnyKernel3" || echo "dtbo.img not found!"
echo "Zipping flashable kernel..."
zip -r9 "GF~${KBUILD_BUILD_USER}-${codename}-$(date +'%d%m%y').zip" $DIR/AnyKernel3/*
echo "Zipping complete!"
echo "Build complete! You can find kernel zip in $(find $DIR/AnyKernel3/*.zip)."

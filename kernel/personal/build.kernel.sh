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

[[ ! -d "$DIR/AnyKernel3" ]] && git clone --single-branch https://github.com/greenforce-project/AnyKernel3 --depth=1 &>/dev/null
[[ ! -d "$DIR/aosp_clang" ]] && git clone --single-branch https://github.com/greenforce-project/aosp_clang --depth=1 &>/dev/null
[[ ! -d "$DIR/aarch64-linux-android-4.9" ]] && git clone --single-branch https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 -b android-9.0.0_r40 --depth=1 &>/dev/null
[[ ! -d "$DIR/arm-linux-androideabi-4.9" ]] && git clone --single-branch https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 -b android-9.0.0_r40 --depth=1 &>/dev/null

export ARCH=arm64
export SUBARCH="$ARCH"
export KBUILD_BUILD_USER=personal
export KBUILD_BUILD_HOST=greenforce-project
export KBUILD_BUILD_TIMESTAMP=$(TZ=Asia/Jakarta date)
source <(grep -E '^(VERSION|PATCHLEVEL)' Makefile | sed -e s/[[:space:]]//g)
if ! [[ -n "$VERSION" && -n "$PATCHLEVEL" ]]; then
    echo "Unable to get kernel version from Makefile!"
    exit 1
fi
export kernelversion="$VERSION.$PATCHLEVEL"
if [[ "$kernelversion" ~= 4.19 ]]; then
    export vdso_flag="CROSS_COMPILE_COMPAT"
else
    export vdso_flag="CROSS_COMPILE_ARM32"
fi
export codename="$2" &>/dev/codename
if [[ -n "$codename" ]]; then
    if [[ -f "/dev/codename" ]]; then
        export codename=$(cat /dev/codename)
    else
        echo "codename is empty, do 'export codename=[CODENAME]' to build."
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
# Disable stackprotector strong config
sed -i 's/CONFIG_STACKPROTECTOR_STRONG=y/# CONFIG_STACKPROTECTOR_STRONG is not set/g' out/.config
if ! [[ -f "$IMG_PATH/Image.gz-dtb" || -f "$IMG_PATH/Image" ]]; then
    echo "Build failed, please check and fix it!"
    exit 1
else
    echo "Build Complete, find the bacon in $IMG_PATH"
fi
mv "$IMG_PATH/Image.gz-dtb" "$DIR/anykernel-3" || mv "$IMG_PATH/Image" "$DIR/AnyKernel3"
mv "$IMG_PATH/dtb.img" "$DIR/anykernel-3" || echo "dtb.img not found!"
mv "$IMG_PATH/dtbo.img" "$DIR/anykernel-3" || echo "dtbo.img not found!"
zip -r9q "GF~${KBUILD_BUILD_USER}-${codename}-$(TZ=Asia/Jakarta date +'%d%m%y').zip" $DIR/AnyKernel3/*
echo "Build complete! You can find the zip in $(find $DIR/AnyKernel3/*.zip)."

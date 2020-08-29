#!/usr/bin/env bash
# Lite kernel compilation script [ Args ]
# Copyright (C) 2020 Muhammad Fadlyas (fadlyas07)
# SPDX-License-Identifier: GPL-3.0-or-later

# Usage : [ chat_id token my_id defconfig codename arch ]

[[ ! -d "$(pwd)/anykernel-3" ]] && git clone https://github.com/fadlyas07/anykernel-3 --depth=1 &>/dev/null
[[ ! -d "$(pwd)/gcc" ]] && git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 --depth=1 -b android-9.0.0_r59 gcc &>/dev/null
[[ ! -d "$(pwd)/gcc32" ]] && git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 --depth=1 -b android-9.0.0_r59 gcc32 &>/dev/null

# Main Environment
codename="$5"
MAIN_ARCH="$6"
product_name='GreenForce'
temp="$(pwd)/temporary"
pack="$(pwd)/anykernel-3"
kernel_img="$(pwd)/out/arch/arm64/boot/Image.gz-dtb"

mkdir "$(pwd)/temporary"

tg_send_message() {
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
         -d "disable_web_page_preview=true" \
         -d "parse_mode=html" \
         -d chat_id="$TELEGRAM_ID" \
         -d text="$(
                    for POST in "${@}" ; do
                        echo "${POST}"
                    done
            )" &>/dev/null
}

# Needed to export
export ARCH="$MAIN_ARCH"
export SUBARCH="$MAIN_ARCH"
export TELEGRAM_ID="$1"
export TELEGRAM_TOKEN="$2"
export TELEGRAM_PRIV="$3"
export KBUILD_BUILD_USER=fadlyas07
export KBUILD_BUILD_HOST=circleci-Lab
export CROSS_COMPILE="$(pwd)/gcc/bin/aarch64-linux-android-"
export CROSS_COMPILE_ARM32="$(pwd)/gcc32/bin/arm-linux-androideabi-"

echo 'Build started ...'
build_date="$(TZ=Asia/Jakarta date +'%H%M-%d%m%y')"
make ARCH="$MAIN_ARCH" O=out "$4" &>/dev/null
make -j"$(nproc --all)" -l"$(nproc --all)" ARCH="$MAIN_ARCH" O=out 2>&1| tee "Log-$(TZ=Asia/Jakarta date +'%d%m%y').log"
mv Log-*.log "$temp"

if [[ ! -f "$kernel_img" ]] ; then
    curl -F document=@$(echo $temp/Log-*.log) "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" -F chat_id="$TELEGRAM_PRIV"
    tg_send_message "build throw an errors!"
    exit 1 ;
else
    kernel_version="$(cat $(pwd)/out/.config | grep Linux/arm64 | cut -d " " -f3)"
    curl -F document=@$(echo $temp/Log-*.log) "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" -F chat_id="$TELEGRAM_PRIV"
    mv "$kernel_img" "$pack/zImage" && cd $pack || exit 1 ;
    zip -r9 $product_name-$codename-"$build_date".zip * -x .git README.md LICENCE $(echo *.zip) &>/dev/null && cd .. || exit 1 ;
    curl -F chat_id="$TELEGRAM_ID" -F caption="New #$codename build is available! ($kernel_version, $(git rev-parse --abbrev-ref HEAD)) at commit $(git log --pretty=format:"%h (\"%s\")" -1)." \
         -F "disable_web_page_preview=true" -F "parse_mode=html" \
         -F document=@$(echo $pack/*.zip) "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument"
fi
rm -rf out $(echo $pack/*.zip) $pack/zImage

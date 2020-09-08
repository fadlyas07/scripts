#!/usr/bin/env bash
# Lite kernel compilation script [ Args ]
# Copyright (C) 2020 Muhammad Fadlyas (fadlyas07)
# SPDX-License-Identifier: GPL-3.0-or-later
# Usage : [ codename chat_id defconfig my_id token toolchain zip name ]

if [[ $# -eq 0 ]] ; then
    echo "No parameter specified!"
  exit 1 ;
fi

case "$6" in
# define toolchain for build
    -sd | --sd-clang)
        [[ ! -d "$(pwd)/tc-clang" ]] && git clone --single-branch https://github.com/crdroidmod/android_vendor_qcom_proprietary_llvm-arm-toolchain-ship_6.0.9 --depth=1 tc-clang &>/dev/null
        [[ ! -d "$(pwd)/gcc" ]] && git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 --depth=1 -b android-9.0.0_r59 gcc &>/dev/null
        [[ ! -d "$(pwd)/gcc32" ]] && git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 --depth=1 -b android-9.0.0_r59 gcc32 &>/dev/null
        ;;
    -ac | --aosp-clang)
        [[ ! -d "$(pwd)/tc-clang" ]] && git clone --single-branch https://github.com/crdroidmod/android_prebuilts_clang_host_linux-x86_clang-6766004 --depth=1 tc-clang &>/dev/null 
        [[ ! -d "$(pwd)/gcc" ]] && git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 --depth=1 -b android-9.0.0_r59 gcc &>/dev/null
        [[ ! -d "$(pwd)/gcc32" ]] && git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 --depth=1 -b android-9.0.0_r59 gcc32 &>/dev/null
        ;;
    -pr | --proton-clang)
        [[ ! -d "$(pwd)/tc-clang" ]] && git clone --single-branch https://github.com/kdrag0n/proton-clang --depth=1 tc-clang &>/dev/null
        ;;
    -gf | --gf-clang)
        [[ ! -d "$(pwd)/tc-clang" ]] && git clone --single-branch https://github.com/GreenForce-project-repository/clang-11.0.0 --depth=1 tc-clang &>/dev/null
        ;;
    -az | --azure-clang)
        [[ ! -d "$(pwd)/tc-clang" ]] && git clone --single-branch https://github.com/Panchajanya1999/azure-clang --depth=1 tc-clang &>/dev/null
        ;;
    -av | --avalon-clang)
        [[ ! -d "$(pwd)/tc-clang" ]] && git clone --single-branch https://github.com/Haseo97/Avalon-Clang-11.0.1 --depth=1 tc-clang &>/dev/null
        ;;
    *)
        [[ ! -d "$(pwd)/gcc" ]] && git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 --depth=1 -b android-9.0.0_r59 gcc &>/dev/null
        [[ ! -d "$(pwd)/gcc32" ]] && git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 --depth=1 -b android-9.0.0_r59 gcc32 &>/dev/null
        ;;
    # Auto define command for build
        -sd | -ac )
          build_command() {
            export LD_LIBRARY_PATH="$(pwd)/tc-clang/lib:$LD_LIBRARY_PATH" ;
            PATH="$(pwd)/tc-clang/bin:$(pwd)/gcc/bin:$(pwd)/gcc32/bin:$PATH" \
            make -j"$(nproc --all)" -l"$(nproc --all)" O=out \
                                                       ARCH="$ARCH" \
                                                       CC=clang \
                                                       CLANG_TRIPLE=aarch64-linux-gnu- \
                                                       CROSS_COMPILE=aarch64-linux-android- \
                                                       CROSS_COMPILE_ARM32=arm-linux-androideabi-
          }
          ;;
        -pr | -gf | -az | -av)
          build_command() {
            PATH="$(pwd)/tc-clang/bin:$PATH" \
            make -j"$(nproc --all)" -l"$(nproc --all)" O=out \
                                                       ARCH="$ARCH" \
                                                       AR=llvm-ar \
                                                       CC=clang \
                                                       NM=llvm-nm \
                                                       OBJCOPY=llvm-objcopy \
                                                       OBJDUMP=llvm-objdump \
                                                       STRIP=llvm-strip \
                                                       CROSS_COMPILE=aarch64-linux-gnu- \
                                                       CROSS_COMPILE_ARM32=arm-linux-gnueabi-
          }
          ;;
        *)
          build_command() {
            PATH="$(pwd)/gcc/bin:$(pwd)/gcc32/bin:$PATH" \
            make -j"$(nproc --all)" -l"$(nproc --all)" O=out \
                                                       ARCH="$ARCH" \
                                                       CROSS_COMPILE=aarch64-linux-android- \
                                                       CROSS_COMPILE_ARM32=arm-linux-androideabi-
          }
          ;;
esac

# Main Environment
codename="$1"
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

# custom compiler name for clang
if [[ -d "$(pwd)/tc-clang" ]] ; then
    CCV="$($(pwd)/tc-clang/bin/clang --version | head -n1)"
    LDV="$($(pwd)/tc-clang/bin/ld.lld --version | head -n1)"
    export KBUILD_COMPILER_STRING="$CCV with $LDV"
fi

# Needed to export
export TELEGRAM_ID="$2"
export TELEGRAM_TOKEN="$5"
export TELEGRAM_PRIV="$4"
export KBUILD_BUILD_USER=fadlyas07
export KBUILD_BUILD_HOST=circleci-Lab

echo Build started ... ;
build_date="$(TZ=Asia/Jakarta date +'%H%M-%d%m%y')"
make ARCH="$ARCH" O=out "$3" &>/dev/null
build_command 2>&1| tee "Log-$(TZ=Asia/Jakarta date +'%d%m%y').log"
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
    curl -F chat_id="$TELEGRAM_ID" -F caption="New #$codename build is available! ($kernel_version, $(git rev-parse --abbrev-ref HEAD)) at commit $(git log --pretty=format:"%h (\"%s\")" -1)" \
         -F "disable_web_page_preview=true" -F "parse_mode=html" \
         -F document=@$(echo $pack/*.zip) "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument"
fi

case "$7" in
    "yes|Yes|yEs|yeS|YES")
        rm -rf out $(echo $pack/*.zip) $pack/zImage $temp/$(echo *.log)
        ;;
    "no|No|nO|NO")
        rm -rf $temp/$(echo *.log)
        ;;
    *)
        echo "nothing to do, kek!"
        ;;
esac

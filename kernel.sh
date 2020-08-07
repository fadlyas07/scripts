#!/usr/bin/env bash
# Simple kernel compilation script
# Copyright (C) 2020 Muhammad Fadlyas (fadlyas07)
# SPDX-License-Identifier: GPL-3.0-or-later

if [[ -n $CI ]] ; then
    echo "Yeay, build running on CI!" ;
        if [[ -z $chat_id ]] && [[ -z $token ]] ; then
            echo 'chat id and bot token does not exist!' ;
            exit 1 ;
        fi
    ls -Aq &>/dev/null
else
    echo "Okay, build running on my VM" ;
        if [[ -z $chat_id ]] && [[ -z $token ]] ; then
            read -p "Enter your chat id: " chat_id
            read -p "Enter your bot token: " token
            export chat_id token
        fi
    ls -Aq &>/dev/null
fi
case '$(git rev-parse --abbrev-ref HEAD)' in *"17.1"*)
unset chat_id && export chat_id="784548477" ;; esac

config_path="$(pwd)/arch/arm64/configs"
if [[ -e "$config_path/ugglite_defconfig" ]] ; then
    device=ugglite && config_device1=ugglite_defconfig
elif [[ -e "$config_path/rolex_defconfig" ]] || [[ -e "$config_path/riva_defconfig" ]] ; then
    device=rova && config_device1=rolex_defconfig && config_device2=riva_defconfig
fi

[[ ! -d "$(pwd)/anykernel-3" ]] && git clone https://github.com/fadlyas07/anykernel-3 --depth=1 &>/dev/null
[[ ! -d "$(pwd)/origin_gcc" ]] && git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 --depth=1 -b android-9.0.0_r58 origin_gcc &>/dev/null
[[ ! -d "$(pwd)/origin_gcc32" ]] && git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 --depth=1 -b android-9.0.0_r58 origin_gcc32 &>/dev/null

# Needed to export
export ARCH=arm64
export SUBARCH=arm64
export TELEGRAM_ID=$chat_id
export TELEGRAM_TOKEN=$token
export KBUILD_BUILD_USER=fadlyas
export KBUILD_BUILD_HOST=circleci-Lab

mkdir "$(pwd)/temporary"

tg_send_message() {
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
         -d "disable_web_page_preview=true" \
         -d "parse_mode=html" \
         -d chat_id="$TELEGRAM_ID" \
         -d text="$(
                    for POST in "${@}" ; do
                        echo "$POST"
                    done
            )" &>/dev/null
}

build_kernel() {
    PATH="$(pwd)/origin_gcc/bin:$(pwd)/origin_gcc32/bin:$PATH" \
    make "-j$(nproc --all)" O=out \
                            ARCH=arm64 \
                            CROSS_COMPILE=aarch64-linux-android- \
                            CROSS_COMPILE_ARM32=arm-linux-androideabi-
}

# Main Environment
product_name='GreenForce'
temp="$(pwd)/temporary"
pack="$(pwd)/anykernel-3"
kernel_img="$(pwd)/out/arch/arm64/boot/Image.gz-dtb"

# build kernel - 1
build_start1=$(date +"%s")
build_date1="$(TZ=Asia/Jakarta date +'%H%M-%d%m%y')"

make ARCH=arm64 O=out $config_device1 &>/dev/null
build_kernel 2>&1| tee "Log-$(TZ=Asia/Jakarta date +'%d%m%y').log"
mv Log-*.log $temp

if [[ ! -f "$kernel_img" ]] ; then
    build_end=$(date +"%s")
    build_diff=$(($build_end - $build_start1))
    grep -iE 'Stop|not|empty|in file|waiting|crash|error|fail|fatal' $(echo $temp/Log-*.log) &> "$temp/trimmed_log.txt"
    send_to_dogbin="$(echo https://del.dog/raw/$(jq -r .key <<< $(curl -sf --data-binary '$(cat $temp/Log-*.log)' https://del.dog/documents)))"
    curl -F document=@$(echo $temp/Log-*.log) "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" -F chat_id="784548477"
    curl -F document=@$(echo $temp/Log-*.log) "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" -F chat_id="$TELEGRAM_ID" -F "disable_web_page_preview=true" -F "parse_mode=html" -F caption="<b>build throw an errors!</b> ($(git rev-parse --abbrev-ref HEAD | cut -b 9-15)) (Log : $send_to_dogbin) Build took $(($build_diff / 60)) minutes, $(($build_diff % 60)) seconds."
    exit 1 ;
fi

build_end1=$(date +"%s")
build_diff1=$(($build_end1 - $build_start1))
kernel_version="$(cat $(pwd)/out/.config | grep Linux/arm64 | cut -d " " -f3)"
curl -F document=@$(echo $temp/Log-*.log) "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" -F chat_id="784548477"
mv "$kernel_img" "$pack/zImage" && cd $pack
if [[ "$device" == "ugglite" ]] ; then
    zip -r9 $product_name-ugglite-"$build_date1".zip * -x .git README.md LICENCE $(echo *.zip) &>/dev/null && cd ..
    curl -F document=@$(echo $pack/*.zip) "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" -F chat_id="$TELEGRAM_ID" -F caption="New #ugglite build is available! ($kernel_version, $(git rev-parse --abbrev-ref HEAD | cut -b 9-15)) at commit $(git log --pretty=format:"%h (\"%s\")" -1) Build took $(($build_diff1 / 60)) minutes, $(($build_diff1 % 60)) seconds."
elif [[ "$device" == "rova" ]] ; then
    zip -r9 $product_name-rolex-"$build_date1".zip * -x .git README.md LICENCE $(echo *.zip) &>/dev/null && cd ..
    curl -F document=@$(echo $pack/*.zip) "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" -F chat_id="$TELEGRAM_ID" -F caption="New #rolex build is available! ($kernel_version, $(git rev-parse --abbrev-ref HEAD | cut -b 9-15)) at commit $(git log --pretty=format:"%h (\"%s\")" -1) Build took $(($build_diff1 / 60)) minutes, $(($build_diff1 % 60)) seconds."
fi

if [[ "$device" != "ugglite" ]] ; then
    rm -rf out $pack/*.zip $temp/Log-*.log $pack/zImage

    # build kernel - 2
    build_start2=$(date +"%s")
    build_date2="$(TZ=Asia/Jakarta date +'%H%M-%d%m%y')"
    make ARCH=arm64 O=out $config_device2 &>/dev/null
    build_kernel 2>&1| tee "Log-$(TZ=Asia/Jakarta date +'%d%m%y').log"
    mv Log-*.log $temp

    build_end2=$(date +"%s")
    build_diff2=$(($build_end2 - $build_start2))
    kernel_version="$(cat $(pwd)/out/.config | grep Linux/arm64 | cut -d " " -f3)"
    curl -F document=@$(echo $temp/Log-*.log) "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" -F chat_id="784548477"
    mv "$kernel_img" "$pack/zImage" && cd $pack
    if [[ "$device" == "rova" ]] ; then
        zip -r9 $product_name-riva-"$build_date2".zip * -x .git README.md LICENCE $(echo *.zip) &>/dev/null && cd ..
        curl -F document=@$(echo $pack/*.zip) "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" -F chat_id="$TELEGRAM_ID" -F caption="New #riva build is available! ($kernel_version, $(git rev-parse --abbrev-ref HEAD | cut -b 9-15)) at commit $(git log --pretty=format:"%h (\"%s\")" -1) Build took $(($build_diff2 / 60)) minutes, $(($build_diff2 % 60)) seconds."
    fi
fi

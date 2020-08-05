#!/usr/bin/env bash
# Simple kernel compilation script
# Copyright (C) 2020 Muhammad Fadlyas (fadlyas07)
# SPDX-License-Identifier: GPL-3.0-or-later

if [[ -n $CI ]] ; then
    echo "Yeay, build running on CI!" ;
        if [[ -z $chat_id ]] && [[ -z $token ]] ; then
            echo 'chat id and token does not exist!' ;
            exit 1 ;
        fi
    ls -Aq &>/dev/null
else
    echo "Okay, build running on my VM" ;
        if [[ -z $chat_id ]] && [[ -z $token ]] ; then
            read -p "Enter your chat_id: " chat_id
            read -p "Enter your bot token: " token
        fi
    ls -Aq &>/dev/null
fi

config_path="$(pwd)/arch/arm64/configs"
if [[ -e "$config_path/ugglite_defconfig" ]] ; then
    device="Xiaomi Redmi Note 5A Lite" && config_device1=ugglite_defconfig
elif [[ -e "$config_path/rolex_defconfig" ]] || [[ -e "$config_path/riva_defconfig" ]] ; then
    device="Xiaomi Redmi 4A/5A" && config_device1=rolex_defconfig && config_device2=riva_defconfig
fi

case "$(git rev-parse --abbrev-ref HEAD)" in
lineage-17.1)
        unset chat_id && export chat_id="784548477"
        clone_toolchain() {
        [[ ! -d "$(pwd)/origin_gcc" ]] && git clone https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9 --depth=1 -b lineage-17.1 origin_gcc
        [[ ! -d "$(pwd)/origin_gcc32" ]] && git clone https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9 --depth=1 -b lineage-17.1 origin_gcc32
        }
        build_kernel() {
        PATH="$(pwd)/origin_gcc/bin:$(pwd)/origin_gcc32/bin:$PATH" \
        make "-j$(nproc --all)" O=out \
                                ARCH=arm64 \
                                CROSS_COMPILE=aarch64-linux-android- \
                                CROSS_COMPILE_ARM32=arm-linux-androideabi-
        }
        ;;
*)
        clone_toolchain() {
        [[ ! -d "$(pwd)/llvm_clang" ]] && git clone https://github.com/GreenForce-project-repository/clang-11.0.0 --depth=1 -b master llvm_clang
        }
        build_kernel() {
        export CCV="$($(pwd)/llvm_clang/bin/clang --version | head -n1 | perl -pe 's/\(.*?\)//gs' | sed 's/[[:space:]]*$//')" ;
        export LDV="$($(pwd)/llvm_clang/bin/ld.lld --version | head -n1 | perl -pe 's/\(.*?\)//gs' | sed 's/(compatible with [^)]*)//' | sed 's/[[:space:]]*$//')" ;
        export LD_LIBRARY_PATH="$(pwd)/llvm_clang/lib:$LD_LIBRARY_PATH" ;
        PATH="$(pwd)/llvm_clang/bin:$PATH" \
        make "-j$(nproc --all)" O=out \
                                ARCH=arm64 \
                                AR=llvm-ar \
                                CC=clang \
                                NM=llvm-nm \
                                OBJCOPY=llvm-objcopy \
                                OBJDUMP=llvm-objdump \
                                STRIP=llvm-strip \
                                CROSS_COMPILE=aarch64-linux-gnu- \
                                CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
                                KBUILD_COMPILER_STRING="$CCV, $LDV"
        }
        ;;
esac

clone_toolchain &>/dev/null
[[ ! -d "$(pwd)/anykernel-3" ]] && git clone https://github.com/fadlyas07/anykernel-3 --depth=1

# Needed to export
export ARCH=arm64
export SUBARCH=arm64
export TELEGRAM_ID=$chat_id
export TELEGRAM_TOKEN=$token
export KBUILD_BUILD_USER=fadlyas
export KBUILD_BUILD_HOST=circleci-Lab

mkdir "$(pwd)/temporary"

tg_send_sticker() {
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendSticker" \
         -d sticker="CAACAgUAAxkBAAEYl9pee0jBz-DdWSsy7Rik8lwWE6LARwACmQEAAn1Cwy4FwzpKLPPhXRgE" \
         -d chat_id="$TELEGRAM_ID"
}

tg_send_message() {
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
         -d "disable_web_page_preview=true" \
         -d "parse_mode=html" \
         -d chat_id="$TELEGRAM_ID" \
         -d text="$(
                    for POST in "${@}" ; do
                        echo "$POST"
                    done
            )"
}

# Main Environment
product_name='GreenForce'
temp="$(pwd)/temporary"
pack="$(pwd)/anykernel-3"
kernel_img="$(pwd)/out/arch/arm64/boot/Image.gz-dtb"

# build kernel
build_start=$(date +"%s")
build_date1="$(TZ=Asia/Jakarta date +'%H%M-%d%m%y')"

make ARCH=arm64 O=out $config_device1 &>/dev/null
build_kernel 2>&1| tee "Log-$(TZ=Asia/Jakarta date +'%d%m%y').log"
mv Log-*.log "$temp"

if [[ ! -f $kernel_img ]] ; then
    build_end=$(date +"%s")
    build_diff=$(($build_end - $build_start))
    grep -iE 'Stop|not|empty|in file|waiting|crash|error|fail|fatal' "$(echo $temp/Log-*.log)" &> "$temp/trimmed_log.txt"
    send_to_dogbin="$(echo https://del.dog/raw/$(jq -r .key <<< $(curl -sf --data-binary "$(cat $temp/Log-*.log)" https://del.dog/documents)))"
    curl -F document=@$(echo $temp/Log-*.log) "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" -F chat_id="784548477"
    curl -F document=@$(echo $temp/*.txt) "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" -F chat_id="$TELEGRAM_ID"
    tg_send_message "<b>build throw an errors!</b>" \
                    "<b>Branch :</b> origin/$(git rev-parse --abbrev-ref HEAD) ($(git rev-parse --abbrev-ref HEAD | cut -b 9-15))" \
                    "<b>Log :</b> $send_to_dogbin" \
                    "<b>Time elapsed :</b> $(($build_diff / 60)) minutes, $(($build_diff % 60)) seconds."
    exit 1 ;
fi

curl -F document=@$(echo $temp/Log-*.log) "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" -F chat_id="784548477"
mv "$kernel_img" "$pack/zImage" && cd $pack
if [[ $device == "Xiaomi Redmi Note 5A Lite" ]] ; then
    zip -r9q $product_name-ugglite-"$build_date1".zip * -x .git README.md LICENCE $(echo *.zip)
elif [[ $device == "Xiaomi Redmi 4A/5A" ]] ; then
    zip -r9q $product_name-rolex-"$build_date1".zip * -x .git README.md LICENCE $(echo *.zip)
fi
cd ..

if [[ $device != "Xiaomi Redmi Note 5A Lite" ]] ; then
    rm -rf out "$temp/Log-*.log" "$pack/zImage"

    # build kernel
    build_date2="$(TZ=Asia/Jakarta date +'%H%M-%d%m%y')"
    make ARCH=arm64 O=out $config_device2 &>/dev/null
    build_kernel 2>&1| tee "Log-$(TZ=Asia/Jakarta date +'%d%m%y').log"
    mv Log-*.log "$temp"

    curl -F document=@$(echo $temp/Log-*.log) "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" -F chat_id="784548477"
    mv "$kernel_img" "$pack/zImage" && cd $pack
        if [[ $device == "Xiaomi Redmi 4A/5A" ]] ; then
            zip -r9q $product_name-riva-"$build_date2".zip * -x .git README.md LICENCE $(echo *.zip)
        fi
    cd ..
fi

build_end=$(date +"%s")
build_diff=$(($build_end - $build_start))
kernel_version=$(cat $(pwd)/out/.config | grep Linux/arm64 | cut -d " " -f3)
toolchain_version=$(cat $(pwd)/out/include/generated/compile.h | grep LINUX_COMPILER | cut -d '"' -f2)

tg_send_sticker
tg_send_message "<b>Device :</b> $device" \
                "<b>Branch :</b> origin/$(git rev-parse --abbrev-ref HEAD) ($(git rev-parse --abbrev-ref HEAD | cut -b 9-15))" \
                "<b>Kernel version :</b> Linux $kernel_version" \
                "<b>Compiler :</b> $toolchain_version" \
                "<b>Latest commit :</b> $(git log --pretty=format:'%s' -1)" \
                "<b>Time elapsed :</b> $(($build_diff / 60)) minutes, $(($build_diff % 60)) seconds."
if [[ $device == "Xiaomi Redmi Note 5A Lite" ]] ; then
    curl -F document=@$(echo $pack/$product_name-ugglite-$build_date1.zip) "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" -F chat_id="$TELEGRAM_ID"
elif [[ $device == "Xiaomi Redmi 4A/5A" ]] ; then
    curl -F document=@$(echo $pack/$product_name-rolex-$build_date1.zip) "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" -F chat_id="$TELEGRAM_ID"
    sleep 2
    curl -F document=@$(echo $pack/$product_name-riva-$build_date2.zip) "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" -F chat_id="$TELEGRAM_ID"
fi

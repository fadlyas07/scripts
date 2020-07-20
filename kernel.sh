#!/usr/bin/env bash
# Circle CI/CD - Simple kernel build script
# Copyright (C) 2019, 2020, Raphielscape (@raphielscape)
# Copyright (C) 2018, 2019, Akhil Narang (@akhilnarang)
# Copyright (C) 2020, Muhammad Fadlyas (@fadlyas07)

# clone all preparations if not exist
[[ ! -d "$(pwd)/anykernel-3" ]] && git clone https://github.com/fadlyas07/anykernel-3 --depth=1
[[ ! -d "$(pwd)/telegram" ]] && git clone https://github.com/fabianonline/telegram.sh --depth=1 telegram
if [[ "$(git rev-parse --abbrev-ref HEAD)" != "lineage-17.1" ]]; then
    [[ ! -d "$(pwd)/tc-clang" ]] && git clone https://github.com/GreenForce-project-repository/clang-11.0.0 --depth=1 -b master llvm_clang
else
    [[ ! -d "$(pwd)/tc-gcc" ]] && https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9 --depth=1 -b lineage-17.1 origin_gcc
    [[ ! -d "$(pwd)/tc-gcc32" ]] && https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9 --depth=1 -b lineage-17.1 origin_gcc32
fi

# let see `defconfig` to determine device for compiled
config_path="$(pwd)/arch/arm64/configs"
if [[ -e "$config_path/ugglite_defconfig" ]]; then
    device="Xiaomi Redmi Note 5A Lite" && config_device1=ugglite_defconfig
elif [[ -e "$config_path/rolex_defconfig" || "$config_path/riva_defconfig" ]]; then
    device="Xiaomi Redmi 4A/5A" && config_device1=rolex_defconfig && config_device2=riva_defconfig
fi

# set `GitHub` config
git config --global user.name "fadlyas07"
git config --global user.email "fadlyardhians@gmail.com"

# create `Temporary` folder
mkdir $(pwd)/temporary
temp=$(pwd)/temporary

# export build `Architecture`
export ARCH=arm64
export SUBARCH=arm64

# export `Telegram` Environment
export TELEGRAM_TOKEN="$token"
# change chat_id to my_id for `A10` branch
case "$(git rev-parse --abbrev-ref HEAD)" in
    "lineage-17.1")
        unset chat_id
        export chat_id="784548477"
    ;;
esac
export TELEGRAM_ID="$chat_id"

# cchace inflation
ccache -M 50G
export USE_CCACHE=1
export CCACHE_COMPRESS=1
export WITHOUT_CHECK_API=true
export CCACHE_EXEC=/usr/bin/ccache

# some other kernel stuff
pack=$(pwd)/anykernel-3
product_name=GreenForce
kernel_img=$(pwd)/out/arch/arm64/boot/Image.gz-dtb

# send sticker to channel
tg_send_sticker()
{
   curl -s -X POST "https://api.telegram.org/bot"$TELEGRAM_TOKEN"/sendSticker" \
           -d sticker="CAACAgUAAxkBAAEYl9pee0jBz-DdWSsy7Rik8lwWE6LARwACmQEAAn1Cwy4FwzpKLPPhXRgE" \
           -d chat_id="$TELEGRAM_ID"
}

# send info to main channel
tg_send_message()
{
    curl -s -X POST "https://api.telegram.org/bot"$TELEGRAM_TOKEN"/sendMessage" \
            -d "disable_web_page_preview=true" \
            -d chat_id="$TELEGRAM_ID" \
            -d "parse_mode=html" \
            -d text="$(
           for POST in "$@"; do
               echo "$POST"
           done
    )"
}

# Make the kernel
case "$(git rev-parse --abbrev-ref HEAD)" in
    "lineage-17.1")
        make_kernel()
        {
         PATH=$(pwd)/origin_gcc/bin:$(pwd)/origin_gcc32/bin:"$PATH" \
         make -j$(nproc --all) O="out" \
                               ARCH="arm64" \
                               CROSS_COMPILE="aarch64-linux-gnu-" \
                               CROSS_COMPILE_ARM32="arm-linux-gnueabi-" \
                               KBUILD_BUILD_USER="Mhmmdfdlyas" \
                               KBUILD_BUILD_HOST="$(TZ=Asia/Jakarta date +'%B')-build"
        }
        ;;
    "*")
        make_kernel()
        {
         export LD_LIBRARY_PATH=$(pwd)/llvm_clang/lib:"$PATH"
         PATH=$(pwd)/llvm_clang/bin:"$PATH" \
         make -j$(nproc --all) O="out" \
                               ARCH="arm64" \
                               AR="llvm-ar" \
                               CC="clang" \
                               CROSS_COMPILE="aarch64-linux-gnu-" \
                               CROSS_COMPILE_ARM32="arm-linux-gnueabi-" \
                               KBUILD_BUILD_USER="Mhmmdfdlyas" \
                               KBUILD_BUILD_HOST="$(TZ=Asia/Jakarta date +'%B')-build" \
                               NM="llvm-nm" \
                               OBJCOPY="llvm-objcopy" \
                               OBJDUMP="llvm-objdump" \
                               STRIP="llvm-strip"
        }
        ;;
esac

# `time` mark started build
build_start=$(date +"%s")
# `time` mark build (1)
date1=$(TZ=Asia/Jakarta date +'%H%M-%d%m%y')

# build kernel
make ARCH=arm64 O=out $config_device1
make_kernel 2>&1| tee Log-$(TZ=Asia/Jakarta date +'%d%m%y').log
mv Log-*.log "$temp"
# find errors
if ! [[ -f "$kernel_img" ]]; then
    # `time` mark errors build
    build_end=$(date +"%s")
    build_diff=$(($build_end - $build_start))
    # ship log to `del.dog` & grep errors to `trimmed_log.txt`
    grep -iE 'not|empty|in file|waiting|crash|error|fail|fatal' "$(echo $temp/*.log)" &> "$temp/trimmed_log.txt"
    send_to_dogbin=$(echo https://del.dog/$(jq -r .key <<< $(curl -sf --data-binary "$(cat $(echo $temp/*.log))" https://del.dog/documents)))
    # ship it all to main channel
    curl -F document=@$(echo $temp/*.log) "https://api.telegram.org/bot"$TELEGRAM_TOKEN"/sendDocument" -F chat_id="784548477"
    curl -F document=@$(echo $temp/*.txt) "https://api.telegram.org/bot"$TELEGRAM_TOKEN"/sendDocument" -F chat_id="$TELEGRAM_ID" -F caption="$send_to_dogbin"
    tg_send_message "<b>$product_name</b> for <b>$device</b> on branch '<b>$(git rev-parse --abbrev-ref HEAD)</b>' Build errors in $(($build_diff / 60)) minutes and $(($build_diff % 60)) seconds."
    exit 1
fi
curl -F document=@$(echo $temp/*.log) "https://api.telegram.org/bot"$TELEGRAM_TOKEN"/sendDocument" -F chat_id="784548477"
mv "$kernel_img" "$pack/zImage" && cd $pack
if [[ "$device" = "Xiaomi Redmi Note 5A Lite" ]]; then
    zip -r9 $product_name-ugglite-$date1.zip * -x .git README.md LICENCE $(echo *.zip)
elif [[ "$device" = "Xiaomi Redmi 4A/5A" ]]; then
    zip -r9 $product_name-rolex-$date1.zip * -x .git README.md LICENCE $(echo *.zip)
fi
cd ..

# continue build if not
if ! [[ "$device" = "Xiaomi Redmi Note 5A Lite" ]]; then
# delete output, previous log, and zImage
rm -rf out/ $temp/*.log $pack/zImage

# `time` mark build (2)
date2=$(TZ=Asia/Jakarta date +'%H%M-%d%m%y')

# build kernel
make ARCH=arm64 O=out $config_device2
make_kernel 2>&1| tee Log-$(TZ=Asia/Jakarta date +'%d%m%y').log
mv Log-*.log "$temp"
curl -F document=@$(echo $temp/*.log) "https://api.telegram.org/bot"$TELEGRAM_TOKEN"/sendDocument" -F chat_id="784548477"
mv "$kernel_img" "$pack/zImage" && cd $pack
if [[ "$device" = "Xiaomi Redmi 4A/5A" ]]; then
    zip -r9 $product_name-riva-$date2.zip * -x .git README.md LICENCE $(echo *.zip)
fi
cd ..
fi

# `time` mark ended build
build_end=$(date +"%s")
build_diff=$(($build_end - $build_start))

# some kernel stuff for channel
kernel_version=$(cat $(pwd)/out/.config | grep Linux/arm64 | cut -d " " -f3)
toolchain_version=$(cat $(pwd)/out/include/generated/compile.h | grep LINUX_COMPILER | cut -d '"' -f2)

# push everything to channel
tg_send_sticker
tg_send_message "⚠️ <i>Warning: New build is available!</i> working on <b>$(git rev-parse --abbrev-ref HEAD)</b> in <b>Linux $kernel_version</b> using <b>$toolchain_version</b> for <b>$device</b> at commit <b>$(git log --pretty=format:'%s' -1)</b> build complete in <b>$(($build_diff / 60)) minutes</b> and <b>$(($build_diff % 60)) seconds</b>."
if [[ "$device" = "Xiaomi Redmi Note 5A Lite" ]]; then
    curl -F document=@$(echo $pack/$product_name-ugglite-$date1.zip) "https://api.telegram.org/bot"$TELEGRAM_TOKEN"/sendDocument" -F chat_id="$TELEGRAM_ID"
elif [[ "$device" = "Xiaomi Redmi 4A/5A" ]]; then
    curl -F document=@$(echo $pack/$product_name-rolex-$date1.zip) "https://api.telegram.org/bot"$TELEGRAM_TOKEN"/sendDocument" -F chat_id="$TELEGRAM_ID"
    curl -F document=@$(echo $pack/$product_name-riva-$date2.zip) "https://api.telegram.org/bot"$TELEGRAM_TOKEN"/sendDocument" -F chat_id="$TELEGRAM_ID"
fi

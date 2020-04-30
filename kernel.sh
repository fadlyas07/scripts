#!/usr/bin/env bash
# Circle CI/CD - Simple kernel build script
# Copyright (C) 2019, 2020 Raphielscape LLC (@raphielscape)
# Copyright (C) 2019, 2020 Dicky Herlambang (@Nicklas373)
# Copyright (C) 2020 Muhammad Fadlyas (@fadlyas07)
export parse_branch=$(git rev-parse --abbrev-ref HEAD)
if [[ $parse_branch == "lavender" ]]; then
    export device="Xiaomi Redmi Note 7/7S"
    export config_device1=lavender-perf_defconfig
    export config_device2=lavender-perf_defconfig
else
    export device="Xiaomi Redmi 4A/5A"
    export config_device1=rolex_defconfig
    export config_device2=riva_defconfig
fi
if ! [[ $parse_branch == "Eas-version" ]]; then
    git clone --depth=1 --single-branch https://github.com/fadlyas07/android_prebuilts_clang_host_linux-x86_clang-r383902 -b 10.0 clang
fi
git clone --depth=1 --single-branch https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 -b android-9.0.0_r55 gcc
git clone --depth=1 --single-branch https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 -b android-9.0.0_r55 gcc32
git clone --depth=1 --single-branch https://github.com/fabianonline/telegram.sh telegram
git clone --depth=1 --single-branch https://github.com/fadlyas07/anykernel-3
mkdir $(pwd)/temp
export ARCH=arm64
export TEMP=$(pwd)/temp
export TELEGRAM_ID=$chat_id
export TELEGRAM_TOKEN=$token
export pack=$(pwd)/anykernel-3
export product_name=GreenForce
export KBUILD_BUILD_HOST=$(git log --format='%H' -1)
export KBUILD_BUILD_USER=$(git log --format='%cn' -1)
export kernel_img=$(pwd)/out/arch/arm64/boot/Image.gz-dtb
build_start=$(date +"%s")

tg_sendstick() {
   curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendSticker" \
	-d sticker="CAACAgUAAxkBAAEYl9pee0jBz-DdWSsy7Rik8lwWE6LARwACmQEAAn1Cwy4FwzpKLPPhXRgE" \
	-d chat_id="$TELEGRAM_ID"
}
TELEGRAM=telegram/telegram
tg_channelcast() {
    "$TELEGRAM" -c "$TELEGRAM_ID" -H \
	"$(
		for POST in "$@"; do
			echo "$POST"
		done
	)"
}
if [[ $parse_branch == "Eas-version" ]]; then
    tg_build() {
      PATH=$(pwd)/gcc/bin:$(pwd)/gcc32/bin:$PATH \
      make -j$(nproc) O=out \
                      ARCH=arm64 \
                      CROSS_COMPILE=aarch64-linux-android- \
                      CROSS_COMPILE_ARM32=arm-linux-androideabi-
    }
else
    tg_build() {
      PATH=$(pwd)/clang/bin:$(pwd)/gcc/bin:$(pwd)/gcc32/bin:$PATH \
      make -j$(nproc) O=out \
		      ARCH=arm64 \
		      CC=clang \
		      CLANG_TRIPLE=aarch64-linux-gnu- \
		      CROSS_COMPILE=aarch64-linux-android- \
		      CROSS_COMPILE_ARM32=arm-linux-androideabi-
    }
fi
date1=$(TZ=Asia/Jakarta date +'%H%M-%d%m%y')
make ARCH=arm64 O=out "$config_device1" && \
tg_build 2>&1| tee $(TZ=Asia/Jakarta date +'%A-%H%M-%d%m%y').log
mv *.log $TEMP
if ! [[ -f "$kernel_img" ]]; then
    build_end=$(date +"%s")
    build_diff=$(($build_end - $build_start))
    curl -F document=@$(echo $TEMP/*.log) "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" -F chat_id="$TELEGRAM_ID"
    tg_channelcast "<b>$product_name</b> for <b>$device</b> Build errors in $(($build_diff / 60)) minutes and $(($build_diff % 60)) seconds."
    exit 1
fi
curl -F document=@$(echo $TEMP/*.log) "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" -F chat_id="$TELEGRAM_ID"
mv $kernel_img $pack/zImage
cd $pack
if [[ $parse_branch == "lavender" ]]; then
    zip -r9q $product_name-lavender-new-blob-$date1.zip * -x .git README.md LICENCE $(echo *.zip)
else
    zip -r9q $product_name-rolex-$date1.zip * -x .git README.md LICENCE $(echo *.zip)
fi
cd ..
rm -rf out/ $TEMP/*.log $pack/zImage
date2=$(TZ=Asia/Jakarta date +'%H%M-%d%m%y')
if [[ $parse_branch == "lavender" ]]; then
    git revert 4ab2eb2bd6389b776de2cf5a94e8c1eb96251e09 --no-commit
fi
make ARCH=arm64 O=out "$config_device2" && \
tg_build 2>&1| tee $(TZ=Asia/Jakarta date +'%A-%H%M-%d%m%y').log
mv *.log $TEMP
if ! [[ -f "$kernel_img" ]]; then
    build_end=$(date +"%s")
    build_diff=$(($build_end - $build_start))
    curl -F document=@$(echo $TEMP/*.log) "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" -F chat_id="$TELEGRAM_ID"
    tg_channelcast "<b>$product_name</b> for <b>$device</b> Build errors in $(($build_diff / 60)) minutes and $(($build_diff % 60)) seconds."
    exit 1
fi
curl -F document=@$(echo $TEMP/*.log) "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" -F chat_id="$TELEGRAM_ID"
mv $kernel_img $pack/zImage
cd $pack
if [[ $parse_branch == "lavender" ]]; then
    zip -r9q $product_name-lavender-old-blob-$date2.zip * -x .git README.md LICENCE $(echo *.zip)
else
    zip -r9q $product_name-riva-$date2.zip * -x .git README.md LICENCE $(echo *.zip)
fi
cd ..
build_end=$(date +"%s")
build_diff=$(($build_end - $build_start))
kernel_ver=$(cat $(pwd)/out/.config | grep Linux/arm64 | cut -d " " -f3)
toolchain_ver=$(cat $(pwd)/out/include/generated/compile.h | grep LINUX_COMPILER | cut -d '"' -f2)
tg_sendstick
tg_channelcast "⚠️ <i>Warning: New build is available!</i> working on <b>$parse_branch</b> in <b>Linux $kernel_ver</b> using <b>$toolchain_ver</b> for <b>$device</b> at commit <b>$(git log --pretty=format:'%s' -1)</b>. Build complete in $(($build_diff / 60)) minutes and $(($build_diff % 60)) seconds."
if [[ $parse_branch == "lavender" ]]; then
    curl -F document=@$pack/$product_name-lavender-new-blob-$date1.zip "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" -F chat_id="$TELEGRAM_ID"
    curl -F document=@$pack/$product_name-lavender-old-blob-$date2.zip "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" -F chat_id="$TELEGRAM_ID"
else
    curl -F document=@$pack/$product_name-rolex-$date1.zip "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" -F chat_id="$TELEGRAM_ID"
    curl -F document=@$pack/$product_name-riva-$date2.zip "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" -F chat_id="$TELEGRAM_ID"
fi

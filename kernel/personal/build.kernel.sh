#!/usr/bin/env bash
# Lite kernel compilation script [ with Args ]
# Copyright (C) 2020 Muhammad Fadlyas (fadlyas07)
# SPDX-License-Identifier: GPL-3.0-or-later
if [[ $# -eq 0 ]] ; then
    echo "No parameter specified!"
  exit 1 ;
fi
git clone --quiet --depth=1 https://github.com/fadlyas07/anykernel-3
export ARCH=arm64 && export SUBARCH=arm64
trigger_sha="$(git rev-parse HEAD)" && commit_msg="$(git log --pretty=format:'%s' -1)"
export my_id="$2" && export channel_id="$3" && export token="$4"
git clone --quiet --depth=1 https://github.com/arter97/arm64-gcc -b master gcc
export CROSS_COMPILE=aarch64-elf-
if [[ msm_test != 1 ]] : then # Yep, clone gcc32 for vDSO32 :(
    git clone --quiet --depth=1 https://github.com/arter97/arm32-gcc -b master gcc32
    export CROSS_COMPILE_ARM32=arm-eabi-
fi
export KBUILD_BUILD_USER=greenforce-bot && export KBUILD_BUILD_HOST=nightly-build
make -j$(nproc) ARCH=arm64 O=out ${1}
make -j$(nproc) ARCH=arm64 O=out &> build.log
if [[ ! -f $(pwd)/out/arch/arm64/boot/Image.gz-dtb ]] ; then
    curl -F document=@$(pwd)/build.log "https://api.telegram.org/bot${token}/sendDocument" -F chat_id=${my_id}
    curl -s -X POST "https://api.telegram.org/bot${token}/sendMessage" -d chat_id=${my_id} -d text="Build failed! at branch $(git rev-parse --abbrev-ref HEAD)"
  exit 1 ;
fi
curl -F document=@$(pwd)/build.log "https://api.telegram.org/bot${token}/sendDocument" -F chat_id=${my_id}
mv $(pwd)/out/arch/arm64/boot/Image.gz-dtb $(pwd)/anykernel-3
cd $(pwd)/anykernel-3 && zip -r9q "${KBUILD_BUILD_USER}"-"${KBUILD_BUILD_HOST}"-"${codename}"-"$(TZ=Asia/Jakarta date +'%d%m%y')".zip *
cd .. && curl -F "disable_web_page_preview=true" -F "parse_mode=html" -F document=@$(echo $(pwd)/anykernel-3/*.zip) "https://api.telegram.org/bot${token}/sendDocument" -F caption="
The new test-build for #${codename} coming with Linux $(cat $(pwd)/out/.config | grep Linux/arm64 | cut -d " " -f3) success at commit $(echo ${trigger_sha} | cut -c 1-8) (\"<a href='${my_project}/${target_repo}/commit/${trigger_sha}'>${commit_msg}</a>\") | <b>SHA1:</b> <code>$(sha1sum $(echo $(pwd)/anykernel-3/*.zip ) | awk '{ print $1 }')</code>." -F chat_id=${channel_id}
rm -rf out $(pwd)/anykernel-3/*.zip $(pwd)/anykernel-3/zImage $(pwd)/*.log

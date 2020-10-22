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
export my_id="$3" && export channel_id="$4" && export token="$5"
if [[ "$2" == "clang" ]] ; then
    git clone --quiet --depth=1 https://github.com/greenforce-project/clang-11.0.0 proton-clang cc_lang
    function build_now() {
        export PATH="$(pwd)/cc_lang/bin:$PATH"
        export LD_LIBRARY_PATH="$(pwd)/cc_lang/lib:$LD_LIBRARY_PATH"
        export CCV="$(cc_lang/bin/clang --version | head -n 1)"
        export LDV="$(cc_lang/bin/ld.lld --version | head -n 1 | perl -pe 's/\(git.*?\)//gs' | sed 's/(compatible with [^)]*)//' | sed 's/[[:space:]]*$//')"
        export KBUILD_COMPILER_STRING="${CCV} with ${LDV}"
        make -j$(nproc) -l$(nproc) ARCH=arm64 O=out CC=clang \
                                   AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy \
                                   OBJDUMP=llvm-objdump CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
                                   STRIP=llvm-strip
    }
elif [[ "$2" == "gcc" ]] ; then
    git clone --quiet --depth=1 https://github.com/chips-project/aarch64-elf gcc
    git clone --quiet --depth=1 https://github.com/chips-project/arm-eabi gcc32
    function build_now() {
        export PATH="$(pwd)/gcc/bin:$(pwd)/gcc32/bin:$PATH"
        make -j$(nproc) -l$(nproc) ARCH=arm64 O=out CROSS_COMPILE=aarch64-elf- \
                                   CROSS_COMPILE_ARM32=arm-eabi-
    }
else
    curl -s -X POST "https://api.telegram.org/bot${token}/sendMessage" -d chat_id=${my_id} -d text="Please set your toochains on args!"
  exit 1 ;
fi
export KBUILD_BUILD_USER=greenforce && export KBUILD_BUILD_HOST=nightly
make -j$(nproc) -l$(nproc) ARCH=arm64 O=out ${1} && build_now &> build.log
if [[ ! -f $(pwd)/out/arch/arm64/boot/Image.gz-dtb ]] ; then
    curl -F document=@$(pwd)/build.log "https://api.telegram.org/bot${token}/sendDocument" -F chat_id=${my_id}
    curl -s -X POST "https://api.telegram.org/bot${token}/sendMessage" -d chat_id=${my_id} -d text="Build failed! at branch $(git rev-parse --abbrev-ref HEAD)"
  exit 1 ;
fi
curl -F document=@$(pwd)/build.log "https://api.telegram.org/bot${token}/sendDocument" -F chat_id=${my_id}
mv $(pwd)/out/arch/arm64/boot/Image.gz-dtb $(pwd)/anykernel-3
cd $(pwd)/anykernel-3 && zip -r9q "${KBUILD_BUILD_USER}"-"${KBUILD_BUILD_HOST}"-"${codename}"-"$(TZ=Asia/Jakarta date +'%d%m%y')".zip *
cd .. && curl -F "disable_web_page_preview=true" -F "parse_mode=html" -F document=@$(echo $(pwd)/anykernel-3/*.zip) "https://api.telegram.org/bot${token}/sendDocument" -F caption="
New build for #${codename} + $(cat $(pwd)/out/.config | grep Linux/arm64 | cut -d " " -f3) success at commit $(echo ${trigger_sha} | cut -c 1-8) (\"<a href='${my_project}/${target_repo}/commit/${trigger_sha}'>${commit_msg}</a>\") | <b>SHA1:</b> <code>$(sha1sum $(echo $(pwd)/anykernel-3/*.zip ) | awk '{ print $1 }')</code>." -F chat_id=${channel_id}
rm -rf out $(pwd)/anykernel-3/*.zip $(pwd)/anykernel-3/zImage $(pwd)/*.log

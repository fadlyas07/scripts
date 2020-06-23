#!/usr/bin/env bash
# Ubuntu 18.04 LTS - Simple local kernel build script
# Copyright (C) 2019, 2020, Raphielscape LLC (@raphielscape)
# Copyright (C) 2019, 2020, Dicky Herlambang (@Nicklas373)
# Copyright (C) 2019, 2020, Dhimas Bagus Prayoga (@kry9ton)
# Copyright (C) 2020, Muhammad Fadlyas (@fadlyas07)
export ARCH=arm64
export pack=$(pwd)/anykernel-3
export github_name=$(git config user.name)
export github_email=$(git config user.email)
export parse_branch=$(git rev-parse --abbrev-ref HEAD)
export kernel_img=$(pwd)/out/arch/arm64/boot/Image.gz-dtb
if ! [[ -e $(pwd)/anykernel-3 ]]; then
    git clone --quiet --depth=1 https://github.com/fadlyas07/anykernel-3
fi
if ! [[ -e $(pwd)/gcc ]]; then
    git clone --quiet --depth=1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 -b android-9.0.0_r57 gcc
    git clone --quiet --depth=1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 -b android-9.0.0_r57 gcc32
fi
if [ -z $github_name ] && [ -z $github_email ]; then
    echo -e "empty git config user.name & git config user.email"
    read -p "Enter user.name: " NAME
    read -p "Enter user.email: " EMAIL
    git config --global user.name "$NAME"
    git config --global user.email "$EMAIL"
fi
clear
while true; do
    echo -e "\n[1] Build an android Kernel"
    echo -e "[2] Cleanup source"
    echo -e "[3] Create flashable zip"
    echo -e "[4] Exit"
    echo -ne "\n(i) Please enter a choice[1-5]: "
    read choice
if [ "$choice" = "1" ]; then
    clear
    echo -e ""
    echo -e "Enter your defconfig name"
    read -p "Enter defconfig: " CONFIG
    if [[ -z $CONFIG ]]; then
        echo -e " You GaY plox, enter your defconfig name first!"
        exit 1
    fi
    make O=out ARCH=arm64 $CONFIG > /dev/null
    PATH=$(pwd)/gcc/bin:$(pwd)/gcc32/bin:$PATH && \
    make -j$(nproc --all) O=out \ ARCH=arm64 \ CROSS_COMPILE=aarch64-linux-android- \ CROSS_COMPILE_ARM32=arm-linux-androideabi- 2>&1| tee Log-$(TZ=Asia/Jakarta date +'%d%m%y').log
    build_start=$(date +"%s")
    echo -e "\n#######################################################################"
    echo -e "(i) Build started at $(`date`)"
    spin[0]="-"
    spin[1]="\\"
    spin[2]="|"
    spin[3]="/"
    while kill -0 $pid &>/dev/null
      do
        for i in "${spin[@]}"
          do
            echo -ne "\b$i"
          sleep 0.1
        done
      done
    if ! [ -f $kernel_img ]; then
        build_end=$(date +"%s")
        build_diff=$(($build_end - $build_start))
        grep -iE 'not|empty|in file|waiting|crash|error|fail|fatal' "$(echo *.log)" &> "trimmed_log.txt"
        echo -e "\n(!) Kernel compilation failed at $(($build_diff / 60)) minutes and $(($build_end % 60)) seconds."
        echo -e "#######################################################################"
        exit 1
    fi
    build_end=$(date +"%s")
    build_diff=$(($build_end - $build_start))
    echo -e "\n(i) Image-dtb compiled successfully."
    echo -e "#######################################################################"
    echo -e "(i) Total time elapsed: $(($build_diff / 60)) minute(s) and $(($build_diff % 60)) seconds."
    echo -e "#######################################################################"
fi
if [ "$choice" = "2" ]; then
    clear
    echo -e "\n#######################################################################"
    make O=out clean &>/dev/null
    make mrproper &>/dev/null
    rm -rf out/* temp trimm*.txt *.log
    echo -e "(i) Kernel source cleaned up."
    echo -e "#######################################################################"
fi
if [ "$choice" = "3" ]; then
    clear
    echo -e "\n#######################################################################"
    cd $pack
    make clean &>/dev/null
    echo -e "Checking your image.gz-dtb..."
    sleep 3
      if ! [ -f $kernel_img ]; then
          echo -e "Image.gz-dtb Not Found!"
          sleep 1
          echo -e "Aborting process..."
          sleep 2
      else
          mv $kernel_img $pack/zImage
          make normal &>/dev/null
          echo -e "(i) Flashable zip generated under $pack."
          echo -e "#######################################################################"
      fi
    cd ..
fi
if [ "$choice" = "4" ]; then
    clear
    exit 
fi
done

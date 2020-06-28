#!/usr/bin/env bash
# Ubuntu 18.04 LTS - Simple local kernel build script
# Copyright (C) 2019, 2020, Raphielscape LLC (@raphielscape)
# Copyright (C) 2019, 2020, Dicky Herlambang (@Nicklas373)
# Copyright (C) 2019, 2020, Dhimas Bagus Prayoga (@kry9ton)
# Copyright (C) 2020, Muhammad Fadlyas (@fadlyas07)

clear

# Clone AnyKernel If not exist
if ! [[ -e $(pwd)/anykernel-3 ]]; then
    echo -e ""
    echo -e "Determine your AnyKernel now"
    echo -e ""
    echo -e "\n[1] fadlyas/anykernel-3"
    echo -e "[2] Custom anykernel"
    echo -e "[3] Exit"
    echo -ne "\nEnter a choice[1-3]: "
    read choice
    if [ $choice = "1" ]; then
        echo -e "cloning anykernel-3..."
        anykernel_link=https://github.com/fadlyas07/anykernel-3
        git clone --quiet --depth=1 "$anykernel_link" anykernel-3
    fi
    if [ $choice = "2" ]; then
        echo -e "cloning anykernel-3..."
        echo -e "Enter the Link of your custom anykernel here"
        read -p "AnyAkernel URL's: " anykernel_link
        git clone --quiet --depth=1 "$anykernel_link" anykernel-3
    fi
    if [ $choice = "3" ]; then
        exit 1
    fi
fi

# Clone Compiler If not exist
if ! [[ -e $(pwd)/tc-clang ]]; then
    echo -e ""
    echo "Ok now determine clang will you use"
    echo -e ""
    echo -e "Why clang? clang is Future plox :v"
    echo -e ""
    echo -e "\n[1] GF🔥clang 11.0.0"
    echo -e "[2] Proton Clang 11.0.0"
    echo -e "[3] Custom clang"
    echo -e "[4] Exit"
    echo -ne "\nEnter a choice[1-4]: "
    read choice
    if [ $choice = "1" ]; then
        echo -e "Cloning GF🔥clang 11.0.0..."
        git clone --quiet --depth=1 https://github.com/fadlyas07/clang-11.0.0 tc-clang
    fi
    if [ $choice = "2" ]; then
        echo -e "Cloning Proton clang 11.0.0..."
        git clone --quiet --depth=1 https://github.com/kdrag0n/proton-clang tc-clang
    fi
    if [ $choice = "3" ]; then
        echo -e ""
        echo -e "⚠️ Make sure Clang is based on LLVM and built with binutils in it, or compilation will fail."
        echo -e ""
        echo -e "Place the clang link here"
        read -p "Enter Clang URL's: " URL
        echo -e ""
        echo -e "Cloning $URL"
        git clone --quiet --depth=1 "$URL" tc-clang
    fi
    if [ $choice = "4" ]; then
        exit 1
    fi
fi

# Main Environment
export ARCH=arm64
export SUBARCH=arm64
export pack=$(pwd)/anykernel-3
export github_name=$(git config user.name)
export github_email=$(git config user.email)
export parse_branch=$(git rev-parse --abbrev-ref HEAD)
export kernel_img=$(pwd)/out/arch/arm64/boot/Image.gz-dtb

# GitHub Config
if [ -z $github_name ] && [ -z $github_email ]; then
    echo -e "Username & empty email, please enter it below here!"
    read -p "Enter username: " USER
    read -p "Enter email: " EMAIL
    git config --global user.name "$USER"
    git config --global user.email "$EMAIL"
fi

clear

while true; do
echo -e ""
echo -e "⚠️ READ THIS BEFORE USING THIS SCRIPT"
echo -e ""
echo -e "This is a script to build an Android kernel (ARM64) on Linux (especially Ubuntu & Debian)."
echo -e "This script was built and tested on Linux 18.04 LTS and everything went well. I made this script"
echo -e "for personal purposes, and it is not recommended for everyone to use, But it's free to use."
echo -e "I made this script inspired by @Krypton A.K.A Dimas Bagus Prayoga to simplify the kernel making"
echo -e "process. (Original Script -> https://github.com/Kry9toN/Scripts)"
echo -e ""
echo -e "OK! let's start to building android kernel now!"
echo -e ""
echo -e "\n[1] Build an android Kernel"
echo -e "[2] Cleanup source"
echo -e "[3] Create flashable zip"
echo -e "[4] Changing compiler"
echo -e "[5] Exit"
echo -ne "\n(i) Please enter a choice[1-5]: "
read choice

# Choice 1
if [ $choice = "1" ]; then
    echo -e ""
    echo -e "Enter the name of your defconfig"
    read -p "Enter defconfig: " DEFCONFIG
    # if user does not set defconfig
    if [[ -z $DEFCONFIG ]]; then
        echo -e " Please!! enter your defconfig name first!"
      exit 1
    fi
    echo -e "##-------------------------------##-------------------------------##"
    echo -e ""
    echo -ne "                            BUILD STARTED!                          "
    echo -e ""
    echo -e "##-------------------------------##-------------------------------##"
    export LD_LIBRARY_PATH=$(pwd)/tc-clang/bin/../lib:$PATH
    make ARCH=arm64 O=out "$DEFCONFIG" && \
    PATH=$(pwd)/tc-clang/bin:$PATH \
    make -j$(nproc) O=out \
    ARCH=arm64 \
    AR=llvm-ar \
    CC=clang \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
    NM=llvm-nm \
    OBJCOPY=llvm-objcopy \
    OBJDUMP=llvm-objdump \
    STRIP=llvm-strip 2>&1| tee Log-$(TZ=Asia/Jakarta date +'%d%m%y').log
    if ! [[ -f "$kernel_img" ]]; then
        grep -iE 'not|empty|in file|waiting|crash|error|fail|fatal' "$(echo *.log)" &> "trimmed_log.txt"
        rm -rf Log*.log
        echo -e "##-------------------------------##-------------------------------##"
        echo -e ""
        echo -ne "                            BUILD FAILED!                           "
        echo -e ""
        echo -e "##-------------------------------##-------------------------------##"
      exit 1
    fi
    rm -rf Log*.log
    echo -e "##-------------------------------##-------------------------------##"
    echo -e ""
    echo -ne "                            BUILD SUCCESS!                          "
    echo -e ""
    echo -e "##-------------------------------##-------------------------------##"
fi

# Choice 2
if [ $choice = "2" ]; then
    echo -e "
    echo -e "##-------------------------------##-------------------------------##"
    echo -e ""
    echo -ne "                    CLEAN-UP KERNEL DIRECTORY                       "
    echo -e ""
    echo -e "##-------------------------------##-------------------------------##"
    make O=out clean &>/dev/null
    make mrproper &>/dev/null
    rm -rf out/* trimm*.txt anykernel-3/zImage anykernel-3/$(echo *.zip)
    echo -e "##-------------------------------##-------------------------------##"
    echo -e ""
    echo -ne "                              SUCCESS!                              "
    echo -e ""
    echo -e "##-------------------------------##-------------------------------##"
fi

# Choice 3
if [ $choice = "3" ]; then
    echo -e ""
    echo -e "##-------------------------------##-------------------------------##"
    echo -e ""
    echo -ne "                      CREATING FLASHABLE ZIP                        "
    echo -e ""
    echo -e "##-------------------------------##-------------------------------##"
    cd "$pack"
    make clean &>/dev/null
    echo -e "Checking your image.gz-dtb..."
    sleep 2
    if ! [[ -f "$kernel_img" ]]; then
          echo -e "Image.gz-dtb Not Found!"
          sleep 1
          echo -e "Aborting process..."
      else
          mv "$kernel_img" $pack/zImage
          zip -r9 kernel.zip * &>/dev/null
          echo -e "##-------------------------------##-------------------------------##"
          echo -e ""
          echo -ne "                             SUCCESS!!                             "
          echo -e ""
          echo -e "##-------------------------------##-------------------------------##"
      fi
    echo "successful creating zip, look at the zip at anykernel-3/kernel.zip"
    sleep 5
    cd ~/
fi

# Choice 4
if [ $choice = "4" ]; then
    clear
    unset URL
    echo -e ""
    echo -e "⚠️ Make sure Clang is based on LLVM and built with binutils in it, or compilation will fail"
    echo -e ""
    echo -e "Place the compiler link here"
    read -p "Enter Clang URL's: " URL
    if [ -z $URL ]; then
        echo -e "Changing Compiler failed!"
        echo -e "Please enter the link correctly"
   else
        echo -e "Cleaning old compiler...."
        rm -rf tc-clang
        sleep 2
        echo -e "Cloning new compiler..."
        git clone --quiet --depth=1 "$URL" tc-clang
        toolchain_ver=$($(pwd)/tc-clang/bin/clang --version | head -n 1)
        echo "Track compiler to -> $toolchain_ver"
        sleep 5
    fi
fi

# Choice 5
if [ $choice = "5" ]; then
    clear
    exit
fi
done

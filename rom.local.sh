#!/usr/bin/env bash
# Ubuntu 18.04 - Simple rom build script | Bahasa Indonesia 🇮🇩
# Copyright (C) 2019, 2020, Raphielscape (@raphielscape)
# Copyright (C) 2018, 2019, Akhil Narang (@akhilnarang)
# Copyright (C) 2020, Mhmmdfdlyas (@fadlyas07)

[[ ! -d "$(pwd)/telegram" ]] && git clone --depth=1 https://github.com/fabianonline/telegram.sh telegram

export github_name=$(git config user.name)
export github_email=$(git config user.email)

COMMON_DEPENDENCIES="jq sshpass"
if [ "$(command -v apt-get)" != "" ]; then
    sudo apt-get install -y $COMMON_DEPENDENCIES
else
    echo "Distronya tidak mendukung, tolong install dependencies sendiri: sudo apt install -y $COMMON_DEPENDENCIES"
fi

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

# GitHub Config
if [ -z $github_name ] && [ -z $github_email ]; then
    echo -e "Sayang... biasain set username git sama emailnya, gblk!"
    read -p "Masukin username: " USER
    read -p "Masukin email: " EMAIL
    git config --global user.name "$USER"
    git config --global user.email "$EMAIL"
fi

# Regenerate ssh key for sf
ssh-keyscan frs.sourceforge.net >> ~/.ssh/known_hosts

# print warning for everyone
clear
echo -e ""
echo -e "⚠️ Hati - Hati dan teliti OK!"
echo -e ""

while true; do
# Main Environment
ccache -M 50G
export ARCH=arm64
export SUBARCH=arm64
export USE_CCACHE=1
export TELEGRAM_ID="-1001323865672"
export TELEGRAM_TOKEN="1239494557:AAGhiG4ZcBq31-lGgB4u7cy3W_zJ1u8FN9k"
export CCACHE_COMPRESS=1
export WITHOUT_CHECK_API=true
export CCACHE_EXEC=/usr/bin/ccache

echo -e ""
echo -e "\n[1] Build rom"
echo -e "[2] Bersihkan distro"
echo -e "[3] Upload sourceforge"
echo -e "[4] Dah lah"
echo -ne "\n(i) Pilih salah satu ajg [1-5]: "
read choice

# Choice 1
if [ $choice = "1" ]; then
    echo -e ""
    echo -e "Pastikan semuanya sudah siap"
    echo -e ""
    if [[ -z "$BUILD" ]]; then
        echo ""
        echo -e "Misal 'UNOFFICIAL' gatau sih work atau engga :v"
        read -p "Masukin tipe build: " BUILD
        export CUSTOM_BUILD_TYPE=$BUILD
    else
        echo -e "Build tipe saat ini $BUILD"
    fi
    build_start=$(date +"%s")

    . build/envsetup.sh

    if [[ -z "$CMD" ]]; then
        echo ""
        echo -e "Masukin CMD lunch, misal 'lunch ios13_rova-userngebug'"
        read -p "Masukin Lunch: " LUNCH
        export CMD=$LUNCH
        command "$LUNCH"
    fi

    tg_send_message "<code>$(echo $CMD) dimulai! ...</code>"

    tg_send_message "
👤 : <a href='https://github.com/$github_name'>@$github_name</a>
⏰ : $(date | cut -d' ' -f4) $(date | cut -d' ' -f5) $(date | cut -d' ' -f6)
📆 : $(TZ=Asia/Jakarta date +'%a, %d %B %G')
🏫 : Started on $(hostname)"

    if [[ -z $GAS ]]; then
        echo -e ""
        echo -e "Masukin CMD build, misal 'mka bacon'"
        read -p "Masukin mka: " MKAA
        export GAS=$MKAA
        command "$GAS" 2>&1| tee build.rom.log
    fi

    if ! [[ -e out/target/product/"$(echo r*)"/"$(echo *-*2020*.zip)" ]]; then
        build_end=$(date +"%s")
        build_diff=$(($build_end - $build_start))
        grep -iE 'FAILED:' "$(echo build.rom.log)" &> "trimmed_log.txt"
        send_to_dogbin=$(echo https://del.dog/$(jq -r .key <<< $(curl -sf --data-binary "$(cat $(echo trimmed_log.txt))" https://del.dog/documents)))
        raw_send_to_dogbin=$(echo https://del.dog/raw/$(jq -r .key <<< $(curl -sf --data-binary "$(cat $(echo trimmed_log.txt))" https://del.dog/documents)))
        curl -F document=@$(echo build.rom.log) "https://api.telegram.org/bot"$TELEGRAM_TOKEN"/sendDocument" -F chat_id="$TELEGRAM_ID" -F caption="
        ⏰ : $(date | cut -d' ' -f4) $(date | cut -d' ' -f5) $(date | cut -d' ' -f6)
        🔗 : $send_to_dogbin
        🗒️ : $raw_send_to_dogbin
        ⌛ : $(($build_diff / 60)) menit dan $(($build_diff % 60)) detik."
    else
        rm -rf $(pwd)/out/target/product/"$(echo r*)"/"$(echo ota*.zip)"
        build_end=$(date +"%s")
        build_diff=$(($build_end - $build_start))
        tg_send_message "<b>SELAMAT GAN BUILD SUKSES!</b>"
        curl -F document=@$(echo build.rom.log) "https://api.telegram.org/bot"$TELEGRAM_TOKEN"/sendDocument" -F chat_id="$TELEGRAM_ID" -F caption="
        ⏰ : $(date | cut -d' ' -f4) $(date | cut -d' ' -f5) $(date | cut -d' ' -f6)
        ⌛ : $(($build_diff / 60)) menit dan $(($build_diff % 60)) detik."
    fi
  echo -e "Build sukses gan!"
fi

if [ $choice = "2" ]; then
    make O=out clean &>/dev/null
    make mrproper &>/dev/null
    rm -rf out *.log *.txt
fi

if [ $choice = "3" ]; then
    clear
    echo ""
    echo -e "upload rom ke sourceforge"
    echo ""
    echo -e "pastikan lu udah selesai compile"
    echo -e ""
    rm -rf $(pwd)/out/target/product/"$(echo r*)"/"$(echo ota*.zip)"
    if [[ -z $USER ]]; then
        echo ""
        echo "Masukin username sf mu"
        read -p "Masukkan username: " CI_SF_USER
        export USER=$CI_SF_USER
    fi
    if [[ -z $PW ]]; then
        echo ""
        echo "Masukin password sf mu"
        read -p "Masukkan password: " CI_SF_PASS
        export PW=$CI_SF_PASS
    fi
    if [[ -z $DIR ]]; then
        echo -e ""
        echo "Kasih tau dir sf mu, langsung ketik '{project}/blablabla/blavla'"
        echo "Gausah pake '/home/frs/project' lagi"
        read -p "Masukkin dir nya: " DIR_SF
        export DIR=$DIR_SF
    fi
    export READ_ZIP=$(echo *2020*.zip)
    export FILEPATH=$(find $(pwd)/out/target/product/"$(echo r*)"/"$READ_ZIP")
    sshpass -p '$PW' scp "$FILEPATH" $USER@frs.sourceforge.net:/home/frs/project/"$DIR"
    tg_send_message "<code>Mengupload ke sourceforge...</code>"
    tg_send_message "
<b>Upload Sukses!!</b>
🖇️ : $(echo https://sourceforge.net/projects/$DIR/files/$FILEPATH/download)"
fi

if [ $choice = "4" ]; then
    exit 1
fi
done

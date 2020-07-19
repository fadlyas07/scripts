#!/usr/bin/env bash
# Ubuntu 18.04 - Simple rom build script | Bahasa Indonesia 🇮🇩
# Copyright (C) 2019, 2020, Raphielscape (@raphielscape)
# Copyright (C) 2018, 2019, Akhil Narang (@akhilnarang)
# Copyright (C) 2020, Mhmmdfdlyas (@fadlyas07)

[[ ! -d "$(pwd)/telegram" ]] && git clone --depth=1 https://github.com/fabianonline/telegram.sh telegram

export github_name=$(git config user.name)
export github_email=$(git config user.email)

COMMON_DEPENDENCIES="jq"
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
export TELEGRAM_ID="784548477"
export TELEGRAM_TOKEN="1239494557:AAGhiG4ZcBq31-lGgB4u7cy3W_zJ1u8FN9k"
export CCACHE_COMPRESS=1
export WITHOUT_CHECK_API=true
export CCACHE_EXEC=/usr/bin/ccache

echo -e ""
echo -e "\n[1] Build rom"
echo -e "[2] Bersihkan distro"
echo -e "[3] Dah lah"
echo -ne "\n(i) Pilih salah satu ajg [1-3]: "
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
        command "$CMD"
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
        command "$GAS" 2>&1| tee build.log
    fi

DEVICE_ROM_DIR=$(echo *)
FILE_IN_DIR=$(echo *-*20*.zip)

    if ! [[ -e "$(pwd)/out/target/product/$DEVICE_ROM_DIR/$FILE_IN_DIR" ]]; then
        build_end=$(date +"%s")
        build_diff=$(($build_end - $build_start))
        grep -iE 'ninja:|FAILED:' "$(echo build.log)" &> "trimmed_log.txt"
        send_to_dogbin=$(echo https://del.dog/$(jq -r .key <<< $(curl -sf --data-binary "$(cat $(echo trimmed_log.txt))" https://del.dog/documents)))
        raw_send_to_dogbin=$(echo https://del.dog/raw/$(jq -r .key <<< $(curl -sf --data-binary "$(cat $(echo trimmed_log.txt))" https://del.dog/documents)))
        curl -F document=@$(echo build.rom.log) "https://api.telegram.org/bot"$TELEGRAM_TOKEN"/sendDocument" -F chat_id="$TELEGRAM_ID" -F caption="
⏰ : $(date | cut -d' ' -f4) $(date | cut -d' ' -f5) $(date | cut -d' ' -f6)
🔗 : $send_to_dogbin
🗒️ : $raw_send_to_dogbin
⌛ : $(($build_diff / 60)) menit dan $(($build_diff % 60)) detik."
    else
        rm -rf $(pwd)/$HOME_DIR/out/target/product/"$(echo *)"/"$(echo ota*.zip)"
        build_end=$(date +"%s")
        build_diff=$(($build_end - $build_start))
        tg_send_message "<b>BUILD SUKSES!...!</b>"
        curl -F document=@$(echo build.rom.log) "https://api.telegram.org/bot"$TELEGRAM_TOKEN"/sendDocument" -F chat_id="$TELEGRAM_ID" -F caption="
💿 : $(echo $CMD)
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
    exit 1
fi
done

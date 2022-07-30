#!/usr/bin/env bash
# Copyright (C) 2020 Muhammad Fadlyas (fadlyas07)
# SPDX-License-Identifier: GPL-3.0-or-later

tg() {
    ACTION=${1} EXTRA=${2} CHANNEL_ID=${3}
    URL="https://api.telegram.org/bot${TELEGRAM_BOT}"
    case "$ACTION" in
        msg)
            curl \
            -d chat_id=$CHANNEL_ID \
            -d "parse_mode=html" \
            -d "disable_web_page_preview=true" \
            -X POST $URL/sendMessage \
            -d text="$(
                for POST in "${EXTRA}"; do
                    echo "${POST}";
                done
            )"
            ;;
        file)
            curl \
            -F chat_id=$CHANNEL_ID \
            -F "parse_mode=html" \
            -F "disable_web_page_preview=true" \
            -F document=@$EXTRA $URL/sendDocument \
            -F caption="$(
                for caption in "${4}"; do
                    echo "${caption}";
                done
            )"
            ;;
        stkr)
            curl \
            -d chat_id=$CHANNEL_ID \
            -s -X POST $URL/sendSticker \
            -d sticker="${1}"
        ;;
    esac
}
notif() { echo -e "\e[1;32m$*\e[0m"; }
error() { echo -e "\e[1;41m$*\e[0m"; }
die() { command exit "${1}"; }

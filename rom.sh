#!/usr/bin/env bash
# Copyright (C) 2022 Muhammad Fadlyas (fadlyas07)
# SPDX-License-Identifier: GPL-3.0-or-later

export DEVICE=
export ROM_NAME=
export BRANCH_MANIFEST=
export ROM_CODENAME=
export TG_TOKEN=
export CHAT_ID=
export GH_TOKEN=
export BUILDTYPE=
export LunchCommand="lunch XX_${DEVICE}-userdebug"
export BuildCommand=
export GitHubUsername="greenforce-project"
export GitHubRepoRelease="android_release"
export GitHubReleaseTag="release"

if [[ "$DEVICE" == "" ]]; then
    echo "Environment for 'DEVICE' is empty, please set it by editing script!"
    exit 1
elif [[ "$ROM_NAME" == "" ]]; then
    echo "Environment for 'ROM_NAME' is empty, please set it by editing script!"
    exit 1
elif [[ "$BRANCH_MANIFEST" == "" ]]; then
    echo "Environment for 'BRANCH_MANIFEST' is empty, please set it by editing script!"
    exit 1
elif [[ "$ROM_CODENAME" == "" ]]; then
    echo "Environment for 'ROM_CODENAME' is empty, please set it by editing script!"
    exit 1
elif [[ "$TG_TOKEN" == "" ]]; then
    echo "Environment for 'TG_TOKEN' is empty, please set it by editing script!"
    exit 1
elif [[ "$CHAT_ID" == "" ]]; then
    echo "Environment for 'CHAT_ID' is empty, please set it by editing script!"
    exit 1
elif [[ "$GH_TOKEN" == "" ]]; then
    echo "Environment for 'GH_TOKEN' is empty, please set it by editing script!"
    exit 1
elif [[ "$BUILDTYPE" == "" ]]; then
    echo "Environment for 'BUILDTYPE' is empty, please set it by editing script!"
    exit 1
elif [[ "$LunchCommand" == "" ]]; then
    echo "Environment for 'LunchCommand' is empty, please set it by editing script!"
    exit 1
elif [[ "$BuildCommand" == "" ]]; then
    echo "Environment for 'BuildCommand' is empty, please set it by editing script!"
    exit 1
else
    echo "Trust me everything's gonna be alright!"
fi

export CDIR=$(pwd)
export OUT="${CDIR}/out/target/product/${DEVICE}"
export DISTRO=$(source /etc/os-release && echo "${PRETTY_NAME}")
if [[ -d "${CDIR}/ccache" ]]; then
    CCACHE_DIR="${CDIR}/ccache"
else
    CCACHE_DIR="${HOME}/.ccache"
fi
export CCACHE_DIR
export TZ=":Asia/Jakarta"

export TERM=xterm
red=$(tput setaf 1)             #  red
grn=$(tput setaf 2)             #  green
blu=$(tput setaf 4)             #  blue
cya=$(tput setaf 6)             #  cyan
txtrst=$(tput sgr0)             #  Reset

timeStart() {
    DATELOG=$(date "+%H%M-%d%m%Y")
    BUILD_START=$(date +"%s")
    DATE=$(date)
}

timeEnd() {
	BUILD_END=$(date +"%s")
	DIFF=$(($BUILD_END - $BUILD_START))
}

telegram_curl() {
    local ACTION=${1}
    shift
    local HTTP_REQUEST=${1}
    shift
    if [[ "${HTTP_REQUEST}" != "POST_FILE" ]]; then
        curl -s -X "${HTTP_REQUEST}" "https://api.telegram.org/bot$TG_TOKEN/$ACTION" "$@" | jq .
    else
        curl -s "https://api.telegram.org/bot$TG_TOKEN/$ACTION" "$@" | jq .
    fi
}

telegram_main() {
    local ACTION=${1}
    local HTTP_REQUEST=${2}
    local CURL_ARGUMENTS=()
    while [[ "${#}" -gt 0 ]]; do
        case "${1}" in
            --animation | --audio | --document | --photo | --video )
                local CURL_ARGUMENTS+=(-F $(echo "${1}" | sed 's/--//')=@"${2}")
                shift
                ;;
            --* )
                if [[ "$HTTP_REQUEST" != "POST_FILE" ]]; then
                    local CURL_ARGUMENTS+=(-d $(echo "${1}" | sed 's/--//')="${2}")
                else
                    local CURL_ARGUMENTS+=(-F $(echo "${1}" | sed 's/--//')="${2}")
                fi
                shift
                ;;
        esac
        shift
    done
    telegram_curl "${ACTION}" "${HTTP_REQUEST}" "${CURL_ARGUMENTS[@]}"
}

telegram_curl_get() {
    local ACTION=${1}
    shift
    telegram_main "${ACTION}" GET "$@"
}

telegram_curl_post() {
    local ACTION=${1}
    shift
    telegram_main "${ACTION}" POST "$@"
}

telegram_curl_post_file() {
    local ACTION=${1}
    shift
    telegram_main "${ACTION}" POST_FILE "$@"
}

tg_send_message() {
    telegram_main sendMessage POST "$@"
}

tg_edit_message_text() {
    telegram_main editMessageText POST "$@"
}

tg_send_document() {
    telegram_main sendDocument POST_FILE "$@"
}

progress() {
    echo "BOTLOG: Build tracker process is running..."
    sleep 5;

    while [ 1 ]; do
        if [[ ${retVal} -ne 0 ]]; then
            exit ${retVal}
        fi

        # Get latest percentage
        PERCENTAGE=$(cat $BUILDLOG | tail -n 1 | awk '{ print $2 }')
        NUMBER=$(echo ${PERCENTAGE} | sed 's/[^0-9]*//g')

        # Report percentage to the $CHAT_ID
        if [[ "${NUMBER}" != "" ]]; then
            if [[ "${NUMBER}" -le  "99" ]]; then
                if [[ "${NUMBER}" != "${NUMBER_OLD}" ]] && [[ "$NUMBER" != "" ]] && ! cat $BUILDLOG | tail  -n 1 | grep "glob" > /dev/null && ! cat $BUILDLOG | tail  -n 1 | grep "including" > /dev/null && ! cat $BUILDLOG | tail  -n 1 | grep "soong" > /dev/null && ! cat $BUILDLOG | tail  -n 1 | grep "finishing" > /dev/null; then
                echo -e "BOTLOG: Percentage changed to ${NUMBER}%"
                    build_message "🛠️ Building... ${NUMBER}%" > /dev/null
                fi
            NUMBER_OLD=${NUMBER}
            fi
            if [[ "$NUMBER" -eq "99" ]] && [[ "$NUMBER" != "" ]] && ! cat $BUILDLOG | tail  -n 1 | grep "glob" > /dev/null && ! cat $BUILDLOG | tail  -n 1 | grep "including" > /dev/null && ! cat $BUILDLOG | tail  -n 1 | grep "soong" > /dev/null && ! cat $BUILDLOG | tail -n 1 | grep "finishing" > /dev/null; then
                echo "BOTLOG: Build tracker process ended"
                break
            fi
        fi

        sleep 5
    done
    return 0
}
timeStart
build_message() {
	if [[ "$CI_MESSAGE_ID" = "" ]]; then
CI_MESSAGE_ID=$(tg_send_message --chat_id "$CHAT_ID" --text "<b>=== Starting Build ${ROM_NAME} ===</b>
<b>Codename:</b> <code>${ROM_CODENAME} (${BRANCH_MANIFEST})</code>
<b>Device:</b> <code>${DEVICE}</code>
<b>Build type:</b> <code>${BUILDTYPE}</code>
<b>Job:</b> <code>$(nproc --all) Paralel processing</code>
<b>Running on:</b> <code>$DISTRO</code>
<b>Started at</b> <code>$DATE</code>

<b>Status:</b> <code>${1}</code>" --parse_mode "html" | jq .result.message_id)
	else
tg_edit_message_text --chat_id "$CHAT_ID" --message_id "$CI_MESSAGE_ID" --text "<b>=== Starting Build ${ROM_NAME} ===</b>
<b>Codename:</b> <code>${ROM_CODENAME} (${BRANCH_MANIFEST})</code>
<b>Device:</b> <code>${DEVICE}</code>
<b>Build type:</b> <code>${BUILDTYPE}</code>
<b>Job:</b> <code>$(nproc --all) Paralel processing</code>
<b>Running on:</b> <code>$DISTRO</code>
<b>Started at</b> <code>$DATE</code>

<b>Status:</b> <code>${1}</code>" --parse_mode "html"
	fi
}

statusBuild() {
    if [[ $retVal -eq 8 ]]; then
        build_message "Build Aborted 😡 with Code Exit ${retVal}.

Total time elapsed: $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds."
        tg_send_message --chat_id "$CHAT_ID" --text "Build Aborted 💔 with Code Exit ${retVal}.
Sudah kubilang yang teliti 😡"
        echo "Build Aborted"
        tg_send_document --chat_id "$CHAT_ID" --document "$BUILDLOG" --reply_to_message_id "$CI_MESSAGE_ID"
        LOGTRIM="$CDIR/out/log_trimmed.log"
        sed -n '/FAILED:/,//p' $BUILDLOG &> $LOGTRIM
        tg_send_document --chat_id "$CHAT_ID" --document "$LOGTRIM" --reply_to_message_id "$CI_MESSAGE_ID"
        exit $retVal
    fi
    if [[ $retVal -eq 141 ]]; then
        build_message "Build Aborted 👎 with Code Exit ${retVal}, See log.

Total time elapsed: $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds."
        tg_send_message --chat_id "$CHAT_ID_SECOND" --text "Build Aborted 💔 with Code Exit ${retVal}."
        echo "Build Aborted"
        tg_send_document --chat_id "$CHAT_ID" --document "$BUILDLOG" --reply_to_message_id "$CI_MESSAGE_ID"
        LOGTRIM="$CDIR/out/log_trimmed.log"
        sed -n '/FAILED:/,//p' $BUILDLOG &> $LOGTRIM
        tg_send_document --chat_id "$CHAT_ID" --document "$LOGTRIM" --reply_to_message_id "$CI_MESSAGE_ID"
        exit $retVal
    fi
    if [[ $retVal -ne 0 ]]; then
        build_message "Build Error 💔 with Code Exit ${retVal}, See log.

Total time elapsed: $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds."
        tg_send_message --chat_id "$CHAT_ID_SECOND" --text "Build Error 💔 with Code Exit ${retVal}."
        echo "Build Error"
        tg_send_document --chat_id "$CHAT_ID" --document "$BUILDLOG" --reply_to_message_id "$CI_MESSAGE_ID"
        LOGTRIM="$CDIR/out/log_trimmed.log"
        sed -n '/FAILED:/,//p' $BUILDLOG &> $LOGTRIM
        tg_send_document --chat_id "$CHAT_ID" --document "$LOGTRIM" --reply_to_message_id "$CI_MESSAGE_ID"
        exit $retVal
    fi
    build_message "Build success ❤️"
    tg_send_message --chat_id "$CHAT_ID" --text "LOL WTF' Build Success Mate ❤️
Congratsss I'm Happy for you!!"
}

echo -e ${blu}"CCACHE is enabled for this build"${txtrst}
export CCACHE_EXEC=$(which ccache)
export USE_CCACHE=1
ccache -M 50G
BUILDLOG="${CDIR}/out/${ROM_NAME}-${DEVICE}-${DATELOG}.log"
build_message "Prepare for build..."
sleep 2
. build/envsetup.sh
build_message "${LunchCommand}"
command "$LunchCommand"
mkfifo reading
tee "$BUILDLOG" < reading &
if [[ -d "$OUT" ]]; then
    build_message "Here we go again...🔥"
else
    build_message "Staring bro...🔥"
fi
sleep 2
build_message "🛠️ Building..."
progress &
command "$BuildCommand" > reading

retVal=$?
timeEnd
statusBuild
tg_send_document --chat_id "$CHAT_ID" --document "$BUILDLOG" --reply_to_message_id "$CI_MESSAGE_ID"

export FILENAME=$(cd "${OUT}" && find *${BUILDTYPE}*.zip)
export FILEPATH="${OUT}/${FILENAME}"
if [[ -e "${FILEPATH}" ]]; then
    build_message "Build Success ❤️"
    [[ ! -e "$(pwd)/gh-release" ]] && curl -Lo "$(pwd)/gh-release" https://github.com/fadlyas07/scripts/raw/master/github/github-release
    chmod +x "$(pwd)/gh-release"
    build_message "Uploading ${FILENAME}..."
    build_upload() {
        ./gh-release upload \
            --security-token "$GH_TOKEN" \
            --user "${GitHubUsername}" \
            --repo "${GitHubRepoRelease}" \
            --tag "${GitHubReleaseTag}" \
            --name "${FILENAME}" \
            --file "${FILEPATH}" && echo "succes bro!"
    }

    if [[ $(build_upload) == "succes bro!" ]]; then
        LINK=$(echo "https://github.com/greenforce-project/android_release/releases/download/release/${FILENAME}")
        build_message "Build Complete!
        tg_send_message --chat_id "$CHAT_ID" --reply_to_message_id "$CI_MESSAGE_ID" --text "Link: <code>${LINK}</code>" --parse_mode "html"
    else
        build_message "Uploading failed..."
    fi
else
    build_message "Something went wrong to track files..."
fi

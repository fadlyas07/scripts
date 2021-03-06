#!/usr/bin/env bash

function die() {
    echo
    echo -e "\033[01;31m${1}\033[0m"
    echo
    exit 1
}

REPOS=( "fw-api" "qcacld-3.0" "qca-wifi-host-cmn" )
SUBFOLDER=drivers/staging
URL=https://source.codeaurora.org/quic/la/platform/vendor/qcom-opensource/wlan/

while [[ ${#} -ge 1 ]]; do
    case ${1} in
        "-i"|"--init") INIT=true ;;
        "-t"|"--tag") shift; TAG=${1} ;;
        "-u"|"--update") UPDATE=true ;;
    esac
    shift
done
[[ -n ${INIT} && -n ${UPDATE} ]] && die "Both init and update were specified!"
[[ -z ${TAG} ]] && die "No tag was specified!"

for REPO in "${REPOS[@]}"; do
    echo "${REPO}"
    if ! git ls-remote --exit-code "${REPO}" &>/dev/null; then
        git remote add "${REPO}" "${URL}${REPO}"
    fi
    git fetch "${REPO}" "${TAG}"
    if [[ -n ${INIT} ]]; then
        git merge --allow-unrelated-histories -s ours --no-commit FETCH_HEAD
        git read-tree --prefix="${SUBFOLDER}/${REPO}" -u FETCH_HEAD
        git commit --gpg-sign --signoff --no-edit -m "staging: ${REPO}: Checkout at ${TAG}"
    elif [[ -n ${UPDATE} ]]; then
        GIT_MAJOR_VERSION=$(git --version | head -n 1 | cut -d . -f 1 | awk '{print $3}')
        GIT_MINOR_VERSION=$(git --version | head -n 1 | cut -d . -f 2)
        [[ ${GIT_MAJOR_VERSION} -gt 2 ]] || [[ ${GIT_MAJOR_VERSION} -eq 2 && ${GIT_MINOR_VERSION} -ge 15 ]] && SIGNOFF=true
        git merge --gpg-sign${SIGNOFF:+" --signoff"} --no-edit -m "staging: ${REPO}: Merge tag '${TAG}' into $(git rev-parse --abbrev-ref HEAD)" \
              -X subtree="${SUBFOLDER}/${REPO}" FETCH_HEAD
    fi
done
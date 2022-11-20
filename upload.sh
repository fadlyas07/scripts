#!/usr/bin/env bash
# Copyright (C) 2022 Muhammad Fadlyas (fadlyas07)
# SPDX-License-Identifier: GPL-3.0-or-later

echo "PERINGATAN: Pastikan setidaknya ada 1 file dan 1 commit dalam repository Anda."
if [[ $# -eq 0 ]]; then
    echo "Tidak ada parameter yang ditentukan!"
    exit 1
fi

# Cara Menggunakan Skrip
# 1. (Jika belum) Unduh skrip menggunakan perintah `wget https://github.com/fadlyas07/scripts/raw/master/upload.sh`
# 2. Edit skrip sesuai dengan apa yang dibutuhkan
# 3. Jalankan skrip menggunakan perintah `bash upload.sh <Tempat file> <NamaFile>`
#    contoh: bash upload.sh "/home/greenforce/syberia/out/target/product/chime/Syberia-blablabla.zip" "Syberia-blablabla.zip"

# Lingkungan Utama -> EDIT DISINI <-
export UsernameGitHub=     # Username akun GitHub / Organisasi Anda, contoh -> 'fadlyas07'
export TokenGithub=         # Token GitHub akun Anda, biasanya di mulai dengan -> 'gh_xxxxxx'
export TargetRilisRepository=        # Nama repository yang ingin Anda gunakan sebagai tempat mengunggah file, contoh -> 'android-release'
export TargetRilisTag=release    # Nama tag dalam repository Anda

# JANGAN DIUBAH!
export FolderSaatIni=$(pwd)
export TempatFile=${1} # Ini adalah "PATH" atau jalan dimana skrip bisa menemukan file Anda, contoh '/home/greenforce/syberia/out/target/product/chime/Syberia-blablabla.zip'
export NamaFile=${2} # Ini adalah nama dari file yang ingin Anda unggah, contoh 'Syberia-blablabla.zip' (nama file dapat dirubah, pastikan ekstensi file tetap sama)
export PerkiraanUkuran=$(echo "$(du -sh ${TempatFile} | cut -c 1-4 | sed 's/	//g')B")

GitHubRilis="${FolderSaatIni}/github-release"
if ! [[ -e "${GitHubRilis}" ]]; then
    curl -Lo "${FolderSaatIni}/github-release" https://github.com/fadlyas07/scripts/raw/master/github/github-release
elif [[ -e "${GitHubRilis}" ]]; then
    echo "File 'github-release' sudah ada!"
else
    echo "Terjadi kesalahan yang tidak diketahui, tolong cek script anda!"
    exit 0
fi
chmod +x "${GitHubRilis}"

if [[ -e "${TempatFile}" && -e "${GitHubRilis}" ]]; then
    echo "Mengunggah..."
    BuatRilisTag() {
        ./github-release release \
            --security-token "${TokenGithub}" \
            --user "${UsernameGitHub}" \
            --repo "${TargetRilisRepository}" \
            --tag "${TargetRilisTag}" \
            --name "${TargetRilisTag}" \
            --description "Release tag for my awesome files!" || echo "Tag sudah ada!"
    }   
    UnggahFile() {
        ./github-release upload \
                --security-token "${TokenGithub}" \
                --user "${UsernameGitHub}" \
                --repo "${TargetRilisRepository}" \
                --tag "${TargetRilisTag}" \
                --name "${NamaFile}" \
                --file "${TempatFile}" || echo "GAGAL Mengupload file, periksa kembali!"
    }
    if [[ $(BuatRilisTag) == "Tag sudah ada!" ]]; then
        if ! [[ -f "${GitHubRilis}" ]]; then
            echo "File github-release tidak ditemukan, tolong periksa kembali..." && exit
        else
            chmod +x "${GitHubRilis}"
            sleep 8s
            BuatRilisTag || echo "Tag sudah dibuat, lanjut mengunggah ${NamaFile}..."
        fi
    fi
    if [[ $(UnggahFile) == "GAGAL Mengupload file, periksa kembali!" ]]; then
        if ! [[ -f "${GitHubRilis}" ]]; then
            echo "File github-release tidak ditemukan, tolong periksa kembali..." && exit
        else
            chmod +x "${GitHubRilis}"
            sleep 8s
            UnggahFile || echo "gagal lagi, file tidak bisa di upload ke GitHub Release!" && exit
        fi
    fi
    echo "File sukses di unggah! file berukuran ${PerkiraanUkuran}
        
Link akan di tampilkan dalam 3 detik..."
    sleep 3s
    LINK="https://github.com/${UsernameGitHub}/${TargetRilisRepository}/releases/download/release/${NamaFile}"
    echo "Pengunggahan selesai!
        
NAMA FILE: ${NamaFile}
TEMPAT FILE: ${TempatFile}
UKURAN FILE: ${PerkiraanUkuran}
LINK: ${LINK}

"
    fi
else
    echo "File di ${TempatFile} tidak terdeteksi

Mohon periksa kembali!

"
    exit 1
fi

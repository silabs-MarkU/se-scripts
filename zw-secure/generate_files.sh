#!/bin/sh +x

BOOTLOADER_v1=${1}
BOOTLOADER_v2=${2}
APPLICATION=${3}
ENCRYPT_KEY=${4}
PRI_SIGN_KEY=${5}



DEVICE=EFR32ZG23B020F512IM40

commander.exe convert ${BOOTLOADER_v1} --secureboot --keyfile ${PRI_SIGN_KEY} --outfile bootloader-base-signed.hex
commander.exe convert ${BOOTLOADER_v2} --secureboot --keyfile ${PRI_SIGN_KEY} --outfile bootloader-upgraded-signed.hex
commander.exe convert ${APPLICATION} --secureboot --keyfile ${PRI_SIGN_KEY} --outfile application-signed.hex

commander.exe gbl create bootloader-upgrade.gbl --bootloader bootloader-upgraded-signed.hex --sign ${PRI_SIGN_KEY} --encrypt ${ENCRYPT_KEY} --compress lzma


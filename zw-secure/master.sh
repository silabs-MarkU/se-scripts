#!/bin/sh +x

WSTK_SERIAL=${1}
BOOTLOADER_v1=${2}
BOOTLOADER_v2=${3}
APPLICATION=${4}
ENCRYPT_KEY=${5}
PUB_SIGN_KEY=${6}
PRI_SIGN_KEY=${7}
USER_CONFIG=${8}



echo "Inputs to this script:"
echo "WSTK_SERIAL: You can get this from commander -v"
echo "Bootloader_v1: This is your desired bootloader with version X"
# This is based on SoC Internal Storage 512
# Update the Bootloader Core Component:
#	Enable Use Custom Bootloader Application Size : 278528 (0x0004_4000)
#	Change "Base address of bootloader upgrade image" : 327680 (0x0005_0000)
#	Also, optionally enable "Upgrade SE without using the staging area"

echo "Bootloader_v2: This is your desired bootloader with version X+1"
# As above, but in Bootloader Core Component, the bootloader version is incremented

echo "Application: This is your desired application"
echo "Encryption Key: Encryption key as a token"
echo "Public Sign Key: Public Sign Key as a token"
echo "Private Sign Key: Private Sign Key as a PEM"
echo "User Config: Should be set with only Secure Boot enabled"



DEVICE=EFR32ZG23B020F512IM40

commander.exe convert ${BOOTLOADER_v1} --secureboot --keyfile ${PRI_SIGN_KEY} --outfile bootloader-base-signed.hex
commander.exe convert ${BOOTLOADER_v2} --secureboot --keyfile ${PRI_SIGN_KEY} --outfile bootloader-upgraded-signed.hex
commander.exe convert ${APPLICATION} --secureboot --keyfile ${PRI_SIGN_KEY} --outfile application-signed.hex

commander.exe gbl create bootloader-upgrade.gbl --bootloader bootloader-upgraded-signed.hex --sign ${PRI_SIGN_KEY} --encrypt ${ENCRYPT_KEY} --compress lzma


commander.exe device masserase -s ${WSTK_SERIAL} -d ${DEVICE} 
commander.exe device reset -s ${WSTK_SERIAL} -d ${DEVICE}
commander.exe flash bootloader-base-signed.hex -s ${WSTK_SERIAL} -d ${DEVICE}
commander.exe flash application-signed.hex --serialno ${WSTK_SERIAL} --device ${DEVICE}
commander.exe flash --tokengroup znet --tokenfile ${ENCRYPT_KEY} --tokenfile ${PUB_SIGN_KEY} -s ${WSTK_SERIAL} -d ${DEVICE}
#commander.exe flash --patch 0x0FE00074:0x01:1 --device ${DEVICE}
#commander.exe flash --patch 0x0FE00004:0x00:1 --device ${DEVICE}
commander.exe device reset -s ${WSTK_SERIAL} -d ${DEVICE}

# get the DSK
dsk=`commander.exe tokendump --tokengroup znet --token MFG_ZW_QR_CODE -d ${DEVICE} | grep MFG_ZW_QR_CODE`
dsk=`echo ${dsk} | cut -c 30-69`
echo "DSK:" ${dsk}


commander.exe security writekey --sign ${PUB_SIGN_KEY}
commander.exe security writeconfig ${USER_CONFIG} --noprompt


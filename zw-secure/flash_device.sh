#!/bin/sh +x

WSTK_SERIAL=${1}
BOOTLOADER=${2}
APPLICATION=${3}
ENCRYPT_KEY=${4}
SIGN_KEY=${5}

DEVICE=EFR32ZG23B020F512IM40

commander.exe device masserase -s ${WSTK_SERIAL} -d ${DEVICE} 
commander.exe device reset -s ${WSTK_SERIAL} -d ${DEVICE}
commander.exe flash ${BOOTLOADER} -s ${WSTK_SERIAL} -d ${DEVICE}
commander.exe flash ${APPLICATION} --address 0x08006000 --serialno ${WSTK_SERIAL} --device ${DEVICE}
commander.exe flash --tokengroup znet --tokenfile ${ENCRYPT_KEY} --tokenfile ${SIGN_KEY} -s ${WSTK_SERIAL} -d ${DEVICE}
#commander.exe flash --patch 0x0FE00074:0x01:1 --device ${DEVICE}
#commander.exe flash --patch 0x0FE00004:0x00:1 --device ${DEVICE}
commander.exe device reset -s ${WSTK_SERIAL} -d ${DEVICE}

# get the DSK
dsk=`commander.exe tokendump --tokengroup znet --token MFG_ZW_QR_CODE -d ${DEVICE} | grep MFG_ZW_QR_CODE`
dsk=`echo ${dsk} | cut -c 30-69`
echo "DSK:" ${dsk}

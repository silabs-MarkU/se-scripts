#!/bin/sh +x

WSTK_SERIAL=${1}
DEVICE=${2:-EFR32ZG23B020F512IM40}
ENCRYPT_KEY=${3:-encryption_key.txt}
PUB_SIGN_KEY=${4:-sign_pubkey.pem}
PRI_SIGN_KEY=${5:-sign_privkey.pem}

COMMANDER=commander.exe

if [ -z "${WSTK_SERIAL}" ]
then
	echo "Inputs to this script:"
	echo "WSTK_SERIAL: You can get this from commander -v"
else	

	
	${COMMANDER} util keytotoken ${PUB_SIGN_KEY} --outfile sign_key.token

	# Program the device
	${COMMANDER} device masserase -s ${WSTK_SERIAL} -d ${DEVICE} 
	${COMMANDER} device reset -s ${WSTK_SERIAL} -d ${DEVICE}
	${COMMANDER} flash bootloader-base-signed.hex -s ${WSTK_SERIAL} -d ${DEVICE}
	${COMMANDER} flash application-signed.hex --serialno ${WSTK_SERIAL} --device ${DEVICE}
	${COMMANDER} flash --tokengroup znet --tokenfile ${ENCRYPT_KEY} --tokenfile sign_key.token -s ${WSTK_SERIAL} -d ${DEVICE}
	${COMMANDER} device reset -s ${WSTK_SERIAL} -d ${DEVICE}
	
	# get the DSK
	dsk=`${COMMANDER} tokendump --tokengroup znet --token MFG_ZW_QR_CODE -d ${DEVICE} | grep MFG_ZW_QR_CODE`
	dsk=`echo ${dsk} | cut -c 30-69`
	echo "DSK:" ${dsk}
	
	# Cleanup
	rm sign_key.token
	
fi


#!/bin/sh +x

WSTK_SERIAL=${1}
USER_CONFIG=${5}
DEVICE=${6:-EFR32ZG23B020F512IM40}
PUB_SIGN_KEY=${8:-sign_pubkey.pem}

COMMANDER=commander.exe

if [ -z "${USER_CONFIG}" ]
then
	echo "Inputs to this script:"
	echo "WSTK_SERIAL: You can get this from commander -v"
	echo "User Config: Should be set with only Secure Boot enabled. A default can be created with $COMMANDER security genconfig -o <filename> --nostore"
else	
	
	# Program OTP of the device
	${COMMANDER} security writekey --sign ${PUB_SIGN_KEY} --noprompt -s ${WSTK_SERIAL} -d ${DEVICE}
	${COMMANDER} security writeconfig --configfile ${USER_CONFIG} --noprompt -s ${WSTK_SERIAL} -d ${DEVICE}
	
fi


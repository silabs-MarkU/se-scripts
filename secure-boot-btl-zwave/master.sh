#!/bin/sh
#set -x

WSTK_SERIAL=${1}
BOOTLOADER_v1=${2}
BOOTLOADER_v2=${3}
APPLICATION=${4}
USER_CONFIG=${5}
DEVICE=${6:-empty}
ENCRYPT_KEY=${7:-encryption_key.txt}
PUB_SIGN_KEY=${8:-sign_pubkey.pem}
PRI_SIGN_KEY=${9:-sign_privkey.pem}

COMMANDER=commander.exe

# Check here input device

if [ "empty" = "$DEVICE" ]; then
	FIRST_FOUND_DEVICE="$(commander.exe device info -v | grep Part | cut -d ':' -f2 | cut -d ' ' -f2  | tr -d '\r')"

	while true; do
		read -p "Set found device $FIRST_FOUND_DEVICE as target (y/n)? " yn
		case $yn in
			[Yy]* ) break;;
			[Nn]* ) exit;;
			* ) echo "Please answer yes or no.";;
		esac
	done
fi

exit 0

if [ -z "${USER_CONFIG}" ]
then
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
	# I use the on/off switch example
	# Update the Z-Wave Core Component to US Long Range
	
	echo "User Config: Should be set with only Secure Boot enabled. A default can be created with $COMMANDER security genconfig -o <filename> --nostore"
else	

	# Generate the keys and key tokens
	if [ ! -f "${ENCRYPT_KEY}" ]; then
		${COMMANDER} util genkey --type aes-ccm --outfile ${ENCRYPT_KEY}
	fi
	
	if [ ! -f "${PRI_SIGN_KEY}" ]; then
		${COMMANDER} util genkey --type ecc-p256 --privkey ${PRI_SIGN_KEY} --pubkey ${PUB_SIGN_KEY}
	fi
	
	${COMMANDER} util keytotoken ${PUB_SIGN_KEY} --outfile sign_key.token
	
	# Generate the signed images and upgrade file
	${COMMANDER} convert ${BOOTLOADER_v1} --secureboot --keyfile ${PRI_SIGN_KEY} --outfile bootloader-base-signed.hex
	${COMMANDER} convert ${BOOTLOADER_v2} --secureboot --keyfile ${PRI_SIGN_KEY} --outfile bootloader-upgraded-signed.hex
	${COMMANDER} convert ${APPLICATION} --secureboot --keyfile ${PRI_SIGN_KEY} --outfile application-signed.hex
	
	${COMMANDER} gbl create bootloader-upgrade.gbl --bootloader bootloader-upgraded-signed.hex --sign ${PRI_SIGN_KEY} --encrypt ${ENCRYPT_KEY} --compress lzma
	
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
	
	# Program OTP of the device
	${COMMANDER} security writekey --sign ${PUB_SIGN_KEY} --noprompt -s ${WSTK_SERIAL} -d ${DEVICE}
	${COMMANDER} security writeconfig --configfile ${USER_CONFIG} --noprompt -s ${WSTK_SERIAL} -d ${DEVICE}
	
	# Cleanup
	rm sign_key.token
fi


#!/bin/sh +x

WSTK_SERIAL=${1}
BOOTLOADER_v1=${2}
BOOTLOADER_v2=${3}
APPLICATION=${4}
ENCRYPT_KEY=${5:-encryption_key.txt}
PUB_SIGN_KEY=${6:-sign_pubkey.pem}
PRI_SIGN_KEY=${7:-sign_privkey.pem}

COMMANDER=commander.exe

if [ -z "${APPLICATION}" ]
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
	
else	

	# Generate the keys and key tokens
	if [ ! -f "${ENCRYPT_KEY}" ]; then
		${COMMANDER} util genkey --type aes-ccm --outfile ${ENCRYPT_KEY}
	fi
	
	if [ ! -f "${PRI_SIGN_KEY}" ]; then
		${COMMANDER} util genkey --type ecc-p256 --privkey ${PRI_SIGN_KEY} --pubkey ${PUB_SIGN_KEY}
	fi
	
	# Generate the signed images and upgrade file
	${COMMANDER} convert ${BOOTLOADER_v1} --secureboot --keyfile ${PRI_SIGN_KEY} --outfile bootloader-base-signed.hex
	${COMMANDER} convert ${BOOTLOADER_v2} --secureboot --keyfile ${PRI_SIGN_KEY} --outfile bootloader-upgraded-signed.hex
	${COMMANDER} convert ${APPLICATION} --secureboot --keyfile ${PRI_SIGN_KEY} --outfile application-signed.hex
	
	${COMMANDER} gbl create bootloader-upgrade.gbl --bootloader bootloader-upgraded-signed.hex --sign ${PRI_SIGN_KEY} --encrypt ${ENCRYPT_KEY} --compress lzma
	
fi


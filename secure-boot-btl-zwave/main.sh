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

# Set path to your commander executable
COMMANDER=commander.exe

# Check for commander program
if $COMMANDER -v | grep -q "Simplicity"; then
    echo "Program: $COMMANDER was found.."
else
    # WSTK2 has trouble with echo -e
    echo ""
    echo "Commander program was not found.."
    echo "* This script depends on the Simplicity Commander executable."
    echo "* Add commander to your path variables, or"
    echo "* Adjust the COMMANDER variable in this script to point to your commander executable."
    echo ""
    exit 1
fi

if [ -z "${USER_CONFIG}" ]; then
    echo "Welcome! Please review the set of inputs to this script and re-run."
    # WSTK2 has trouble with echo -e
    echo ""
    echo "PARAMETER 1: WSTK_SERIAL: This is your target emulator, and can be retrieved from \"commander.exe -v\" output:"
    echo "$(commander.exe -v)"
    echo "* This script will offer to use the first found emulator if desired value not found"
    echo ""
    echo "PARAMETER 2: Bootloader_v1: This is your desired bootloader with version N."
    echo " Make sure to build your bootloader in accordance with addresses in the README.md!"
    # This is based on example SoC Internal Storage 512
    # Update the Bootloader Core Component settings to NOT stage over the application:
    #	Enable Use Custom Bootloader Application Size : 278528 (0x00044000)
    #	Change "Base address of bootloader upgrade image" : 327680 (0x00050000)
    #	Also, optionally enable "Upgrade SE without using the staging area"
    echo ""
    echo "PARAMETER 3: Bootloader_v2: This is your desired bootloader with version N+1."
    # Same as above, but version must be incremented in bootloader Core Component settings
    echo ""
    # The on/off switch example is useful because it does not sleep
    #   Update the Z-Wave Core Component region to US Long Range if necessary. Default region is EU
    echo "PARAMETER 4: Application: This is your desired application."
    echo ""
    # The included user config uses default values with Secure Boot enabled
    echo "PARAMETER 5: User Config (included file): Tested as default with only Secure Boot enabled."
    echo "* A default can be created with: \"$COMMANDER security genconfig -o <filename> --nostore\""
    echo "* You must enable Secure Boot if you generate a new default."
    echo ""
    # Device part number
    echo "PARAMETER 6: DEVICE: You can get this from \"commander.exe device info\" output:"
    echo "$(commander.exe device info)"
    echo "* This script will offer to use the first found device if desired value not found."
    echo ""
    echo "PARAMETERS 7-9: Keys: These are your generated keys in order: encryption_key.txt, sign_pubkey.pem, sign_privkey.pem."
    echo "* CAUTION! This script will automatically generate any keys that you have not provided"
    echo ""
    exit 1
fi

# Check for presence of requested target part. If not found, offer first found device as alternative
if ! $COMMANDER device info | grep -q $DEVICE; then
    FIRST_FOUND_DEVICE="$(commander.exe device info -v | grep Part | cut -d ':' -f2 | cut -d ' ' -f2 | tr -d '\r')"
    echo "Requested device $DEVICE was not found!"

    while true; do
        read -p "We've found an attached: $FIRST_FOUND_DEVICE. Set as target (y/n)? " yn
        case $yn in
        [Yy]*) DEVICE=$FIRST_FOUND_DEVICE break ;;
        [Nn]*) exit ;;
        *) echo "Please answer yes or no." ;;
        esac
    done

    echo "$DEVICE set as target.."
else
    echo "Device: $DEVICE was found.."
fi

# Check for presence of requested target WSTK emulator board. If not found, offer first found WSTK as alternative
if ! $COMMANDER -v | grep "Emulator" | grep -q $WSTK_SERIAL; then
    FIRST_FOUND_WSTK="$(commander.exe -v | grep Emulator | cut -d '=' -f2 | cut -d ' ' -f1 | tr -d '\r')"
    echo "Requested device $WSTK_SERIAL was not found!"

    while true; do
        read -p "We've found an attached: $FIRST_FOUND_WSTK. Set as emulator (y/n)? " yn
        case $yn in
        [Yy]*) WSTK_SERIAL=$FIRST_FOUND_WSTK break ;;
        [Nn]*) exit ;;
        *) echo "Please answer yes or no." ;;
        esac
    done

    echo "$WSTK_SERIAL set as WSTK emulator.."
else
    echo "WSTK emulator: $WSTK_SERIAL was found.."
fi

# Generate the keys and key tokens
if [ ! -f "${ENCRYPT_KEY}" ]; then
    ${COMMANDER} util genkey --type aes-ccm --outfile ${ENCRYPT_KEY}
fi

if [ ! -f "${PRI_SIGN_KEY}" ]; then
    ${COMMANDER} util genkey --type ecc-p256 --privkey ${PRI_SIGN_KEY} --pubkey ${PUB_SIGN_KEY}
fi

echo "Starting process.."

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
dsk=$(${COMMANDER} tokendump --tokengroup znet --token MFG_ZW_QR_CODE -d ${DEVICE} | grep MFG_ZW_QR_CODE)
dsk=$(echo ${dsk} | cut -c 30-69)
echo "DSK:" ${dsk}

# Program OTP of the device
${COMMANDER} security writekey --sign ${PUB_SIGN_KEY} --noprompt -s ${WSTK_SERIAL} -d ${DEVICE}
${COMMANDER} security writeconfig --configfile ${USER_CONFIG} --noprompt -s ${WSTK_SERIAL} -d ${DEVICE}

# Cleanup
rm sign_key.token

exit 0

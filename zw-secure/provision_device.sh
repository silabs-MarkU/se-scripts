#!/bin/sh +x

WSTK_SERIAL=${1}
ENCRYPT_KEY=${2}
PUB_SIGN_KEY=${3}
USER_CONFIG=${4}


DEVICE=EFR32ZG23B020F512IM40

commander.exe security writekey --sign ${PUB_SIGN_KEY} -s ${WSTK_SERIAL} -d ${DEVICE}
commander.exe security writekey --encrypt ${ENCRYPT_KEY} -s ${WSTK_SERIAL} -d ${DEVICE}
commander.exe security writeconfig ${USER_CONFIG} --noprompt -s ${WSTK_SERIAL} -d ${DEVICE}



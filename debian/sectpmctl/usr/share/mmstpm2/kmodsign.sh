#!/bin/sh

KBUILD_SIGN_PIN="$(cat "/etc/mmstpm2/keys/db.pwd")" tpmkmodsign -P tpm2 -P default -Q "?provider=tpm2,tpm2.digest!=yes" sha256 "object:${2}?pass" "${3}" "${4}" ${5}


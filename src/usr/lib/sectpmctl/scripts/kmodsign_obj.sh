#!/bin/bash

# SECTPMCTL

if [[ $# -lt 5 ]]; then
  KBUILD_SIGN_PIN="$(cat "/var/lib/sectpmctl/keys/db.pwd")" tpmkmodsign -P tpm2 -P default -Q "?provider=tpm2,tpm2.digest!=yes" sha256 "object:${2}?pass" "${3}" "${4}"
else
  KBUILD_SIGN_PIN="$(cat "/var/lib/sectpmctl/keys/db.pwd")" tpmkmodsign -P tpm2 -P default -Q "?provider=tpm2,tpm2.digest!=yes" sha256 "object:${2}?pass" "${3}" "${4}" "${5}"
fi


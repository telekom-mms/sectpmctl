#!/bin/bash

KBUILD_SIGN_PIN="$(cat "/etc/mmstpm2/keys/db.pwd")" tpmsbsign --provider tpm2 --provider default --propquery ?provider=tpm2,tpm2.digest!=yes --key "object:${2}?pass" "${3}" "${4}" "${5}" "${6}" "${7}"


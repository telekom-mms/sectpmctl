#!/bin/sh

KBUILD_SIGN_PIN="$(cat "/etc/mmstpm2/keys/db.pwd")" tpmsbsign --provider tpm2 --provider default "$@"

#!/bin/bash

# Path's
MMSTPM2_KEYS="/etc/mmstpm2/keys"

/usr/share/mmstpm2/kmodsign.sh sha256 "${MMSTPM2_KEYS}/db.obj" "${MMSTPM2_KEYS}/db.cer" "$2"


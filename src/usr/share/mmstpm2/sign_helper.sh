#!/bin/sh

# Path's
MMSTPM2_KEYS="/etc/mmstpm2/keys"

kmodsign sha256 "${MMSTPM2_KEYS}/db.key" "${MMSTPM2_KEYS}/db.cer" "$2"


#!/bin/bash

# Path's
SECTPMCTL_KEYS="/var/lib/sectpmctl/keys"

/usr/lib/sectpmctl/scripts/kmodsign.sh sha256 "${SECTPMCTL_KEYS}/db.obj" "${SECTPMCTL_KEYS}/db.cer" "$2"


#!/bin/bash

# SECTPMCTL
# As dkms offers to kind of sign helpers, this script will support both of them:
# When used as sign_tool, the second parameter will contain the module to sign and
# when used as sign_file, the forth parameter will contain the module to sign

# Path's
SECTPMCTL_KEYS="/var/lib/sectpmctl/keys"

if [[ $# -eq 2 ]]; then
  /usr/lib/sectpmctl/scripts/kmodsign.sh sha256 "${SECTPMCTL_KEYS}/db.obj" "${SECTPMCTL_KEYS}/db.cer" "$2"
elif [[ $# -eq 4 ]]; then
  /usr/lib/sectpmctl/scripts/kmodsign.sh sha256 "${SECTPMCTL_KEYS}/db.obj" "${SECTPMCTL_KEYS}/db.cer" "$4"
else
  echo /usr/lib/sectpmctl/scripts/dkms_sign_helper.sh Unknown parameters given
  exit 1
fi


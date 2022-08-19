#!/bin/bash

# SECTPMCTL
# AUTHORS: Heike Pesch <heike.pesch@t-systems.com>
#          Richard Robert Reitz <richard-robert.reitz@t-systems.com>

# Path's
SECTPMCTL_KEYS="/var/lib/sectpmctl/keys"

/usr/lib/sectpmctl/scripts/kmodsign.sh sha256 "${SECTPMCTL_KEYS}/db.obj" "${SECTPMCTL_KEYS}/db.cer" "$2"


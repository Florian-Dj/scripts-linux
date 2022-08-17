#!/bin/bash
###########################
# Author : Florian DJERBI
# Object : Environment deleted
# Create : 16/08/2022
# Update : 17/08/2022
###########################


#
# FUNCTIONS
#

function main() {
    BRANCH=$(sudo -Hiu ${USER} bash -c 'echo "${BRANCH}"')
    REPO=$(sudo -Hiu ${USER} bash -c 'echo "${REPO}"')
    DOMAIN=$(sudo -Hiu ${USER} bash -c 'echo "${DOMAIN}"')
    echo "${USER}, ${DOMAIN}, ${REPO}, ${BRANCH}"
}

while true; do
    for user in $(awk -F: '{if (65000 > $3 && $3 > 1000) {print $1}}' /etc/passwd); do
        echo "  - ${user}"
    done
    echo -n "Choice user delete: "
    read USER
    getent passwd ${USER} > /dev/null 2>&1
    RES=$?
    if [ ${RES} -eq 0 ]; then
        main "${USER}"; break;
    fi
done


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
    init "$@"
}

function init(){
    while true; do
        for user in $(awk -F: '{if (65000 > $3 && $3 > 1000) {print $1}}' /etc/passwd); do
            echo "  - ${user}"
        done
        echo -n "Choice user delete: "
        read USER
        getent passwd ${USER} > /dev/null 2>&1
        RES=$?
        if [ ${RES} -eq 0 ]; then
            verification "${USER}"; break;
        fi
    done
}


function verification(){
    while true; do
        echo -n "Are you sure to delete ${USER}? (yes/no): "
	read DELETE
	case ${DELETE} in
            [Yy]*) delete_user "$USER"; break;;
            [Nn]*) exit 1;;
        esac
    done
}

function delete_user(){
    BRANCH=$(sudo -Hiu ${USER} bash -c 'echo "${BRANCH}"')
    REPO=$(sudo -Hiu ${USER} bash -c 'echo "${REPO}"')
    DOMAIN=$(sudo -Hiu ${USER} bash -c 'echo "${DOMAIN}"')
    if [ ! -z "${BRANCH}" ] && [ ! -z "${REPO}" ] && [ ! -z "${DOMAIN}" ]; then
        userdel -r ${USER}
        rm /etc/logrotate.d/${DOMAIN}
        rm -r /var/www/${DOMAIN}
        rm /var/spool/cron/crontabs/${USER}
        rm /etc/apache2/sites-available/${DOMAIN}.conf
        rm /etc/apache2/sites-enabled/${DOMAIN}.conf
        rm -r /etc/letsencrypt/live/${DOMAIN}
    fi
}

main "$@"

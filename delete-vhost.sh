#!/bin/bash
###########################
# Author : Florian DJERBI
# Object : Environment deleted
# Create : 16/08/2022
# Update : 20/08/2022
###########################


#
# VARIABLES
#
_reset='\033[0m'
_red='\033[0;31m'
_green='\033[0;32m'
_cyan='\033[0;36m'


#
# FUNCTIONS
#
function _success()
{
    printf "${_green}✔ %s${_reset}\n" "$@"
}

function _error() {
    printf "${_red}✖ %s${_reset}\n" "$@"
}

function _info() {
    printf "${_cyan}▬ %s${_reset}\n" "$@"
}


function main() {
    check_folder "$@"
    init "$@"
}

function check_folder(){
    if [ ! -d /data/backup ];then
        mkdir -p /data/backup
    fi
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
            BRANCH=$(sudo -Hiu ${USER} bash -c 'echo "${BRANCH}"')
            REPO=$(sudo -Hiu ${USER} bash -c 'echo "${REPO}"')
            DOMAIN=$(sudo -Hiu ${USER} bash -c 'echo "${DOMAIN}"')
            verification "$@"
            break
        fi
    done
}


function archive(){
    if [ ! -z "${BRANCH}" ] && [ ! -z "${REPO}" ] && [ ! -z "${DOMAIN}" ]; then
        tar -zcvf /data/backup/${DOMAIN}-${USER}-${BRANCH}.tar.gz /etc/logrotate.d/${DOMAIN} /var/www/${DOMAIN} /var/spool/cron/crontabs/${USER} /etc/apache2/sites-available/${DOMAIN}.conf /etc/apache2/sites-enabled/${DOMAIN}.conf /etc/letsencrypt/live/${DOMAIN} > /dev/null 2>&1
    fi
}


function verification(){
    while true; do
        echo -n "Do you want to archive the projetct ? (yes/no): "
	read ARCHIVE
	case ${ARCHIVE} in
            [Yy]*) archive "$@"; break;;
            [Nn]*) exit 1;;
        esac
    done
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

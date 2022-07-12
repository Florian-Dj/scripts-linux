#!/bin/bash
###########################
# Author : Florian DJERBI
# Object : Environment creation
# Create : 12/07/2022
# Update : 13/07/2022
###########################

echo -n "Project name (user): "
read PROJET
USER=$( echo "${PROJET}" | cut -c1-30 )
echo -n "Domain name (domain.extension): "
read DOMAIN


function usercreation(){

        useradd -m -s /bin/bash -d /home/${DOMAIN} ${USER}
        echo "Creating the SSH key for GIT"
        sudo -H -u ${USER} bash -c 'ssh-keygen -t rsa -b 4096 -N "" -C "${USER}@${DOMAIN}" -f ~/.ssh/id_rsa -q -P ""'
}

function main() {
    echo "User creation"
    usercreation
    echo "User has been created"
}

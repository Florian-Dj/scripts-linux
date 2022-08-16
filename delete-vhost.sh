#!/bin/bash
###########################
# Author : Florian DJERBI
# Object : Environment deleted
# Create : 16/08/2022
# Update : 16/08/2022
###########################


function main() {
    for user in $(awk -F: '{printf "%s:%s\n",$1,$3}' /etc/passwd  | egrep ':[0-9]{4}$'); do
        echo "  - ${user}"
    done
}

main "@"

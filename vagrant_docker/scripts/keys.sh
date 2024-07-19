#!/usr/bin/env bash 

set -o allexport
source /vagrant/scripts/variables
set +o allexport

function get_keys {
    i=0
    while read line
    do
        host_ips[ $i ]="$line"        
        (( i++ ))
    done < <(cat /vagrant/iplist.txt)

    for ip in "${host_ips[@]}"
    do
        echo "Scanning host key: ${ip}"
        sudo su -l postgres -c "ssh-keyscan ${ip} >> ~/.ssh/known_hosts"
    done
}

echo "${GREEN}Getting all keys from all machines${RESET}"
get_keys
echo "${GREEN}done${RESET}"

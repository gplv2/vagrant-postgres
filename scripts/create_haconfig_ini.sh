#!/usr/bin/env bash 

set -o allexport
source /vagrant/scripts/variables
set +o allexport

function get_ips {
    i=0
    while read line
    do
        host_ips[ $i ]="$line"        
        (( i++ ))
    done < <(cat /vagrant/iplist.txt)

    #for ip in "${host_ips[@]}"
    #do
        #echo "Scanning host key: ${ip}"
        #sudo su -l postgres -c "ssh-keyscan ${ip} >> ~/.ssh/known_hosts"
    #done
}

echo "${GREEN}Getting IPS from all machines${RESET}"
get_ips

echo "${GREEN}Crafting haproxy file for max 2 nodes (limitation of python generator)${RESET}"
cat > /home/vagrant/haproxy-postgresql/config.py <<EOF
HA_MASTER_NAME = "node1"
HA_MASTER_DSN = "${host_ips[0]}:${PORT_BOUNCER}"
HA_STANDBY_NAME = "node2"
HA_STANDBY_DSN = "${host_ips[1]}:${PORT_BOUNCER}"
HA_CHECK_USER = "pgc"
HA_CHECK_PORT = "${PORT}"
HA_LISTEN_PORT = "${PORT_HAPROXY}"
HA_STATS_USER = "pgadmin"
HA_STATS_PASSWORD = "pgsecret"
HA_VIP_IP = "${MY_CIDR_IP}"
EOF

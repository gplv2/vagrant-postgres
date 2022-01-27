#!/usr/bin/env bash 

set -o allexport
source /vagrant/scripts/variables
set +o allexport


echo "Generating local keys"
rm -Rf tmp/*

ssh-keygen -t rsa -q -f "tmp/id_rsa" -N ""'

#sudo su -l postgres -c 'ssh-keyscan -H ${IP1} >> ~/.ssh/known_hosts'
#sudo su -l postgres -c 'ssh-keyscan -H ${IP2} >> ~/.ssh/known_hosts'

#sudo cp /tmp/keys/id_rsa /var/lib/pgsql/.ssh/
#sudo cp /tmp/keys/id_rsa.pub /var/lib/pgsql/.ssh/
#sudo cp /tmp/keys/id_rsa.pub /var/lib/pgsql/.ssh/authorized_keys
#sudo chown -R postgres:postgres /var/lib/pgsql/.ssh
#sudo chmod 644 /var/lib/pgsql/.ssh/authorized_keys
#sudo chmod 600 /var/lib/pgsql/.ssh/id_rsa


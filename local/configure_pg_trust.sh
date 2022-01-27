#!/usr/bin/env bash 

#set -o allexport
#source ./scripts/variables
#set +o allexport

echo "Generating local keys"
rm -Rf tmp/*

ssh-keygen -t rsa -q -f "tmp/id_rsa" -N ""

#sudo su -l postgres -c 'ssh-keyscan -H ${IP1} >> ~/.ssh/known_hosts'
#sudo su -l postgres -c 'ssh-keyscan -H ${IP2} >> ~/.ssh/known_hosts'


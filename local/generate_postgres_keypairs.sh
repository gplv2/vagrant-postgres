#!/usr/bin/env bash 

#set -o allexport
#source ./scripts/variables
#set +o allexport

echo "Generating local keys"
rm -Rf tmp/*

ssh-keygen -t rsa-sha2-512 -q -f "tmp/id_rsa" -N ""


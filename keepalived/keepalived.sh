#!/bin/bash -e

set -o allexport
source /vagrant/scripts/variables
set +o allexport

while getopts m: flag
do
    case "${flag}" in
        m) MODE=${OPTARG};;
    esac
done

echo "Mode: $MODE";

# mode is standby or master

INSTANCE=vagrant
SCRIPTS=/vagrant/keepalived/

function isinstalled {
    if yum list installed "$@" >/dev/null 2>&1; then
        true
    else
        false
    fi
}

echo "Preparing cluster for keepalived installation"

function install_configure_keepalived {
    # DB server
    echo "Configuring keepalived ..."
    echo "Stopping keepalived if running"
    service keepalived stop
    cp /etc/keepalived/keepalived.conf /etc/keepalived/keepalived.conf.orig

    if [ "$MODE" = "master" ]; then
        echo "Configuring keepalived config file"
        cat ${SCRIPTS}/keepalived-template-master.conf | sed -e "s/MY_MODE/MASTER/ ; s/MY_CIDR/${MY_CIDR_IP}/" > ${SCRIPTS}/keepalived-master.conf
        cp ${SCRIPTS}/keepalived-master.conf /etc/keepalived/keepalived.conf
    fi
    if [ "$MODE" = "standby" ]; then
        echo "Configuring keepalived config file"
        cat ${SCRIPTS}/keepalived-template-standby.conf | sed -e "s/MY_MODE/BACKUP/ ; s/MY_CIDR/${MY_CIDR_IP}/" > ${SCRIPTS}keepalived-standby.conf
        cp ${SCRIPTS}/keepalived-standby.conf /etc/keepalived/keepalived.conf
    fi
    echo "Enable keepalived"
        sudo systemctl enable --now keepalived
    echo "Starting keepalived"
    service keepalived start
}

function enable_keepalived {
    if isinstalled keepalived ; then
        systemctl enable keepalived
    fi
}

echo "Start keepalived install tasks..."

enable_keepalived
install_configure_keepalived

echo "keepalived installation done"


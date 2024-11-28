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
    if dnf list installed "$@" >/dev/null 2>&1; then
        true
    else
        false
    fi
}

echo "Preparing cluster for keepalived installation"

function install_configure_keepalived {
    if ! isinstalled keepalived ; then
        echo "Keepalived not installed but it should be"
        exit 1
    fi
    # DB server
    echo "Configuring keepalived ..."
    echo "Stopping keepalived if running"

    # Check if keepalived is running
    if systemctl is-active --quiet keepalived; then
        echo "keepalived is running. Stopping it now..."
        sudo systemctl stop keepalived
        if [ $? -eq 0 ]; then
            echo "keepalived has been stopped successfully."
        else
            echo "Failed to stop keepalived."
            exit 1
        fi
    else
        echo "keepalived is not running."
    fi

    if [ -e /etc/keepalived/keepalived.conf ]; then
        echo "Default config exists."
        cp /etc/keepalived/keepalived.conf /etc/keepalived/keepalived.conf.orig
    fi

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
    echo "Starting keepalived"
    service keepalived start
}

function enable_keepalived {
    if isinstalled keepalived ; then
        systemctl enable --now keepalived
    fi
}

echo "Start keepalived install tasks..."

install_configure_keepalived
enable_keepalived

echo "keepalived installation done"


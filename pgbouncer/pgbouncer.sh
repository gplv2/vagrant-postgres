#!/bin/bash -e

set -o allexport
source /vagrant/scripts/variables
set +o allexport

while getopts "m:n:i:" flag
do
    case "${flag}" in
        m) MODE=${OPTARG};;
        n) NODE_NAME=${OPTARG};;
        i) NODE_IP=${OPTARG};;
    esac
done

echo "Mode: $MODE";

# mode is standby or master

SCRIPTS=/vagrant/pgbouncer



function isinstalled {
  if dnf list installed "$@" >/dev/null 2>&1; then
    true
  else
    false
  fi
}

echo "Preparing cluster for pgbouncer installation"

function install_configure_pgbouncer {
    if ! isinstalled pgbouncer ; then
        echo "Installing Pgbouncer"
        sudo dnf -d1 -q -y install pgbouncer
    fi

    # DB server
    echo "Configuring pgbouncer ..."
    #echo "Stopping pgbouncer if running"
    #service pgbouncer stop
    if [ -r "/etc/pgbouncer/pgbouncer.ini" ]; then
        mv /etc/pgbouncer/pgbouncer.ini /etc/pgbouncer/pgbouncer.ini.orig
    fi
    #cp /tmp/ha/userlist.txt /etc/pgbouncer/userlist.txt
    echo '"pgbouncer" "md54cf2e80a8a9921c588dfe9644fc6a076"' >> /etc/pgbouncer/userlist.txt

    if isinstalled pgbouncer ; then
        cat ${SCRIPTS}/pgbouncer-template.ini | sed -e "s/NODE_IP/${NODE_IP}/g ; s/PORT_BOUNCER/${PORT_BOUNCER}/g ; s/PORT/${PORT}/g" > ${SCRIPTS}/pgbouncer.ini
        cp ${SCRIPTS}/pgbouncer.ini /etc/pgbouncer/pgbouncer.ini
        if [ "$MODE" = "master" ]; then
            echo "Master ..."
            echo "Configuring MASTER pgbouncer config file"
            echo "Preparing Database for use (will take care of pgc/haproxy + pgbouncer)... "
            su - postgres -c "cat /vagrant/sql/create_system.sql | psql -qAtX -p ${PORT}"
        fi
        if [ "$MODE" = "standby" ]; then
            echo "Standby ..."
            #echo "Configuring standby packages"
        fi
    fi
    echo "Starting pgbouncer"
    service pgbouncer start
}

function install_configure_pg {
    # starting the standby
    echo "Changing pg_hba to add the local subnet derived from interface to the end"
    echo $BLOCK_TO_ADD >> $PGCONF/pg_hba.conf
    echo "Reloading postgres...."
    service postgresql-${PGVERSION} reload
}

function enable_pgbouncer {
    if isinstalled pgbouncer ; then
        systemctl enable pgbouncer
    fi
}

echo "Start pgbouncer install tasks..."

install_configure_pgbouncer
enable_pgbouncer

echo "pgbouncer installation done"


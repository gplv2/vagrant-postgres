#!/bin/bash -e

set -o allexport
source /vagrant/scripts/variables
set +o allexport

while getopts "m:n:i:" flag
do
    case "${flag}" in
        m) MODE=${OPTARG};;
        n) NODE_NAME=${OPTARG};;
        i) NODE_NUMBER=${OPTARG};;
    esac
done

echo "Mode: $MODE";

# mode is standby or master

## installing repmgr steps: ##

# 1. Install PostgreSQL
# 2. Install repmgr
# 3. Configure PostgreSQL
# 4. Create users
# 5. Configure pg_hba.conf
# 6. Configure the repmgr file
# 7. Register the primary server
# 8. Build/clone the standby server
# 9. Register the standby server
# 10. Start repmgrd daemon process

SCRIPTS=/vagrant/repmgr/

REPMGR="repmgr -f /etc/repmgr/11/repmgr.conf"
alias repmgr=$REPMGR

echo "Preparing cluster for repmgr installation"

function isinstalled {
  if yum list installed "$@" >/dev/null 2>&1; then
    true
  else
    false
  fi
}

function install_configure_repmgr {
    # DB server
    if [ "$MODE" = "master" ]; then
        if isinstalled postgresql11-server ; then
            echo "Installing repmgr config file"
            cat ${SCRIPTS}/repmgr-template-node.conf | sed -e "s/NODE_NUMBER/${NODE_NUMBER}/g ; s/NODE_NAME/${NODE_NAME}/g ; s/PORT/${PORT}/g" > ${SCRIPTS}/repmgr-master.conf
            cp ${SCRIPTS}/repmgr-master.conf /etc/repmgr/11/repmgr.conf

            echo "Configuring repmgr master DB server ..."

            echo "Preparing Database ... "

            # install extension
            cat > /tmp/install.repmgr.sql << EOF
CREATE EXTENSION repmgr;
CREATE USER repmgr;
ALTER USER repmgr WITH SUPERUSER PASSWORD '${REPMGR_PASSWORD}';
CREATE DATABASE repmgr WITH OWNER repmgr;
EOF
            echo "Creating extension and repmgr user"
            su - postgres -c "cat /tmp/install.repmgr.sql | psql -p ${PORT}"
            # register the primary
            echo "Registering the primary server"
            su - postgres -c "${REPMGR} primary register"
        fi
    fi
    if [ "$MODE" = "standby" ]; then
        if isinstalled postgresql11-server ; then
            echo "Installing repmgr config file"
            cat ${SCRIPTS}/repmgr-template-node.conf | sed -e "s/NODE_NUMBER/${NODE_NUMBER}/g ; s/NODE_NAME/${NODE_NAME}/g ; s/PORT/${PORT}/g" > ${SCRIPTS}/repmgr-standby.conf
            cp ${SCRIPTS}/repmgr-standby.conf /etc/repmgr/11/repmgr.conf

            echo "Stopping standby if running"
            systemctl stop postgresql-11

            echo "Creating a clone from the master server"
            #su - postgres -c "${REPMGR} -h ${MASTER_IP} -U repmgr -p ${PORT} --copy-external-config-files standby clone -F -c"
            su - postgres -c "${REPMGR} -h node1 -U repmgr -p ${PORT} standby clone -F -c"

            # starting the standby
            echo "Starting the standby"
            systemctl start postgresql-11

            # register the standby
            echo "Registering the standby server"
            su - postgres -c "${REPMGR} standby register -F"
        fi
    fi
}

echo "Start repmgr install tasks..."

install_configure_repmgr

# echo "Updating select_cluster.sh script"
# /usr/local/bin/create_cluster_file.js

echo "Crosscheck ssh trust"
su - postgres -c "${REPMGR} cluster crosscheck"

echo "Repmgr installation done"

echo "Results:"
su - postgres -c "${REPMGR} cluster show"


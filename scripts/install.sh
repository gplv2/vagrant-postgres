#!/usr/bin/env bash 

set -o allexport
source /vagrant/scripts/variables
set +o allexport

# RESOURCE_INDEX= grb-db-0
if [ -z "$RESOURCE_INDEX" ] ; then
    RESOURCE_INDEX=`hostname`
fi

echo "${GREEN}Setting up configuration${RESET}"

function fix_locales {
    echo "${GREEN}Fix locales${RESET}"
    # fix locales
    locale-gen "en_US.UTF-8"
    locale-gen "nl_BE.UTF-8"
    locale-gen "fr_BE.UTF-8"

    echo "nl_BE.UTF-8 fr_BE.UTF-8 UTF-8" >> /etc/locale.gen

    locale-gen
}

function isinstalled {
  if yum list installed "$@" >/dev/null 2>&1; then
    true
  else
    false
  fi
}

function install_configure_packages {
    echo "${GREEN}Installing tools${RESET}"
    sudo yum -y install nodejs haproxy keepalived pgbouncer git openssl curl wget net-tools

    # curl -sL https://deb.nodesource.com/setup_6.x | sudo -E bash -
    # curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash -

    # get our IP address
    MY_IP=`ifconfig  | grep -E -o '(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)'`
    # export IP=$MY_IP

    echo "${GREEN}Stopping haproxy${RESET}"
    [ -x /etc/init.d/haproxy ] && /etc/init.d/haproxy stop

    # mkdir /etc/haproxy/certs.d

    echo "Create dhparam file..."
    #sudo openssl dhparam -dsaparam -out /etc/haproxy/dhparam.pem 4096

    echo "${GREEN}Starting haproxy${RESET}"
    [ -x /etc/init.d/haproxy ] && /etc/init.d/haproxy start
}

function load_postgres_sqlfiles {
    # create alter list
    su - postgres -c "psql -qAtX -d ${DATA_DB} -c \"${MOVESQL}\" > /tmp/alter.pre.ts1.sql 2>/dev/null"

    MOVESQL="SELECT ' ALTER TABLE ' || schemaname || '.' || tablename || ' SET TABLESPACE pg_default;' FROM pg_tables WHERE schemaname NOT IN ('pg_catalog', 'information_schema');"

    # create alter list
    su - postgres -c "psql -qAtX -d ${DB} -c \"${MOVESQL}\" > /tmp/alter.pre.ts2.sql 2>/dev/null"

    echo "${GREEN}Moving data + indexes to tablespace${RESET}"
    su - postgres -c "cat /tmp/alter.pre.ts2.sql | psql -d ${DATA_DB}"

}

function create_pgpass {
    # detect the home of postgres user
    PGHOME=`getent passwd postgres | awk -F: '{ print $6 }'`
    PGPASS=${PGHOME}/.pgpass

    echo "${GREEN}Checking pgpass${RESET}"
    if [ ! -e "${PGPASS}" ]; then
        echo "create ${PGPASS}"
        echo "localhost:5432:${DB}:${USER}:${PASSWORD}" > $PGPASS
        echo "localhost:5432:${DATA_DB}:${USER}:${PASSWORD}" >> $PGPASS
        echo "127.0.0.1:5432:${DB}:${USER}:${PASSWORD}" >> $PGPASS
        echo "127.0.0.1:5432:${DATA_DB}:${USER}:${PASSWORD}" >> $PGPASS
        PERMS=$(stat -c "%a" ${PGPASS})
        if [ ! "${PERMS}" = "0600" ]; then
            chmod 0600 ${PGPASS}
        fi

        #chown -R ${DEPLOY_USER}:${DEPLOY_USER} $PGPASS $PGRC
        chown -R postgres:postgres $PGPASS  # $PGRC
        PERMS=$(stat -c "%a" ${PGPASS})
        if [ ! "${PERMS}" = "0600" ]; then
            chmod 0600 ${PGPASS}
        fi
    fi
}

function create_pgrc {
   # # install my own psqlrc
   # echo "${GREEN}Creating .pgsqlrc${RESET}"
   # cp /tmp/rcfiles/psqlrc $PGRC
   # chown -R ${DEPLOY_USER}:${DEPLOY_USER} $PGRC

    # install postgres .psqlrc file
    # cp /tmp/rcfiles/psqlrc $PGRC
    sudo cp /tmp/rcfiles/psqlrc /var/lib/pgsql/.psqlrc
    sudo chown -R postgres:postgres /var/lib/pgsql/.psqlrc
}

# Create an aliases file so we can use short commands to navigate a project
function create_bash_alias {
    echo "${GREEN}Setting up bash aliases${RESET}"
    # the db alias : psql -h 127.0.0.1 -d grb-temp -U ${USER}
cat > /root/.bash_aliases << EOF
alias psqlc='psql -h 127.0.0.1 -d ${DATA_DB} -U ${USER}'
alias home='cd ${PROJECT_DIRECTORY}'
EOF
}

function install_git_repos {

    echo "${GREEN}Accept github keys in advance${RESET}"
    if [ -f /home/${DEPLOY_USER}/ssh/known_hosts ] ; then
        if ! cat /home/${DEPLOY_USER}/ssh/known_hosts | grep -q "github"; then
            echo "Adding SSH github host key"
            su - ${DEPLOY_USER} -c "ssh-keyscan github.com >> /home/${DEPLOY_USER}/.ssh/known_hosts"
        fi
    else
        echo "Adding SSH github host key"
        su - ${DEPLOY_USER} -c "ssh-keyscan github.com >> /home/${DEPLOY_USER}/.ssh/known_hosts"
    fi

    if ! cat /home/${DEPLOY_USER}/.ssh/known_hosts | grep -q "github"; then
        sudo su - $DEPLOY_USER -c "ssh-keyscan github.com >> /home/${DEPLOY_USER}/.ssh/known_hosts"
    fi

    echo "${GREEN}Install GIT repos${RESET}"
    su - ${DEPLOY_USER} -c "git clone https://github.com/gplv2/haproxy-postgresql.git"

}

function yum_update {
    echo "${GREEN}Updating system${RESET}"
    yum -d1 -q -y update
    echo "${GREEN}Update done${RESET}"
}

function make_work_dirs {
    echo "${GREEN}Creating dirs${RESET}"
    CREATEDIRS="/usr/local/src/grb /datadisk2/out"

    for dir in $CREATEDIRS
    do
        if [ ! -d "$dir" ]; then
            mkdir $dir

            if [ $? -eq 0 ]
            then
                echo "Created directory $dir"
            else
                echo "Could not create $dir" >&2
                exit 1
            fi
            chown -R ${DEPLOY_USER}:${DEPLOY_USER} $dir
        fi

#        PERMS=$(stat -c "%a" $dir)
#        if [ ! "${PERMS}" = "0700" ]; then
#            chmod 0700 /root/.ssh
#        fi
    done
}

function create_deploy_user {
    echo "${GREEN}Creating deploy user${RESET}"
    if [ ! -d "/home/${DEPLOY_USER}" ]; then
        # Adding a deploy user
        PASS=YgjwiWbc2UWG.
        SPASS=`openssl passwd -1 $PASS`
        /usr/sbin/useradd -p $SPASS --create-home -s /bin/bash -G www-data $DEPLOY_USER
    fi
}

function install_extra_packages {
    echo "${GREEN}Sort OS packages out${RESET}"

    [ -r /etc/lsb-release ] && . /etc/lsb-release

    if [ -z "$DISTRIB_RELEASE" ] && [ -x /usr/bin/lsb_release ]; then
        # Fall back to using the very slow lsb_release utility
        DISTRIB_RELEASE=$(lsb_release -s -r)
        DISTRIB_CODENAME=$(lsb_release -s -c)
    fi

    if [ "$DISTRIB_RELEASE" = "18.04" ]; then

        if [ ! -e "/home/${DEPLOY_USER}/.hushlogin" ]; then
            touch /home/${DEPLOY_USER}/.hushlogin
            chown ${DEPLOY_USER}:${DEPLOY_USER} /home/${DEPLOY_USER}/.hushlogin
        fi
    fi

    if [ "$DISTRIB_RELEASE" = "18.04" ]; then
        if [ ! -e "/usr/local/bin/composer" ]; then
            echo "Updating global Composer ..."
            curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
        fi
    fi
}

function install_configure_postgres {
    # DB server
    echo "${GREEN}Install PG specific packages ...${RESET}"

    echo "${GREEN}Install EPEL packages ...${RESET}"
    sudo yum -d1 -q -y install sipcalc ccze yum-utils

    #sudo yum install -d1 -y http://yum.postgresql.org/11/redhat/rhel-7-x86_64/pgdg-redhat11-11-2.noarch.rpm
    #sudo yum -d1 -q -y install http://yum.postgresql.org/11/redhat/rhel-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
    sudo yum -d1 -q -y install https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm

    #sudo yum -y install https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm

    echo "Disable stock postgresql..."
    sudo yum-config-manager  --save --setopt=base.exclude=postgres*;
    sudo yum-config-manager  --save --setopt=updates.exclude=postgres*;

    echo "Install PG 11 packages ..."
    sudo yum-config-manager --enable pgdg11

    sudo yum -d1 -q -y install postgresql11.x86_64 postgresql11-contrib.x86_64 postgresql11-libs.x86_64 postgresql11-server.x86_64 python36

    echo "Install PG 11 extensions ..."
    sudo yum -d1 -q -y install repmgr_11.x86_64 powa_11.x86_64 pg_stat_kcache_11.x86_64 pg_qualstats_11.x86_64 pg_repack_11.x86_64
    #sudo yum -d1 -q -y install powa_11-web.x86_64  # powaweb is not resolving ok in repo

    #echo "Install PG 11 barman cli ..."
    #sudo yum -d1 -q -y install barman-cli

    echo "Init database ... $1 / $2 "
    sudo /usr/pgsql-11/bin/postgresql-11-setup initdb

    echo "Enable startup service database ... $1 / $2 "
    sudo systemctl enable --now postgresql-11

    echo "Status database ... $1 / $2 "
    sudo systemctl status postgresql-11

    echo "${GREEN}Checking if postgres is installed ...${RESET}"
    # test for postgres install
    if isinstalled postgresql11 ; then
		echo "${GREEN}Tuning configuration${RESET}"
        #echo "Setting up shared mem"
        #chmod +x /usr/local/bin/shmsetup.sh
        #/usr/local/bin/shmsetup.sh >> /etc/sysctl.conf

        echo "${GREEN}Installing postgres DB server ...${RESET}"

        PGCONF="/var/lib/pgsql/11/data/postgresql.conf"
        PGHBA="/var/lib/pgsql/11/data/pg_hba.conf"

        # enable listen
        if [ -e "${PGCONF}" ]; then
            echo "Enable listening on all interfaces"
            sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" ${PGCONF}
            echo "Configuring shared buffers"
            page_size=`getconf PAGE_SIZE`
            phys_pages=`getconf _PHYS_PAGES`

            if [ -z "phys_pages" ]; then
                echo "Error:  cannot determine page size"
            else
                shmall=`expr $phys_pages / 2`
                shmmax=`expr $shmall \* $page_size`
                echo "Maximum shared segment size in bytes: ${shmmax}"
                # converting this to a safe GB value for postgres
                sed -i -r "s|#?effective_cache_size =".*"$|effective_cache_size = ${PGEFFECTIVE}MB|" ${PGCONF}

                postgres_shared=`expr $shmmax / 1024 / 1024 / 1000`

                echo "Postgres shared buffer size in GB: ${postgres_shared}"
                echo "Configuring memory settings"
                sed -i "s/shared_buffers = 128MB/shared_buffers = ${postgres_shared}GB/" ${PGCONF}
                sed -i "s/#work_mem = 4MB/work_mem = 8MB/" ${PGCONF}
                sed -i "s/#maintenance_work_mem = 64MB/maintenance_work_mem = 2048MB/" ${PGCONF}
                sed -i "s/#max_files_per_process = 1000/max_files_per_process = 10000/" ${PGCONF}
                sed -i "s/#full_page_writes = on/full_page_writes = on/" ${PGCONF}
                sed -i "s/#fsync = on/fsync = off/" ${PGCONF}
                sed -i "s/#synchronous_commit = on/synchronous_commit = off/" ${PGCONF}
                sed -i "s/#wal_level = minimal/wal_level = minimal/" ${PGCONF}
                sed -i "s/#temp_buffers = 8MB/temp_buffers = 32MB/" ${PGCONF}
                echo "Configuring checkpoint settings"
                sed -i "s/#checkpoint_timeout = 5min/checkpoint_timeout = 20min/" ${PGCONF}
                sed -i "s/#max_wal_size = 1GB/max_wal_size = 2GB/" ${PGCONF}
                sed -i "s/#checkpoint_completion_target = 0.5/checkpoint_completion_target = 0.7/" ${PGCONF}
            fi
            echo "Done with changing postgresql settings, we need to restart postgres for them to take effect"
			echo "${GREEN}Restarting Postgresql 11 ${RESET}"
    		systemctl restart postgresql-11
        fi

        # set permissions
        if [ -e "${PGHBA}" ]; then
            #echo "host    all             all             $SUBNET           trust" >> /etc/postgresql/10/main/pg_hba.conf
            #sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" ${PGCONF}
            sed -i "s/host    all             all             127.0.0.1\/32            md5/#host    all             all             127.0.0.1\/32            md5/" ${PGHBA}
            echo "host    all             all             127.0.0.1/32           trust" >> ${PGHBA}
        fi

        #echo "Welcome to Resource ${RESOURCE_INDEX} - ${HOSTNAME} (${IP})"

        # install my .psqlrc file
        # cp /tmp/rcfiles/psqlrc /var/lib/postgresql/.psqlrc
    fi

}


function configure_credentials {
    ## Fix DEPLOY_USER ssh Permissions
    if [ ! -d "/home/${DEPLOY_USER}/.ssh" ]; then
        echo "Creating user SSH dir if it does not exists"
        mkdir /home/${DEPLOY_USER}/.ssh
        chmod 700 /home/${DEPLOY_USER}/.ssh
        chown ${DEPLOY_USER}:${DEPLOY_USER} /home/${DEPLOY_USER}/.ssh
    fi

    ## concat the deployment pub keys into authorize
    if [ -d "/root/.ssh" ]; then
        # for root
        if [ ! -e "/root/.ssh/authorized_keys" ]; then
            [ -r /vagrant/scripts/authorized.default ] && cat /vagrant/scripts/authorized.default /root/.ssh/deployment_*.pub >> /root/.ssh/authorized_keys
            [ -r /root/.ssh/authorized_keys ] && chmod 644 /root/.ssh/authorized_keys
        fi
        # for user
        # deploy keys
        if [ -r "/vagrant/scripts/authorized.default" ]; then
            if [ ! -e "/home/${DEPLOY_USER}/.ssh/authorized_keys" ]; then
                cat /vagrant/scripts/authorized.default /root/.ssh/deployment_*.pub >> /home/${DEPLOY_USER}/.ssh/authorized_keys
                # individual user keys (start with user_* )
                cat /vagrant/scripts/authorized.default /root/.ssh/user_*.pub >> /home/${DEPLOY_USER}/.ssh/authorized_keys
                chown ${DEPLOY_USER}:${DEPLOY_USER} /home/${DEPLOY_USER}/.ssh/authorized_keys
                chmod 644 /home/${DEPLOY_USER}/.ssh/authorized_keys
            fi
        fi
    fi

    ## Copy all deployment keys priv/public to the deploy user ssh dir
    if [ -d "/root/.ssh" ]; then
        if [ -r "/root/.ssh/config" ]; then
            if [ ! -e "/home/${DEPLOY_USER}/.ssh/config" ]; then
                cp /root/.ssh/config /home/${DEPLOY_USER}/.ssh/
                cp /root/.ssh/deployment_* /home/${DEPLOY_USER}/.ssh/
                chown ${DEPLOY_USER}:${DEPLOY_USER} /home/${DEPLOY_USER}/.ssh/deployment_*
            fi
        fi
    fi
}

echo "${GREEN}Start provisioning postgresql ${RESET}"

#fix_locales
#create_deploy_user
#install_extra_packages
#yum_update
install_configure_packages
install_git_repos
#make_work_dirs
#configure_credentials
#create_pgpass
install_configure_postgres
#load_postgres_sqlfiles
#create_bash_alias

echo "${GREEN}Provisioning done${RESET}"

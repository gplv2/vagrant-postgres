#!/usr/bin/env bash 

set -o allexport
source /vagrant/scripts/variables
set +o allexport

# Screen colors using tput
RED=`tput setaf 1`
GREEN=`tput setaf 2`
RESET=`tput sgr0` 

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
  if dnf list installed "$@" >/dev/null 2>&1; then
    true
  else
    false
  fi
}

function install_configure_packages {
    # not used now, too soon for some packages
    echo "${GREEN}Installing node tool${RESET}"

     echo "${GREEN}Installing NPM${RESET}"
     sudo curl -sL https://rpm.nodesource.com/setup_20.x | sudo bash -

     sudo dnf -d1 -q -y install nodejs 

     echo "${GREEN}Installing npm hosts tool${RESET}"
     # install hosts tool to intelligently modify /etc/hosts
     sudo npm config set loglevel warn
     sudo npm install --global hosts.sh | true
     sudo npm install --global sprintf-js | true
     sudo npm install --global parse-key-value | true

     # get our service IP address
     # MY_IP=$(ifconfig | sed -n '/^eth1:/,/^$/p' | grep -oP 'inet\s+\K[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
     # export IP=$MY_IP

     #sed -i 's/GSSAPIAuthentication yes/GSSAPIAuthentication no/g' /etc/ssh/sshd_config
     #sudo service sshd restart
}

function load_postgres_sqlfiles {
    echo "${GREEN}load sql files${RESET}"
    # create alter list
    su - postgres -c "psql -qAtX -d ${DATA_DB} -c \"${MOVESQL}\" > /tmp/alter.pre.ts1.sql 2>/dev/null"

    MOVESQL="SELECT ' ALTER TABLE ' || schemaname || '.' || tablename || ' SET TABLESPACE pg_default;' FROM pg_tables WHERE schemaname NOT IN ('pg_catalog', 'information_schema');"

    # create alter list
    su - postgres -c "psql -qAtX -d ${DB} -c \"${MOVESQL}\" > /tmp/alter.pre.ts2.sql 2>/dev/null"

    echo "${GREEN}Moving data + indexes to tablespace${RESET}"
    su - postgres -c "cat /tmp/alter.pre.ts2.sql | psql -d ${DATA_DB}"

}

function create_pgpass {
    echo "${GREEN}Create pgpass${RESET}"
    # detect the home of postgres user
    PGHOME=`getent passwd postgres | awk -F: '{ print $6 }'`
    PGPASS=${PGHOME}/.pgpass

    if [ ! -e "${PGPASS}" ]; then
        echo "${GREEN}Checking pgpass${RESET}"
        if [ -z "$DB" ] ; then
            DB="*"
        fi
        echo "Creating ${PGPASS}"
        echo "*:${PORT}:${DB}:repmgr:${REPMGR_PASSWORD}" > $PGPASS
        echo "*:${PORT}:${DB}:repmgr:${REPMGR_PASSWORD}" >> $PGPASS
        if ! [ -z "$USER" ] ; then
            echo "localhost:${PORT}:${DATA_DB}:${USER}:${PASSWORD}" >> $PGPASS
            echo "127.0.0.1:${PORT}:${DATA_DB}:${USER}:${PASSWORD}" >> $PGPASS
        fi

        chown -R postgres:postgres $PGPASS  # $PGRC
        PERMS=$(stat -c "%a" ${PGPASS})
        if [ ! "${PERMS}" = "0600" ]; then
            chmod 0600 ${PGPASS}
        fi
    fi
}

function create_pgrc {
   echo "${GREEN}Create .pgrc${RESET}"
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

function dnf_update {
    echo "${GREEN}Updating DNF system${RESET}"
    dnf -d1 -q -y update
    echo "${GREEN}Update done${RESET}"
}

function make_work_dirs {
    echo "${GREEN}Creating dirs${RESET}"
    CREATEDIRS="/usr/local/src/example /var/log/otherexample"

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

function install_epel_9 {
    echo "${GREEN}Install EPEL packages ...${RESET}"
    #sudo dnf -d1 -q -y install sipcalc ccze dnf-utils

    #sudo dnf -d1 -q -y install https://download.postgresql.org/pub/repos/dnf/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm
    sudo dnf -d1 -q -y install https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm

    echo "Install EPEL release ..."
    sudo dnf install -y epel-release
    sudo dnf config-manager --set-enabled epel

    echo "Running EPEL update ..."
    sudo dnf update -y

    echo "Install Extra packages ..."
    sudo dnf -d1 -y install haproxy keepalived pgbouncer git openssl curl wget net-tools psmisc tcpdump

    echo "Haproxy ..."
    sudo systemctl enable --now haproxy
    sudo systemctl status haproxy

    echo "Keepalived ..."
    sudo systemctl enable --now keepalived
    sudo systemctl status keepalived

    echo "PG Bouncer ..."
    sudo systemctl enable --now pgbouncer
    sudo systemctl status pgbouncer
    sudo systemctl stop pgbouncer

}

function install_configure_postgres {
    # DB server
    echo "${GREEN}Install PG specific packages ...${RESET}"

    echo "Disable stock postgresql..."
    sudo dnf -qy module disable postgresql
    #sudo dnf-config-manager  --save --setopt=base.exclude=postgres* 1> /dev/null 2>&1
    #sudo dnf-config-manager  --save --setopt=updates.exclude=postgres* 1> /dev/null 2>&1

    echo "Install PG ${PGVERSION} packages ..."
    #sudo dnf-config-manager --enable pgdg${PGVERSION} 1> /dev/null 2>&1

    sudo dnf install -y postgresql${PGVERSION}-server postgresql${PGVERSION}

    echo "Install PG ${PGVERSION} extensions ..."
    sudo dnf -d1 -y install repmgr_${PGVERSION}.x86_64 powa_${PGVERSION}.x86_64 pg_stat_kcache_${PGVERSION}.x86_64 pg_qualstats_${PGVERSION}.x86_64 pg_repack_${PGVERSION}.x86_64
    #sudo dnf -d1 -q -y install powa_${PGVERSION}-web.x86_64  # powaweb is not resolving ok in repo

    #echo "Install PG ${PGVERSION} barman cli ..."
    #sudo dnf -d1 -q -y install barman-cli

    echo "Init database ..."
    sudo /usr/pgsql-${PGVERSION}/bin/postgresql-${PGVERSION}-setup initdb

    echo "Enable startup service database ..."
    sudo systemctl enable --now postgresql-${PGVERSION}

    echo "Status database ..."
    sudo systemctl status postgresql-${PGVERSION}

    echo "${GREEN}Checking if postgres is installed ...${RESET}"
    # test for postgres install
    if isinstalled postgresql${PGVERSION} ; then
        echo "${GREEN}Tuning configuration${RESET}"
        #echo "Setting up shared mem"
        #chmod +x /usr/local/bin/shmsetup.sh
        #/usr/local/bin/shmsetup.sh >> /etc/sysctl.conf

        echo "${GREEN}Installing postgres DB server ...${RESET}"

        PGCONF="/var/lib/pgsql/${PGVERSION}/data/postgresql.conf"
        PGHBA="/var/lib/pgsql/${PGVERSION}/data/pg_hba.conf"

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
                postgres_shared=`expr $shmmax / 1024 / 1024 / 1000`
                echo "Postgres shared buffer size in GB: ${postgres_shared}"
                # converting this to a safe GB value for postgres
                sed -i "s/shared_buffers = 128MB/shared_buffers = ${postgres_shared}GB/" ${PGCONF}
                echo "Maximum shared segment size in bytes: ${shmmax}"
                #  see scripts/variables for sizing calculations
                sed -i -r "s|#?effective_cache_size =".*"$|effective_cache_size = ${PGEFFECTIVE}MB|" ${PGCONF}

                echo "Configuring memory settings"
                sed -i "s/#port = 5432/port = ${PORT}/" ${PGCONF}
                sed -i "s/#work_mem = 4MB/work_mem = 8MB/" ${PGCONF}
                sed -i "s/#maintenance_work_mem = 64MB/maintenance_work_mem = 1024MB/" ${PGCONF}
                sed -i "s/#max_files_per_process = 1000/max_files_per_process = 10000/" ${PGCONF}
                sed -i "s/#full_page_writes = on/full_page_writes = on/" ${PGCONF}
                sed -i "s/#fsync = on/fsync = off/" ${PGCONF}
                sed -i "s/#synchronous_commit = on/synchronous_commit = off/" ${PGCONF}
                sed -i "s/#wal_level = minimal/wal_level = replica/" ${PGCONF}
                sed -i "s/#temp_buffers = 8MB/temp_buffers = 32MB/" ${PGCONF}
                echo "Configuring checkpoint settings"
                sed -i "s/#checkpoint_timeout = 5min/checkpoint_timeout = 20min/" ${PGCONF}
                sed -i "s/#max_wal_size = 1GB/max_wal_size = 2GB/" ${PGCONF}
                sed -i "s/#checkpoint_completion_target = 0.5/checkpoint_completion_target = 0.7/" ${PGCONF}
                echo "Activating wal log hints"
                sed -i "s/#wal_log_hints = off/wal_log_hints = on/" ${PGCONF}
            fi
            echo "Done with changing postgresql settings, we need to restart postgres for them to take effect"
            echo "${GREEN}Restarting Postgresql ${PGVERSION} ${RESET}"
            systemctl restart postgresql-${PGVERSION}
        fi
        #sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" ${PGCONF}
    
        # set the port up in the profile , important when not using standard port
        sudo su -l postgres -c "echo \"PGPORT=${PORT}\" >> .bash_profile"
        sudo su -l postgres -c "echo \"export PGPORT\" >> .bash_profile"

        IPRANGE=$(get_eth1_pg_hba_entry)

        line_number=$(grep -n "local   all             al" ${PGHBA} | head -n 1 | cut -d: -f1)
        line_to_insert="host    repmgr             repmgr             ${IPRANGE}           trust"
        # Check if the string was found
        if [ -n "$line_number" ]; then
            # Insert the line before the found line
            sed -i "${line_number}a ${line_to_insert}" ${PGHBA}
            echo "Inserted '${line_to_insert}' at line ${line_number} in ${PGHBA}"
        else
            echo "Local line definition not found in ${PGHBA}"
        fi

        # set permissions
        if [ -e "${PGHBA}" ]; then
            #echo "host    all             all             $SUBNET           trust" >> /etc/postgresql/10/main/pg_hba.conf
            sed -i "s/host    all             all             127.0.0.1\/32            md5/#host    all             all             127.0.0.1\/32            md5/" ${PGHBA}
            sed -i "s/host    all             all             127.0.0.1\/32            scram-sha-256/#host    all             all             127.0.0.1\/32            scram-sha-256/" ${PGHBA}
            echo "host    all             all             127.0.0.1/32           trust" >> ${PGHBA}
        fi

        #echo "Welcome to Resource ${RESOURCE_INDEX} - ${HOSTNAME} (${IP})"

        # install my .psqlrc file
        # cp /tmp/rcfiles/psqlrc /var/lib/postgresql/.psqlrc
    fi

    # Setup trust on postgresql user level
    PGHOME=`getent passwd postgres | awk -F: '{ print $6 }'`
    # create the .ssh directories and files , which will be overwritten by a shared local generated one
    sudo su -l postgres -c "ssh-keygen -t rsa -q -f \"${PGHOME}/.ssh/id_rsa\" -N \"\""

    # now copy over the ones from tmp that was generated locally
    sudo cat /vagrant/tmp/id_rsa > ${PGHOME}/.ssh/id_rsa
    sudo cat /vagrant/tmp/id_rsa.pub > ${PGHOME}/.ssh/id_rsa.pub
    sudo cat /vagrant/tmp/id_rsa.pub > ${PGHOME}/.ssh/authorized_keys
    #sudo chown -R postgres:postgres /var/lib/pgsql/.ssh
    sudo chown -R postgres:postgres ${PGHOME}/.ssh/authorized_keys
    sudo chmod 644 ${PGHOME}/.ssh/authorized_keys
    #sudo chmod 600 /var/lib/pgsql/.ssh/id_rsa

#    i=0
#    while read line
#    do
#        host_ips[ $i ]="$line"        
#        (( i++ ))
#    done < <(cat /vagrant/iplist.txt)
#
#    for ip in "${host_ips[@]}"
#    do
#        echo "Scanning host key: ${ip}"
#        sudo su -l postgres -c "ssh-keyscan ${ip} >> ~/.ssh/known_hosts"
#    done

}

function add_ssh_opts {
    echo "${GREEN}Create SSH config for user postgres${RESET}"
    PGHOME=`getent passwd postgres | awk -F: '{ print $6 }'`
    SSH_CONFIG=${PGHOME}/.ssh/config

    if [ ! -e "${SSH_CONFIG}" ]; then
        echo "${GREEN}Creating config${RESET}"

        sudo cat /vagrant/scripts/ssh_config > ${SSH_CONFIG} 
        sudo chown postgres:postgres ${SSH_CONFIG}
        PERMS=$(stat -c "%a" ${SSH_CONFIG})
        if [ ! "${PERMS}" = "0400" ]; then
            sudo chmod 0400 ${SSH_CONFIG}
        fi
    fi
}

function add_hosts {
    echo "${GREEN}Add /etc/hosts entries${RESET}"
    if [ -r "/vagrant/addhosts.sh" ]; then
        chmod +x /vagrant/addhosts.sh
        /vagrant/addhosts.sh
    fi
}

function add_psql_profile {
    echo "${GREEN}Add default psql profile to system${RESET}"
    PSQL="/vagrant/scripts/psql.sh"
    PROF="/etc/profile.d/psql.sh"
    if [ -r "${PSQL}" ]; then
        cat ${PSQL} | sed "s/PGVERSION/${PGVERSION}/" > ${PROF}
        chown root:root ${PROF}
        chmod +x ${PROF}
    fi
}

function configure_credentials {
    echo "${GREEN}Configure the credentials for ${DEPLOY_USER} ${RESET}"
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

function config_sysctl {
    echo "${GREEN}Configure sysctl.conf${RESET}"
    if [ -r "/vagrant/sys/add_sysctl.conf" ]; then
        cat /vagrant/sys/add_sysctl.conf >> /etc/sysctl.conf
        sysctl -p
    fi
}

function get_eth1_pg_hba_entry() {
  local interface="eth1"
  local eth1_ip
  local cidr
  local network_address

  # Get the IP of eth1 excluding the VIP
  eth1_ip=$(ip -o -f inet addr show "$interface" | awk '{print $4}' | grep -E '^192\.168\.56\.' | cut -d/ -f1)

  # Ensure eth1_ip is set and not empty
  if [ -z "$eth1_ip" ]; then
    echo "Error: Could not find a valid local IP for $interface."
    return 1
  fi

  # Calculate the CIDR and network address for PostgreSQL pg_hba.conf
  cidr=$(ip -o -f inet addr show "$interface" | awk '{print $4}' | grep -E '^192\.168\.56\.' | head -n 1 | cut -d/ -f2)

  if [ -z "$cidr" ]; then
    echo "Error: Could not determine CIDR for $interface."
    return 1
  fi

  # Convert CIDR to network address
  calculate_network_address() {
    local ip="$1"
    local prefix="$2"
    local IFS=.
    read -r i1 i2 i3 i4 <<<"$ip"
    local mask=$((0xffffffff << (32 - prefix)))
    printf "%d.%d.%d.%d/%d\n" \
      $((i1 & (mask >> 24 & 0xff))) \
      $((i2 & (mask >> 16 & 0xff))) \
      $((i3 & (mask >> 8 & 0xff))) \
      $((i4 & (mask & 0xff))) \
      "$prefix"
  }

  network_address=$(calculate_network_address "$eth1_ip" "$cidr")

  if [ -z "${network_address}" ]; then
    echo "Error: Failed to calculate network address."
    return 1
  fi

  # Output results
  #echo "Local IP: $eth1_ip"
  #echo "pg_hba.conf Entry: $network_address"
  echo ${network_address}
}

function config_haproxy_generator {
    echo "${GREEN}Generate haproxy file${RESET}"
    PGHBA="/var/lib/pgsql/${PGVERSION}/data/pg_hba.conf"
    if [ -r "/home/vagrant/haproxy-postgresql/create_haproxy_check.py" ]; then
        echo "${GREEN}Found haproxy generator${RESET}"
        if [ -e "${PGHBA}" ]; then
            echo "Creating config.py ..."
            /vagrant/scripts/create_haconfig_ini.sh
            echo "${GREEN}Found pg_hba file${RESET}"
            cd /home/vagrant/haproxy-postgresql && /home/vagrant/haproxy-postgresql/create_haproxy_check.py standby ${PROJECT_NAME} >> ${PGHBA}
        # add access for all the rest in the network
            echo "host    all             all             ${PG_HBA_NET}           md5" >> ${PGHBA}
            echo "${GREEN}Reloading Postgresql ${PGVERSION} ${RESET}"
            systemctl reload postgresql-${PGVERSION}
        fi
    fi
}

function configure_haproxy {
    echo "${GREEN}Stopping haproxy${RESET}"
    service haproxy stop

    mkdir /etc/haproxy/certs.d
    echo "Create dhparam file..."
    sudo openssl dhparam -dsaparam -out /etc/haproxy/dhparam.pem 4096
    echo "Reconfiguring haproxy ..."
    cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg_orig
    cp /home/vagrant/haproxy-postgresql/configs/${PROJECT_NAME}/haproxy-${PROJECT_NAME}.cnf /etc/haproxy/haproxy.cfg
    chown -R root:root /etc/haproxy/haproxy.cfg
    echo "${GREEN}Starting haproxy${RESET}"
    service haproxy start
}

function make_pg_sudoers {
    echo "${GREEN}Add postgres to sudoer${RESET}"
    if [ -r "/vagrant/scripts/postgres" ]; then
        cp /vagrant/scripts/postgres /etc/sudoers.d/
        chmod 440 /etc/sudoers.d/postgres
    fi
}

echo "${GREEN}Start provisioning postgresql ${RESET}"


IPRANGE=$(get_eth1_pg_hba_entry)

echo $IPRANGE

exit

#fix_locales
#create_deploy_user
#install_extra_packages
dnf_update
install_epel_9
install_configure_packages
install_git_repos
#make_work_dirs
#configure_credentials
install_configure_postgres
create_pgpass
add_ssh_opts
add_psql_profile
make_pg_sudoers
add_hosts
config_sysctl
config_haproxy_generator
configure_haproxy
dnf_update
#load_postgres_sqlfiles
#create_bash_alias

echo "${GREEN}Provisioning done${RESET}"

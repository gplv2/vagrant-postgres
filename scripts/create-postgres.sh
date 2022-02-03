#!/usr/bin/env bash
echo "Installing postgres repositories ..."

sudo yum -y install https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm

sudo yum -y install epel-release yum-utils
sudo yum-config-manager --enable pgdg${PGVERSION}

echo "Installing postgres ... "

sudo yum -y install postgresql${PGVERSION}-server postgresql${PGVERSION}


echo "Init database ... "
sudo /usr/pgsql-${PGVERSION}/bin/postgresql-${PGVERSION}-setup initdb

echo "Enable startup service database ... "
sudo systemctl enable --now postgresql-${PGVERSION}

echo "Start database ... "
systemctl status postgresql-${PGVERSION}

exit 0

echo "Preparing Database content ... "

DB=$1;
USER=$2;

# su postgres -c "dropdb $DB --if-exists"

if ! su - postgres -c "psql -d $DB -c '\q' 2>/dev/null"; then
    su - postgres -c "createuser $USER"
    su - postgres -c "createdb --encoding='utf-8' --owner=$USER '$DB'"
fi

echo "Changing user password ..."
cat > /home/vagrant/install.postcreate.sql << EOF
ALTER USER "$USER" WITH PASSWORD 'Berkensap${PGVERSION}';
EOF

su - postgres -c "cat /home/vagrant/install.postcreate.sql | psql -d $DB"


#!/usr/bin/env bash
echo "Installing postgres repositories ... $1 / $2 "

sudo yum -y install https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm

sudo yum -y install epel-release yum-utils
sudo yum-config-manager --enable pgdg12

echo "Installing postgres ... $1 / $2 "

sudo yum install postgresql12-server postgresql12


echo "Init database ... $1 / $2 "
sudo /usr/pgsql-12/bin/postgresql-12-setup initdb

echo "Enable startup service database ... $1 / $2 "
sudo systemctl enable --now postgresql-12

echo "Start database ... $1 / $2 "
systemctl status postgresql-12

exit 0

echo "Preparing Database content ... $1 / $2 "

DB=$1;
USER=$2;

# su postgres -c "dropdb $DB --if-exists"

if ! su - postgres -c "psql -d $DB -c '\q' 2>/dev/null"; then
    su - postgres -c "createuser $USER"
    su - postgres -c "createdb --encoding='utf-8' --owner=$USER '$DB'"
fi

echo "Changing user password ..."
cat > /home/vagrant/install.postcreate.sql << EOF
ALTER USER "$USER" WITH PASSWORD 'Berkensap11';
EOF

su - postgres -c "cat /home/vagrant/install.postcreate.sql | psql -d $DB"


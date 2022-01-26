#!/usr/bin/env bash
echo "Preparing Database ... $1 / $2 "

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


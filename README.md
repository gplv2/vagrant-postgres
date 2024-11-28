# What this is

## UPDATE

The code has changed to add a few optimisations and also to move towards a more recent distribution.  As EL9 becomes the default this vagrant POC reflects this shift.

This vagrant is a local instance of what is used in real life production.  It will build a cluster of Postgres database machines of postgres that will:

 - Be under control of repmgr
 - with a VIP managed by keepalived
 - master/slave HA 'sensing' by custom haproxy test configuration with https://github.com/gplv2/haproxy-postgresql
 - multi slave support
 - uses RockyLinux because we use Redhat profesionally
 - pgbouncer in front of DB, behind haproxy

## Different postgres versions supported

~~Tested version at the moment  : PG 11 and PG 12, PG 13~~
Tested version at the moment  : PG 16 on RockyLinux 9.4
Set your version in the scripts/variables file 

## how to run
 - first create the postgresql shared key to setup trust : vagrant push
 - then : vagrant up
 - and of course: vagrant ssh db1 , db2 etc

# Your systems looks ready to test, now you can play and test things out 
Visit the haproxy url to see who is master : http://192.168.56.111:8182/haproxy?stats
In case you cannot access directly, there's a portforward (8183 , 8184 , etc per node) towards this interface.
You should be able to reach by visiting the IP of the vagrant host and use the forwarded ports.

Login in the second node: vagrant ssh db2 and switch over the cluster like this:

    sudo su -
    su - postgres
    repmgr cluster show
    repmgr standby switchover

Then visit the haproxy url and see the role switch result

To connect to the 'testdb' database you can use different ports which will mean different services

# Haproxy (HA/VIP):
Connect to the HA port psql postgres://test:Iceball1@192.168.56.5:5432/testdb

# Database (direct/VIP):

    psql postgres://test:Iceball1@192.168.56.5:6432/testdb

# Pgbouncer (VIP):

    psql postgres://test:Iceball1@192.168.56.5:7432/testdb

It's important to understand the differences between those 3 ports
Flow is :  HAPROXY -> PGBOUNCER -> DATABASE

Why pgbouncer on localhost :

Excellent article: https://www.depesz.com/2012/12/02/what-is-the-point-of-bouncing/

# About this setup
Every server has a pgbouncer, database and haproxy instance present (and of course a keepalived install)
keepalived will only handle the VIP address, haproxy will only listen on port 5432 on the vip ip and is the only one that will, but since each node has 
a haproxy running at all times but it's only listening on the VIP.

So it's important to understand that when connecting to the VIP IP that you always land on the machine where keepalived owns the vip.
This doesn't mean its the postgresql master server.
The postgresql master server can be diffent from the keepalived master, they are not related at all, they operate independant

You can still connect to a specific server by using the non-vip IP's

You might have to play with the IP's as I sometimes change and not update this doc. use common sense.

## Connect directly to the DB on node1 (db1)

    psql postgres://test:Iceball1@192.168.56.11:6432/testdb

## Connect directly to the DB on node2 (db2)

    psql postgres://test:Iceball1@192.168.56.12:6432/testdb

## Connect indirectly to the DB via pgbouncer on node1 (db1)

    psql postgres://test:Iceball1@192.168.56.11:7432/testdb

## Connect indirectly to the DB via pgbouncer on node2 (db2)

    psql postgres://test:Iceball1@192.168.56.12:7432/testdb

# playtime

Now it's time to have some fun watching keepalived in action
Log into keepalived active node (ssh to the vip using vagrant user)

    vagrant ssh db1

Check if the vip ip is present:

    type ip a

Kill or stop keepalived

   check again :

    ip a

It should be gone now and present on the other node

Test the database connection to the VIP:

    psql postgres://test:Iceball1@192.168.56.111:5432/testdb

Also check the haproxy interface, should still work again, but the name of the node has changed
Visit the haproxy url to see who is master : http://192.168.56.111:8182/haproxy?stats


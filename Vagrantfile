# -*- mode: ruby -*-
# vi: set ft=ruby :

BOX_IMAGE = "bento/centos-7"
#BOX_IMAGE = "centos/7"
NODE_COUNT = 2
IP_PREFIX="192.168.88."

counter = 0

# create ip list for the nodes to use
def this(file)
  i = 0
  until i>=NODE_COUNT.to_int
    i+=1
    ip=IP_PREFIX+"#{i + 10}"
    # Normally 'puts' writes to the standard output stream (STDOUT)
    # which appears on the terminal, but it can also write directly
    # to a file ...
    file.puts ip
  end
end

# create ip list for the nodes to use
def hosts(file)
  i = 0
  until i>=NODE_COUNT.to_int
    i+=1
    ip=IP_PREFIX+"#{i + 10}"
    name="node"+"#{i}"
    # Normally 'puts' writes to the standard output stream (STDOUT)
    # which appears on the terminal, but it can also write directly
    # to a file ...
    file.puts 'hosts --auto-sudo add ' + ip + ' ' + name
  end
end

filename = "iplist.txt"
addhosts = "addhosts.sh"

# Open file for writing
File.open(filename, 'w') do |file|
  # call the method, passing in the file object
  this(file)
  # file is automatically closed when block is done
end

# Open file for writing
File.open(addhosts, 'w') do |file|
  # call the method, passing in the file object
  hosts(file)
  # file is automatically closed when block is done
end

Vagrant.configure("2") do |config|
    # The most common configuration options are documented and commented below.
    # For a complete reference, please see the online documentation at
    # https://docs.vagrantup.com.
    #  create ip list
    # Configure Local Variable To Access Scripts From Remote Location

#    config.trigger.after :up do |trigger|
#      trigger.name = "Register keys"
#      trigger.info = "Accepting hosts keys for all machine"
#      trigger.run_remote = { inline: "/vagrant/scripts/keys.sh" }
#    end

    (1..NODE_COUNT).each do |i|
        config.vm.define "db#{i}" do |subconfig|
            # Every Vagrant development environment requires a box. You can search for
            # boxes at https://atlas.hashicorp.com/search.
            subconfig.vm.box = BOX_IMAGE
            subconfig.vm.hostname = "db#{i}"

            #subconfig.vm.network "private_network", ip: "192.168.50.5"
            subconfig.vm.network :private_network, ip: IP_PREFIX+"#{i + 10}"

            scriptDir = File.dirname(__FILE__)
            localscriptDir = "/vagrant/scripts"
            dbUser = "postgres"
            dbName = "cluster"

            # Disable automatic box update checking. If you disable this, then
            # boxes will only be checked for updates when the user runs
            # `vagrant box outdated`. This is not recommended.
            # config.vm.box_check_update = false

            # Create a forwarded port mapping which allows access to a specific port
            # within the machine from a port on the host machine. In the example below,
            # accessing "localhost:8080" will access port 80 on the guest machine.
            # NOTE: This will enable public access to the opened port
            # config.vm.network "forwarded_port", guest: 80, host: 8080

            # Create a forwarded port mapping which allows access to a specific port
            # within the machine from a port on the host machine and only allow access
            # via 127.0.0.1 to disable public access
            # config.vm.network "forwarded_port", guest: 80, host: 8080, host_ip: "127.0.0.1"

            # Create a private network, which allows host-only access to the machine
            # using a specific IP.
            # config.vm.network "private_network", ip: "192.168.33.10"

            # Create a public network, which generally matched to bridged network.
            # Bridged networks make the machine appear as another physical device on
            # your network.
            # config.vm.network "public_network"

            # Share an additional folder to the guest VM. The first argument is
            # the path on the host to the actual folder. The second argument is
            # the path on the guest to mount the folder. And the optional third
            # argument is a set of non-required options.
            # subconfig.vm.synced_folder "../data", "/vagrant_data"
            #
            # this doesn't work too well , it resizes the disk but not the partition and the image doesn't use lvm
            # subconfig.vm.disk :disk, size: "100GB", primary: true
            #
            # need to export this variable on the shell first to have this feature
            # it will create a new disk called /dev/sdb and you need to mange it yourself
            # export VAGRANT_EXPERIMENTAL="disks"
            # it seem to work ok, it would be the disk to put postgresql data on when using big databases
            # subconfig.vm.disk :disk, size: "100GB", name: "extra_disk"

            subconfig.vm.provider "virtualbox" do |v|
                v.customize ["modifyvm", :id, "--memory", 4096 ]
                v.customize ["modifyvm", :id, "--cpus", 4 ]
                v.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
                v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
                v.customize ["modifyvm", :id, "--ostype", "Centos_64"]
                v.gui = false
            end

            subconfig.vm.provision "shell" do |s|
              ssh_pub_key = File.readlines("#{Dir.home}/.ssh/id_rsa.pub").first.strip
              s.inline = <<-SHELL
              echo #{ssh_pub_key} >> /home/vagrant/.ssh/authorized_keys
              SHELL
            end

            subconfig.vm.provision "shell" do |s|
                s.name = "Installing vagrant bootstrap"
                s.inline = "sudo " + localscriptDir + "/install.sh"
                counter+=1
            end

            # keepalived setup
            subconfig.vm.provision "shell" do |s|
              # make the last one the master for keepalived, it doesn't really matter for keepalived who is who
              if(i == NODE_COUNT) then
                s.name = "Configuring keepalived master node"
                s.inline = "sudo /vagrant/keepalived/keepalived.sh -m master"
              else
                s.name = "Configuring keepalived standby node"
                s.inline = "sudo /vagrant/keepalived/keepalived.sh -m standby"
              end
              counter+=1
            end

            # repmgr setup
            name="node"+"#{i}"
            number="#{i}"
            subconfig.vm.provision "shell" do |s|
              # make nr 1 the master so the rest can clone from it
              if(i == 1) then
                s.name = "configuring repmgr master node"
                s.inline = "sudo /vagrant/repmgr/repmgr.sh -m master -n " + name + " -i " + number
              else
                s.name = "configuring repmgr slave node"
                s.inline = "sudo /vagrant/repmgr/repmgr.sh -m standby -n " + name + " -i " + number
              end
              counter+=1
            end

            # pgbouncer setup
            name="node"+"#{i}"
            number="#{i}"
            subconfig.vm.provision "shell" do |s|
              #
              if(i == 1) then
                s.name = "configuring pgbouncer master node"
                s.inline = "sudo /vagrant/pgbouncer/pgbouncer.sh -m master -n " + name + " -i " + IP_PREFIX+"#{i + 10}"
              else
                s.name = "configuring pgbouncer slave node"
                s.inline = "sudo /vagrant/pgbouncer/pgbouncer.sh -m standby -n " + name + " -i " + IP_PREFIX+"#{i + 10}"
              end
              counter+=1
            end
            # Provider-specific configuration so you can fine-tune various
            # backing providers for Vagrant. These expose provider-specific options.
            # Example for VirtualBox:
            #
            # config.vm.provider "virtualbox" do |vb|
            #   # Display the VirtualBox GUI when booting the machine
            #   vb.gui = true
            #
            #   # Customize the amount of memory on the VM:
            #   vb.memory = "1024"
            # end
            #
            # View the documentation for the provider you are using for more
            # information on available options.
        end
    end
    # for mDNS
    # disabling this crashes virtualbox with a fat error when you try to ping using db1.local of db2.local
    #  HOSTRES[420474]: segfault at 7fa827926888 ip 00007fa8201c9685 sp 00007fa827926888 error 6 in libnss_mdns4_minimal.so.2[7fa8201c9000+2000]
    #    config.vm.provision "shell", inline: <<-SHELL
    #  yum -y install avahi avahi-tools
    #    SHELL
    #
    #  Create the keypair for postgres user to use on both machines
    config.push.define "local-exec" do |push|
      push.inline = <<-SCRIPT
            local/generate_postgres_keypairs.sh
      SCRIPT
    end
end

# if counter == 8 we did all steps successfully, now echo the user the things he can do
if (counter == 8) then
  haproxy_url = "http://192.168.88.5:8182/haproxy?stats"
  puts "Your systems looks ready to test, now you can play and test things out"
  puts "Visit the haproxy url to see who is master : " + String(haproxy_url)
  puts ""
  puts "Login in the second node: vagrant ssh db1 and switch over the cluster like this:"
  puts "sudo su - "
  puts "su - postgres"
  puts "repmgr cluster show"
  puts "repmgr standby switchover"
  puts "Then visit the haproxy url and see the role switch result"
  puts ""
  puts "To connect to the 'testdb' database you can use different ports which will mean different services"
  puts "Haproxy (HA/VIP):"
  puts "Connect to the HA port psql postgres://test:Iceball1@192.168.88.5:5432/testdb"
  puts ""
  puts "Database (direct/VIP):"
  puts "psql postgres://test:Iceball1@192.168.88.5:6432/testdb"
  puts ""
  puts "Pgbouncer (VIP):"
  puts "psql postgres://test:Iceball1@192.168.88.5:7432/testdb"
  puts ""
  puts "It's important to understand the differences between those 3 ports"
  puts "Flow is :  HAPROXY -> PGBOUNCER -> DATABASE"
  puts ""
  puts "Every server has a pgbouncer, database and haproxy instance present (and of course a keepalived install)"
  puts "keepalived will only handle the VIP address, haproxy will only listen on port 5432 on the vip ip and is the only one that will, but since each node has "
  puts "a haproxy running at all times but it's only listening on the VIP."
  puts ""
  puts "So it's important to understand that when connecting to the VIP IP that you always land on the machine where keepalived owns the vip."
  puts "This doesn't mean its the postgresql master server."
  puts "The postgresql master server can be diffent from the keepalived master, they are not related at all, they operate independant"
  puts ""
  puts "You can still connect to a specific server by using the non-vip IP's"
  puts ""
  puts "Connect directly to the DB on node1 (db1)"
  puts "psql postgres://test:Iceball1@192.168.88.11:6432/testdb"
  puts ""
  puts "Connect directly to the DB on node2 (db2)"
  puts "psql postgres://test:Iceball1@192.168.88.12:6432/testdb"
  puts ""
  puts "Connect indirectly to the DB via pgbouncer on node1 (db1)"
  puts "psql postgres://test:Iceball1@192.168.88.11:7432/testdb"
  puts ""
  puts "Connect indirectly to the DB via pgbouncer on node2 (db2)"
  puts "psql postgres://test:Iceball1@192.168.88.12:7432/testdb"
  puts ""
  puts "Now it's time to have some fun watching keepalived in action"
  puts "Log into keepalived active node (ssh to the vip using vagrant user)"
  puts "ssh vagrant@192.168.88.5"
  puts ""
  puts "Check if the vip ip is present:"
  puts "type ip a"
  puts ""
  puts "Kill or stop keepalived"
  puts "check again : ip a"
  puts ""
  puts "It should be gone now and present on the other node"
  puts ""
  puts "Test the database connection to the VIP:"
  puts "psql postgres://test:Iceball1@192.168.88.5:5432/testdb"
  puts ""
  puts "Also check the haproxy interface, should still work again, but the name of the node has changed"
  puts "Visit the haproxy url to see who is master : " + String(haproxy_url)
  puts ""
end

  #
# Check haproxy at http://192.168.88.5:8182/haproxy?stats
# #

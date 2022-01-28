# -*- mode: ruby -*-
# vi: set ft=ruby :

BOX_IMAGE = "bento/centos-7"
#BOX_IMAGE = "centos/7"
NODE_COUNT = 2
IP_PREFIX="192.168.88."

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

filename = "iplist.txt"

# Open file for writing
File.open(filename, 'w') do |file|
  # call the method, passing in the file object
  this(file)
  # file is automatically closed when block is done
end

# create local keys to push
#cmd="local/configure_pg_trust.sh"
#system(cmd)

Vagrant.configure("2") do |config|
    # The most common configuration options are documented and commented below.
    # For a complete reference, please see the online documentation at
    # https://docs.vagrantup.com.
    #  create ip list

    (1..NODE_COUNT).each do |i|
        config.vm.define "db#{i}" do |subconfig|
            # Every Vagrant development environment requires a box. You can search for
            # boxes at https://atlas.hashicorp.com/search.
            subconfig.vm.box = BOX_IMAGE
            subconfig.vm.hostname = "db#{i}"

            #subconfig.vm.network "private_network", ip: "192.168.50.5"
            subconfig.vm.network :private_network, ip: IP_PREFIX+"#{i + 10}"

            # Configure Local Variable To Access Scripts From Remote Location
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

            # Enable provisioning with a shell script. Additional provisioners such as
            # Ansible, Chef, Docker, Puppet and Salt are also available. Please see the
            # documentation for more information about their specific syntax and use.
            # config.vm.provision "shell", inline: <<-SHELL
            #   apt-get update
            #   apt-get install -y apache2
            # SHELL
            #
        end
    end
    # for mDNS
    # disabling this crashes virtualbox with a fat error when you try to ping using db1.local of db2.local
    #  HOSTRES[420474]: segfault at 7fa827926888 ip 00007fa8201c9685 sp 00007fa827926888 error 6 in libnss_mdns4_minimal.so.2[7fa8201c9000+2000]
    #    config.vm.provision "shell", inline: <<-SHELL
    #  yum -y install avahi avahi-tools
    #    SHELL
    config.push.define "local-exec" do |push|
      push.inline = <<-SCRIPT
            local/configure_pg_trust.sh
      SCRIPT
    end
end

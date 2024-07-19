# Docker image to use with Vagrant
# Aims to be as similar to normal Vagrant usage as possible
# Adds Puppet, SSH daemon, Systemd
# Adapted from https://github.com/BashtonLtd/docker-vagrant-images/blob/master/ubuntu1404/Dockerfile

FROM ubuntu:22.04
ENV container=docker
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Brussels

EXPOSE 5432
EXPOSE 3306

RUN apt-get upgrade
RUN apt-get update -y && apt-get dist-upgrade -y

RUN apt-get update -y && apt-get -y install mariadb-server tzdata sudo systemd openssh-client puppet haproxy 
RUN apt-get install -y keepalived pgbouncer git openssl curl wget net-tools psmisc tcpdump haproxy keepalived pgbouncer 
RUN apt-get install -y git openssl curl wget net-tools psmisc tcpdump sipcalc software-properties-common
RUN apt-get install -y vim curl wget gpg gnupg2 apt-transport-https lsb-release ca-certificates
RUN apt-get clean

# Install system dependencies, you may not need all of these
RUN apt-get install -y --no-install-recommends ssh libffi-dev systemd openssh-client

# Install ansible
RUN apt-add-repository -y ppa:ansible/ansible
RUN apt-get update -y 
RUN apt-get install -y ansible

# Needed to run systemd
# VOLUME [ "/sys/fs/cgroup" ]
# Doesn't appear to be necessary? See comments

RUN curl -fsSL https://deb.nodesource.com/setup_22.x -o nodesource_setup.sh
RUN sudo -E bash nodesource_setup.sh
RUN apt-get install -y nodejs

RUN npm config set loglevel warn
RUN npm install --global hosts.sh | true
RUN npm install --global sprintf-js | true
RUN npm install --global parse-key-value | true

# Add vagrant user and key for SSH
RUN useradd --create-home -s /bin/bash vagrant
RUN echo -n 'vagrant:vagrant' | chpasswd
RUN echo 'vagrant ALL = NOPASSWD: ALL' > /etc/sudoers.d/vagrant
RUN chmod 440 /etc/sudoers.d/vagrant
RUN mkdir -p /home/vagrant/.ssh
RUN chmod 700 /home/vagrant/.ssh
RUN echo "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ==" > /home/vagrant/.ssh/authorized_keys
RUN sudo chmod 600 /home/vagrant/.ssh/authorized_keys
RUN sudo chown -R vagrant:vagrant /home/vagrant/.ssh
RUN sed -i -e 's/Defaults.*requiretty/#&/' /etc/sudoers
RUN sed -i -e 's/\(UsePAM \)yes/\1 no/' /etc/ssh/sshd_config

# Start SSH
RUN mkdir /var/run/sshd
EXPOSE 22
RUN /usr/sbin/sshd

# Start Systemd (systemctl)
CMD ["/lib/systemd/systemd"]

#!/bin/bash
if [ `id -u` -ne 0 ]; then
	echo Need sudo
	exit 1
fi

set -v


# install latest packages and securit updates
sudo apt update -y
sudo apt upgrade -y
sudo apt autoremove -y

# basic OS packages
sudo apt install nfs-common net-tools open-vm-tools -y


# cleanup
sudo apt autoremove -y
sudo apt clean

# disable IPv6
echo net.ipv6.conf.all.disable_ipv6=1 | sudo tee -a /etc/sysctl.conf
echo net.ipv6.conf.default.disable_ipv6=1 | sudo tee -a /etc/sysctl.conf
echo net.ipv6.conf.lo.disable_ipv6=1 | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Stop services for cleanup
sudo service rsyslog stop

#clear audit logs
if [ -f /var/log/wtmp ]; then
    sudo truncate -s0 /var/log/wtmp
fi
if [ -f /var/log/lastlog ]; then
    sudo truncate -s0 /var/log/lastlog
fi

# cleanup /tmp directories
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*

# cleanup current ssh keys
sudo rm -f /etc/ssh/ssh_host_*

# add check for ssh keys on reboot...regenerate if neccessary
cat << 'EOL' | sudo tee /etc/rc.local
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.


test -f /etc/ssh/ssh_host_dsa_key || dpkg-reconfigure openssh-server
exit 0
EOL

# make sure the script is executable
sudo chmod +x /etc/rc.local

# reset hostname
# prevent cloudconfig from preserving the original hostname
sudo sed -i 's/preserve_hostname: false/preserve_hostname: true/g' /etc/cloud/cloud.cfg
sudo truncate -s0 /etc/hostname
sudo hostnamectl set-hostname ubuntu-template

# disable swap
sudo swapoff --all
sudo sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab

# make machine-id unique and symlink it - ubuntu 20.04 uses machine id in the dhcp identifier and not mac addresses
sudo truncate -s 0 /etc/machine-id
sudo rm /var/lib/dbus/machine-id
sudo ln -s /etc/machine-id /var/lib/dbus/machine-id

# cleans out all of the cloud-init cache / logs - this is mainly cleaning out networking info
sudo cloud-init clean --logs

# cleanup shell history
cat /dev/null > ~/.bash_history && history -c

echo "run 'sudo shutdown now'"

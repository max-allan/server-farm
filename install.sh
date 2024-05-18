dnf -y install tftp tftp-server syslinux-tftpboot syslinux dhcp-server nfs-utils nginx

cp dhcpd.conf /etc/dhcp/dhcpd.conf
IF=$(nmcli -t -f NAME c show --active | grep -v ^lo$)
IP=$nmcli -t -f IP4.ADDRESS c show $IF | cut -f2 -d: | cut -d/ -f1)

echo 'INTERFACESv4="'$IF'"' >  /etc/default/isc-dhcp-server

systemctl start dhcpd

sed -i s+/var/lib/tftpboot+/tftpboot+ /usr/lib/systemd/system/tftp.service

# mkdir /tftpboot/pxelinux.cfg
# echo "default vesamenu.c32
# prompt 0
# timeout 1
# display boot.msg
# label linux
#   menu label ^Install system
#   menu default
#   kernel images/CentOS-7/vmlinuz
#   append initrd=images/CentOS-7/initrd.img ip=dhcp inst.repo=http://$IP/mnt/archive/CentOS/7/Server/x86_64/os/

# " > /tftpboot/pxelinux.cfg/default

cp grub.cfg /tftpboot/grub.cfg

systemctl start tftp


mkdir /dvd /src
curl -Lo /src/centos9.iso 'https://mirrors.centos.org/mirrorlist?path=/9-stream/BaseOS/x86_64/iso/CentOS-Stream-9-latest-x86_64-dvd1.iso&redirect=1&protocol=https'

echo "/src/centos9.iso /dvd/ ro 0 2" >> /etc/fstab
systemctl daemon-reload
mount -a

cp nginx.conf /etc/nginx/conf.d


dnf -y install tftp tftp-server syslinux-tftpboot syslinux dhcp-server nfs-utils nginx

cp dhcpd.conf /etc/dhcp/dhcpd.conf
IF=$(nmcli -t -f NAME c show --active | grep -v ^lo$)
IP=$(nmcli -t -f IP4.ADDRESS c show ${IF} | cut -f2 -d: | cut -d/ -f1)
# Add 10.99 address for DHCP network
nmcli con mod ${IF} +ipv4.ADDRESS 10.99.99.1/24
nmcli con up ${IF}

echo 'INTERFACESv4="'$IF'"' >  /etc/default/isc-dhcp-server

systemctl start dhcpd
systemctl enable dhcpd

sed -i s+/var/lib/tftpboot+/tftpboot+ /usr/lib/systemd/system/tftp.service

mkdir /tftpboot/pxelinux.cfg
echo "default centos9
label centos9
  kernel images/centos9/vmlinuz
  append initrd=images/centos9/initrd.img ip=dhcp root=nfs:${IP}:/client1 rw selinux=0
" > /tftpboot/pxelinux.cfg/default
# Do some checking to get the client1's mac address and replace default with 01-mac
# https://wiki.syslinux.org/wiki/index.php?title=PXELINUX


# Then make a default like this so other clients can do an install:
# echo "default vesamenu.c32
# display boot.msg
# label linux
#   menu label ^Install system
#   menu default
#   kernel images/centos9/vmlinuz
#   append initrd=images/centos9/initrd.img ip=dhcp inst.repo=http://$IP/centos9/BaseOS/
# " > /tftpboot/pxelinux.cfg/default

systemctl start tftp
systemctl start nfs-server
systemctl enable tftp
systemctl enable nfs-server



mkdir /dvd /src
curl -Lo /src/centos9.iso 'https://mirrors.centos.org/mirrorlist?path=/9-stream/BaseOS/x86_64/iso/CentOS-Stream-9-latest-x86_64-dvd1.iso&redirect=1&protocol=https'

echo "/src/centos9.iso /dvd/ iso9660 loop,ro 0 2" >> /etc/fstab
systemctl daemon-reload
mount -a

mkdir /tftpboot/images/centos9
cp /dvd/images/pxeboot/{vmlinuz,initrd.img} /tftpboot/images/centos9

cp dvd.conf /etc/nginx/conf.d


mkdir /src/root-common
dnf group -y install "Server with GUI" --installroot=/src/root-common

for n in $(seq 1 5) ; do
    mkdir -p /src/client${n}/{work,root} /client${n}
    #mount -t overlay overlay -o  index=on,nfs_export=on,lowerdir=/src/root-common,upperdir=/src/client${n}/root,workdir=/src/client${n}/work /client${n}
    echo "overlay /client${n} overlay  index=on,nfs_export=on,lowerdir=/src/root-common,upperdir=/src/client${n}/root,workdir=/src/client${n}/work 0 0" >> /etc/fstab
    echo "/client${n} 10.99.99.0/24(sync)" >> /etc/exports
done
mount -a
exportfs -a

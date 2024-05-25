dnf -y install tftp tftp-server syslinux-tftpboot syslinux dhcp-server nfs-utils nginx

cp dhcpd.conf /etc/dhcp/dhcpd.conf
IF=$(nmcli -t -f NAME c show --active | grep -v ^lo$)
IP=$(nmcli -t -f IP4.ADDRESS c show ${IF} | cut -f2 -d: | cut -d/ -f1)
# Assumes a /24. If you don't have a subnet on a word boundary, sucks to be you
SUBNET=$(nmcli -t -f IP4.ADDRESS c show ${IF} | cut -f2 -d: | sed -E "s+(.*)\..*\/(.*)+\1.0\/\2+")
# Add 10.99 address for DHCP network
IP10=10.99.99.1
nmcli con mod ${IF} +ipv4.ADDRESS ${IP10}/24
nmcli con up ${IF}

echo 'INTERFACESv4="'$IF'"' >  /etc/default/isc-dhcp-server

systemctl enable --now dhcpd

sed -i s+/var/lib/tftpboot+/tftpboot+ /usr/lib/systemd/system/tftp.service

mkdir /tftpboot/pxelinux.cfg
echo "default centos9
label centos9
  kernel images/centos9/vmlinuz
  append initrd=images/centos9/initrd.img ip=dhcp root=nfs:${IP}:/client1 rw selinux=0
" > /tftpboot/pxelinux.cfg/default

#Post boot the client will re-request DHCP and this time get the main DHCP server, not us.
# Hence $IP

# Do some checking to get the client1's mac address and replace default with 01-mac
# https://wiki.syslinux.org/wiki/index.php?title=PXELINUX


# Then make a default like this so other clients can do an install:
# echo "default vesamenu.c32
# display boot.msg
# label linux
#   menu label ^Install system
#   menu default
#   kernel images/centos9/vmlinuz
#   append initrd=images/centos9/initrd.img ip=dhcp inst.repo=http://${IP}/centos9/BaseOS/
# " > /tftpboot/pxelinux.cfg/default


systemctl enable --now tftp
systemctl enable --now nfs-server

firewall-cmd --add-service=tftp
firewall-cmd --add-service=nfs
firewall-cmd --runtime-to-permanent


mkdir /dvd /src
curl -Lo /src/centos9.iso 'https://mirrors.centos.org/mirrorlist?path=/9-stream/BaseOS/x86_64/iso/CentOS-Stream-9-latest-x86_64-dvd1.iso&redirect=1&protocol=https'

echo "/src/centos9.iso /dvd/ iso9660 loop,ro 0 2" >> /etc/fstab
systemctl daemon-reload
mount -a

mkdir -p /tftpboot/images/centos9
cp /dvd/images/pxeboot/{vmlinuz,initrd.img} /tftpboot/images/centos9

cp dvd.conf /etc/nginx/conf.d


mkdir /src/root-common

# Add this to DNF to only use local repo: --repofrompath dvd,/dvd/BaseOS --repo dvd  


dnf --repofrompath dvd,/dvd/BaseOS --repo dvd group -y install "Server with GUI" --installroot=/src/root-common

for n in $(seq 1 5) ; do
    mkdir -p /src/client${n}/{work,root} /client${n}
    #mount -t overlay overlay -o  index=on,nfs_export=on,lowerdir=/src/root-common,upperdir=/src/client${n}/root,workdir=/src/client${n}/work /client${n}
    echo "overlay /client${n} overlay  index=on,nfs_export=on,lowerdir=/src/root-common,upperdir=/src/client${n}/root,workdir=/src/client${n}/work 0 0" >> /etc/fstab
    echo "/client${n} 1${SUBNET}(rw,no_root_squash)" >> /etc/exports
done
mount -a
exportfs -a

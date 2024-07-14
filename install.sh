dnf -y install tftp tftp-server syslinux-tftpboot syslinux dnsmasq nfs-utils nginx


IF=$(nmcli -t -f NAME c show --active | grep -v ^lo$)
IP=$(nmcli -t -f IP4.ADDRESS c show ${IF} | cut -f2 -d: | cut -d/ -f1)
# Assumes a /24. If you don't have a subnet on a word boundary, sucks to be you
SUBNET=$(nmcli -t -f IP4.ADDRESS c show ${IF} | cut -f2 -d: | sed -E "s+(.*)\..*\/(.*)+\1.0\/\2+")


envsubst '$IP' < dhcpd.conf  > /etc/dnsmasq.d/dhcpd.conf

systemctl enable --now dhcpd

sed -i s+/var/lib/tftpboot+/tftpboot+ /usr/lib/systemd/system/tftp.service

mkdir /tftpboot/pxelinux.cfg
# This makes a machine that will try to boot a root file system over nfs from /client1.
# echo "default centos9
# label centos9
#   kernel images/centos9/vmlinuz
#   append initrd=images/centos9/initrd.img ip=dhcp root=nfs:${IP}:/client1 rw selinux=0
# " > /tftpboot/pxelinux.cfg/default



# Do some checking to get the client1's mac address and replace the file "default" with "01-mac"
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

# OR with http kickstart file:
# DEFAULT vesamenu.c32
# PROMPT 0
# LABEL centos9
#   menu label ^Network installation 
#   kernel images/centos9/vmlinuz
#   append initrd=images/centos9/initrd.img ip=dhcp inst.ks=http://${IP}/ks/client1.cfg inst.sshd

# AND Local booting:
# This is needed if you have buggy PXE bios:
# LABEL localboot
#   MENU LABEL Boot from first hard drive
#   COM32 chain.c32
#   APPEND hd0
#   MENU default
# If your BIOS is good:
# LABEL bootlocal0
#   menu label ^Boot Normally 0
#   LOCALBOOT 0


systemctl enable --now tftp
systemctl enable --now nfs-server

firewall-cmd --add-service=tftp
firewall-cmd --add-service=nfs
firewall-cmd --add-port 4011/udp  # "pxe" service
firewall-cmd --runtime-to-permanent


mkdir /dvd /src
curl -Lo /src/centos9.iso 'https://mirrors.centos.org/mirrorlist?path=/9-stream/BaseOS/x86_64/iso/CentOS-Stream-9-latest-x86_64-dvd1.iso&redirect=1&protocol=https'

echo "/src/centos9.iso /dvd/ iso9660 loop,ro 0 2" >> /etc/fstab
systemctl daemon-reload
mount -a

mkdir -p /tftpboot/images/centos9
cp /dvd/images/pxeboot/{vmlinuz,initrd.img} /tftpboot/images/centos9

cp dvd.conf /etc/nginx/conf.d

# If running diskless:
# mkdir /src/root-common
# dnf --repofrompath dvd,/dvd/BaseOS --repo dvd group -y install "Server with GUI" --installroot=/src/root-common
# for n in $(seq 1 5) ; do
#     mkdir -p /src/client${n}/{work,root} /client${n}
#     #mount -t overlay overlay -o  index=on,nfs_export=on,lowerdir=/src/root-common,upperdir=/src/client${n}/root,workdir=/src/client${n}/work /client${n}
#     echo "overlay /client${n} overlay  index=on,nfs_export=on,lowerdir=/src/root-common,upperdir=/src/client${n}/root,workdir=/src/client${n}/work 0 0" >> /etc/fstab
#     echo "/client${n} 1${SUBNET}(rw,no_root_squash)" >> /etc/exports
# done
# mount -a
# exportfs -a


# If running installer, you need to create config files in  /usr/share/nginx/html/ks/client1.cfg
mkdir -p /usr/share/nginx/html/ks
for CLIENT in $(seq 1 5) ; do
  envsubst '$IP $CLIENT' < client.cfg > /usr/share/nginx/html/ks/client${CLIENT}.cfg
done

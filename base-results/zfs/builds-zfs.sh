#!/bin/bash

KERNEL=$(uname -r)

wget https://repo.percona.com/apt/percona-release_0.1-4.$(lsb_release -sc)_all.deb
sudo dpkg -i percona-release_0.1-4.xenial_all.deb
sudo apt -y update
sudo apt -y upgrade
sudo apt -y install sysbench make percona-toolkit percona-xtrabackup-24 \
  pmm-client qpress netcat socat sysstat mbuffer lsof

sudo apt -y install build-essential autoconf libtool gawk alien fakeroot linux-headers-$(uname -r)
sudo apt -y install zlib1g-dev uuid-dev libattr1-dev libblkid-dev libselinux-dev libudev-dev libssl-dev
sudo apt -y install parted lsscsi ksh dkms dstat

git clone https://github.com/zfsonlinux/spl
git clone https://github.com/zfsonlinux/zfs

cd spl
rm -rf *.deb
git checkout master
sh autogen.sh
./configure
make -s -j$(nproc)
make deb

REL=$(ls | grep "kmod-spl-${KERNEL}"|cut -d'_' -f2)
sudo dpkg -i kmod-spl-${KERNEL}_${REL}_amd64.deb \
  kmod-spl-devel-${KERNEL}_${REL}_amd64.deb \
  spl_${REL}_amd64.deb spl-dkms_${REL}_all.deb

cd ../zfs
rm -rf *.deb
git checkout master
sh autogen.sh
./configure
make -s -j$(nproc)
make deb

REL=$(ls | grep "kmod-zfs-${KERNEL}"|cut -d'_' -f2)
sudo dpkg -i kmod-zfs-${KERNEL}_${REL}_amd64.deb \
  kmod-zfs-devel-${KERNEL}_${REL}_amd64.deb \
  libnvpair1_${REL}_amd64.deb libuutil1_${REL}_amd64.deb \
  libzfs2_${REL}_amd64.deb libzfs2-devel_${REL}_amd64.deb \
  libzpool2_${REL}_amd64.deb zfs_${REL}_amd64.deb \
  zfs-dkms_${REL}_all.deb zfs-dracut_${REL}_amd64.deb \
  zfs-initramfs_${REL}_amd64.deb zfs-test_${REL}_amd64.deb

sudo /sbin/modprobe zfs

sudo zpool create -o ashift=12 mysql \
    mirror /dev/disk/by-id/scsi-3600508b1001cc3a31e419c48f7f6ae86 /dev/disk/by-id/scsi-3600508b1001caa8b1c116bffbfb91b0d \
    mirror /dev/disk/by-id/scsi-3600508b1001ce8b59d5201a88209fe26 /dev/disk/by-id/scsi-3600508b1001ce7fd1a8c931814d6d720 \
    mirror /dev/disk/by-id/scsi-3600508b1001c124cfc259205fca8cda8 /dev/disk/by-id/wwn-0x600508b1001c38ba7c81eac03f530687
sudo zfs set recordsize=16k mysql
sudo zfs set atime=off mysql
sudo zfs set logbias=throughput mysql
sudo zfs set primarycache=metadata mysql
sudo zfs set compression=lz4 mysql

sudo zfs create -o recordsize=128K mysql/logs
sudo zfs create -o recordsize=16K mysql/data

sudo mkdir -p /mysql/logs
sudo mkdir -p /mysql/data
sudo chown -R revin.revin /mysql/*

echo '#!/bin/bash' > /tmp/zfs.sh
echo 'echo 1073741824 > /sys/module/zfs/parameters/zfs_arc_max' >> /tmp/zfs.sh
echo 'echo 1 > /sys/module/zfs/parameters/zfs_prefetch_disable' >> /tmp/zfs.sh
sudo bash /tmp/zfs.sh

#cd ~
#wget https://github.com/datacharmer/mysql-sandbox/releases/download/3.2.14/MySQL-Sandbox-3.2.14.tar.gz
#tar xzf MySQL-Sandbox-3.2.14.tar.gz
#cd MySQL-Sandbox-3.2.14/
#perl Makefile.PL PREFIX=/usr
#make
#sudo make install
#cd
#mkdir mysql
#cd mysql
#wget https://www.percona.com/downloads/Percona-Server-LATEST/Percona-Server-5.7.19-17/binary/tarball/Percona-Server-5.7.19-17-Linux.x86_64.ssl100.tar.gz
#tar xzf Percona-Server-5.7.19-17-Linux.x86_64.ssl100.tar.gz
#mv -f Percona-Server-5.7.19-17-Linux.x86_64.ssl100 5.7.190

#sudo ln -s /lib/x86_64-linux-gnu/libssl.so.1.0.0 /lib/x86_64-linux-gnu/libssl.so.10
#sudo ln -s /lib/x86_64-linux-gnu/libcrypto.so.1.0.0 /lib/x86_64-linux-gnu/libcrypto.so.10

env SANDBOX_BINARY=/home/revin/mysql make_sandbox 5.7.190 -- --no_confirm \
  --upper_directory=/mysql/data --my_clause=innodb_buffer_pool_size=60G \
  --my_clause=innodb_log_file_size=8G --my_clause=innodb_flush_method=O_DSYNC \
  --my_clause=innodb_log_group_home_dir=/mysql/logs --my_clause=innodb_numa_interleave=ON \
  --my_clause=innodb_doublewrite=0 --my_clause=innodb_flush_log_at_trx_commit=1 \
  --my_clause=innodb_checksum_algorithm=crc32 --my_clause=innodb_log_checksums=ON \
  --my_clause=innodb_io_capacity=600 --my_clause=log-bin=mysql-bin --my_clause=server-id=1 \
  --my_clause=log-bin=/mysql/logs/mysql-bin

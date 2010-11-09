#!/bin/sh
#
# Install Debian Squeeze on DockStar

# Copyright (c) 2010 Jeff Doozan
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

# Version 1.0   [8/8/2010] Initial Release

MIRROR="http://jeff.doozan.com/debian"

# Definitions

# Download locations
MKE2FS_URL=$MIRROR/mke2fs
BLPARAM_URL=$MIRROR/blparam
PKGDETAILS_URL=$MIRROR/pkgdetails
#neuer debootstrap
URL_DEBOOTSTRAP=http://ftp.de.debian.org/debian/pool/main/d/debootstrap/debootstrap_1.0.25_all.deb

# Default binary locations
MKE2FS=/sbin/mke2fs
PKGDETAILS=/usr/share/debootstrap/pkgdetails

# Where should the temporary 'debian root' be mounted
ROOT=/tmp/debian

# debootstrap configuration
RELEASE=squeeze
VARIANT=minbase
MIRROR=http://ftp.de.debian.org/debian/

# if you want to install additional packages, add them to the end of this list
EXTRA_PACKAGES=module-init-tools,udev,netbase,ifupdown,iproute,openssh-server,dhcpcd,iputils-ping,wget,net-tools,ntpdate,ftpd,uboot-mkimage,uboot-envtools,vim-tiny,dialog,psmisc,samba,nfs-kernel-server,nfs-common,portmap,apt-utils,rdate,mc,zip,unzip,bzip2,language-env,console-common,locales


#########################################################
#  There are no user-serviceable parts below this line
#########################################################

RO_ROOT_=0

TIMESTAMP=$(date +"%d%m%Y%H%M%S")
touch /sbin/$TIMESTAMP
if [ ! -f /sbin/$TIMESTAMP ]; then
  RO_ROOT=1
else
  rm /sbin/$TIMESTAMP
fi

verify_md5 ()
{
  local file=$1
  local md5=$2

  local check_md5=$(cat "$md5" | cut -d' ' -f1) 
  local file_md5=$(md5sum "$file" | cut -d' ' -f1)  

  if [ "$check_md5" = "$file_md5" ]; then
    return 0
  else
    return 1
  fi
}

download_and_verify ()
{
  local file_dest=$1
  local file_url=$2

  local md5_dest="$file_dest.md5"
  local md5_url="$file_url.md5"

  # Always download a fresh MD5, in case a newer version is available
  if [ -f "$md5_dest" ]; then rm -f "$md5_dest"; fi
  wget -O "$md5_dest" "$md5_url"
  # retry the download if it failed
  if [ ! -f "$md5_dest" ]; then
    wget -O "$md5_dest" "$md5_url"
    if [ ! -f "$md5_dest" ]; then
      return 1 # Could not get md5
    fi
  fi

  # If the file already exists, check the MD5
  if [ -f "$file_dest" ]; then
    verify_md5 "$file_dest" "$md5_dest"
    if [ "$?" -ne "0" ]; then
      rm -f "$md5_dest"
      return 0
    else
      rm -f "$file_dest"
    fi
 fi

  # Download the file
  wget -O "$file_dest" "$file_url"
  # retry the download if it failed
  verify_md5 "$file_dest" "$md5_dest"
  if [ "$?" -ne "0" ]; then  
    # Download failed or MD5 did not match, try again
    if [ -f "$file_dest" ]; then rm -f "$file_dest"; fi
    wget -O "$file_dest" "$file_url"
    verify_md5 "$file_dest" "$md5_dest"
    if [ "$?" -ne "0" ]; then  
      rm -f "$md5_dest"
      return 1
    fi
  fi

  rm -f "$md5_dest"
  return 0
}

install ()
{
  local file_dest=$1
  local file_url=$2   
  local file_pmask=$3  # Permissions mask
  
  echo "# checking for $file_dest..."

  # Install target file if it doesn't already exist
  if [ ! -s "$file_dest" ]; then
    echo ""
    echo "# Installing $file_dest..."

    # Check for read-only filesystem by testing
    #  if we can delete the existing 0 byte file
    #  or, if we can create a 0 byte file
    local is_readonly=0
    if [ -f "$file_dest" ]; then
      rm -f "$file_dest" 2> /dev/null
    else
      touch "$file_dest" 2> /dev/null
    fi
    if [ "$?" -ne "0" ]; then
      local is_readonly=0
      mount -o remount,rw /
    fi
    rm -f "$file_dest" 2> /dev/null
        
    download_and_verify "$file_dest" "$file_url"
    if [ "$?" -ne "0" ]; then
      echo "## Could not install $file_dest from $file_url, exiting."
      if [ "$is_readonly" = "1" ]; then
        mount -o remount,ro /
      fi
      exit 1
    fi

    chmod $file_pmask "$file_dest"

    if [ "$is_readonly" = "1" ]; then
      mount -o remount,ro /
    fi

    echo "# Successfully installed $file_dest."
  fi

  return 0
}

clear

if ! which chroot >/dev/null; then
    echo ""
    echo ""
    echo ""
    echo ""
    echo "Cannot find chroot.  You need to update your PATH."
    echo "Run the following command and then run this script again:"
    echo ""
    echo 'try to set export PATH=$PATH:/sbin:/usr/sbin'
    echo ""
    echo ""
  export PATH=$PATH:/sbin:/usr/sbin
fi

if ! which chroot >/dev/null; then
  echo ""
  echo ""
  echo ""
  echo "ERROR. CANNOT CONTINUE."
  echo ""
  echo "Cannot find chroot.  You need to update your PATH."
  echo "Run the following command and then run this script again:"
  echo ""
  exit 1
fi

echo ""
echo " -----------------------------------------------------------"
echo " | Debian Squeeze install script mod by Gorgone Jeff basis |"
echo " -----------------------------------------------------------"
echo ""
echo " Before running this script, you should have"
echo " used fdisk to create the following partitions:"
echo ""
echo " /dev/sda1 (Linux ext2, at least 400MB) 1,5Gb for oscam"
echo " /dev/sda2 (Linux swap, recommended 256MB)"
echo ""
echo ""
echo " This script will DESTROY ALL EXISTING DATA on /dev/sda1"
echo " Please double check that the device on "
echo " /dev/sda1 is the correct device."
echo ""
echo " By typing ok, you agree to assume all liabilities and risks"
echo " associated with running this installer."
echo ""
echo -n " If everything looks good, type 'ok' to continue: "

read IS_OK
if [ "$IS_OK" != "OK" -a "$IS_OK" != "Ok" -a "$IS_OK" != "ok" ];
then
  echo "Exiting..."
  exit
fi

#-------------------------------------------------------------
#Flashing PART
#-------------------------------------------------------------
clear

echo ""
echo " ------------------------------------------------------"
echo " | Flashing Dockstars internel Memory !!!!!!!!!!!!!!! |"
echo " ------------------------------------------------------"
echo ""
echo "      This script will REPLACE the BOOTLOADER"
echo "      or the COMPLETE Pogo Dockstar System !!"
echo "      Please be sure what you want to do !!!!"
echo ""
echo ""
echo "-------------------------------------------------------"
echo "| type UBOOT in uppercase to flash bootloader only    |"
echo "| type RESCUE in uppercase to flash the rescue System |"
echo "| type 0 (zero) to skip Flashing the Dockstar         |"
echo "-------------------------------------------------------"
echo ""
echo -n "type UBOOT/RESCUE/0 : "

read IS_FLASING

if [ "$IS_FLASING" = "UBOOT" ];
then
    cd /tmp
    wget http://jeff.doozan.com/debian/uboot/install_uboot_mtd0.sh
    chmod +x install_uboot_mtd0.sh
    export PATH=$PATH:/usr/sbin:/sbin
    ./install_uboot_mtd0.sh
fi

if [ "$IS_FLASING" = "RESCUE" ];
then
    cd /tmp
    wget http://jeff.doozan.com/debian/rescue/install_rescue.sh
    chmod +x install_rescue.sh
    export PATH=$PATH:/usr/sbin:/sbin
    ./install_rescue.sh
fi

#-------------------------------------------------------------
#Flashing PART Done
#-------------------------------------------------------------

#ROOT STICK Definitions
ROOT_DEV=/dev/sda1 # Don't change this, uboot expects to boot from here
SWAP_DEV=/dev/sda2

# Create the mount point if it doesn't already exist
if [ ! -f $ROOT ];
then
  mkdir -p $ROOT
fi

# Get the source directory
SRC=$ROOT

##########
##########
#
# Format /dev/sda
#
##########
##########

umount $ROOT > /dev/null 2>&1

if ! which mke2fs >/dev/null; then
  install "$MKE2FS"         "$MKE2FS_URL"          755
else
  MKE2FS=$(which mke2fs)
fi

$MKE2FS $ROOT_DEV
/sbin/mkswap $SWAP_DEV

mount $ROOT_DEV $ROOT

if [ "$?" -ne "0" ]; then
  echo "Could not mount $ROOT_DEV on $ROOT"
  exit 1
fi
clear

##########
##########
#
# Download debootstrap
#
##########
##########

if [ ! -e /usr/sbin/debootstrap ]; then
  mkdir /tmp/debootstrap
  cd /tmp/debootstrap
  wget -O debootstrap.deb $URL_DEBOOTSTRAP
  ar xv debootstrap.deb
  tar -xzvf data.tar.gz

  if [ "$RO_ROOT" = "1" ]; then
    mount -o remount,rw /
  fi
  mv ./usr/sbin/debootstrap /usr/sbin
  mv ./usr/share/debootstrap /usr/share

  install "$PKGDETAILS" "$PKGDETAILS_URL" 755

  if [ "$RO_ROOT" = "1" ]; then
    mount -o remount,ro /
  fi
fi

##########
##########
#
# Run debootstrap
#
##########
##########

echo ""
echo ""
echo "# Starting debootstrap installation"

# Squeeze
/usr/sbin/debootstrap --verbose --arch=armel --variant=$VARIANT --include=$EXTRA_PACKAGES $RELEASE $ROOT $MIRROR

if [ "$?" -ne "0" ]; then
  echo "debootstrap failed."
  echo "See $ROOT/debootstrap/debootstrap.log for more information."
  exit 1
fi

cat <<END > $ROOT/etc/apt/apt.conf
APT::Install-Recommends "0";
APT::Install-Suggests "0";
END

clear
cd /tmp
echo ""
echo ""
echo "get Gorgone Dockstar Heavy Kernel Package"
echo "-----------------------------------------"
echo ""
wget http://ss4200.homelinux.com/dockstar/gogokernel.tar.gz
echo ""
echo "Install Kernel & Module"
echo "-----------------------"
echo ""
tar xzf gogokernel.tar.gz -C /tmp/debian/
echo ""
echo "Apply LED / DATE /Other Fixes"
echo ""

echo debian > $ROOT/etc/hostname
echo LANG=C > $ROOT/etc/default/locale

cat <<END > $ROOT/etc/fw_env.config
# MTD device name	Device offset	Env. size	Flash sector size	Number of sectors
/dev/mtd0 0xc0000 0x20000 0x20000
END

#nfs lock fix 
echo "blacklist ipv6" >$ROOT/etc/modprobe.d/blacklist.conf

#zoneinfo Berlin
cp -f $ROOT/usr/share/zoneinfo/Europe/Berlin $ROOT/etc/localtime

#udev-fix
sed 's/log_warning_msg ".udev\/ already exists on the static $udev_root!"/rm -R \/dev\/.udev/g' $ROOT/etc/init.d/udev >/tmp/udev
chmod 777 /tmp/udev
cp -f /tmp/udev $ROOT/etc/init.d/udev
sed 's/LABEL="acl_end/LABEL="acl_end"/g' $ROOT/lib/udev/rules.d/70-acl.rules >/tmp/70-acl.rules
cp -f /tmp/70-acl.rules $ROOT/lib/udev/rules.d/70-acl.rules

cat <<END > $ROOT/etc/network/interfaces
auto lo eth0
iface lo inet loopback
iface eth0 inet dhcp
END

#nfs share
echo "" >>$ROOT/etc/exports
echo "/mnt *(rw,async,no_subtree_check,fsid=0,insecure)" >>$ROOT/etc/exports

#apt expand
echo "deb http://ftp.de.debian.org/debian squeeze main contrib non-free" >$ROOT/etc/apt/sources.list
echo "deb http://security.debian.org squeeze/updates main contrib non-free" >>$ROOT/etc/apt/sources.list
#quick default samba
mv $ROOT/etc/samba/smb.conf $ROOT/etc/samba/smb.conf.orginal
cat <<END > $ROOT/etc/samba/smb.conf
;========================= Global Settings =====================================
[global]
        dns proxy = no
        domain master = no
        hostname lookups = yes
        ldap ssl = No
        load printers = no
        null passwords = yes
        security = share
        server signing = Auto
        server string = Dockstar
        syslog only = yes
        wins support = no
        workgroup = Workgroup

;=========================== Share Settings =====================================
[mnt]
        browsable = yes
        guest ok = yes
        path = /mnt/
        public = yes
        use sendfile = yes
        writable = yes

END

cat <<END > $ROOT/etc/fstab
# /etc/fstab: static file system information.
#
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
/dev/root      /               ext2    noatime,errors=remount-ro 0 1
$SWAP_DEV      none            swap    sw                0       0
tmpfs          /tmp            tmpfs   defaults          0       0
END

cat <<END > $ROOT/etc/rc.local
#!/bin/sh -e
#
# set date
rdate ptbtime1.ptb.de >/dev/null &
#
#oscam system compat
echo 2 > /proc/cpu/alignment
#
#set LED
echo default-on > /sys/class/leds/dockstar\:green\:health/trigger
echo none       > /sys/class/leds/dockstar\:orange\:misc/trigger
#
END

#halt-led-off
sed '
/halt -d -f $netdown $poweroff $hddown/ a\
        echo none > \/sys\/class/leds/dockstar\\:green\\:health\/trigger
' $ROOT/etc/init.d/halt >/tmp/halt
chmod 777 /tmp/halt
cp -f /tmp/halt $ROOT/etc/init.d/halt

#login
cat <<END > $ROOT/etc/motd.tail

   ---------------------------
   | Seagate Dockstar System |
   ---------------------------

END

clear
echo ""
echo " -------------------------"
echo " | USE DHCP or STATIC IP |"
echo " -------------------------"
echo ""
echo " if u want to use STATIC IP type S"
echo " Please be careful if is an "
echo " incorrect ip u cant access to the stik"
echo " and the setup must be restarted"
echo ""
echo " if u want to use DHCP(dynamic) IP type D"
echo " DHCP is RECOMMENDED"
echo ""
echo -n " [D]HCP or [S]TATIC : "

read IS_STATIC

if [ "$IS_STATIC" != "s" -a "$IS_STATIC" != "S" ];
then
    echo ""
    echo " USE DHCP..."
    echo ""
else
    echo ""
    echo " USE STATIC IP..."
    echo " ----------------"
    echo ""
    echo -n " IP ADDRESS : "
    read IS_IP
    echo -n " NETMASK    : "
    read IS_NETMASK
    echo -n " GATEWAY    : "
    read IS_GATEWAY
    echo ""
    echo -n " DNS SERVER : "
    read IS_DNS
    echo ""
    echo " this line will add to /etc/network/interfaces"
    echo ""
    echo " iface eth0 inet static"
    echo " address " $IS_IP
    echo " netmask " $IS_NETMASK
    echo " gateway " $IS_GATEWAY
    echo ""
    echo " this line will add to /etc/resolv.conf"
    echo ""
    echo " nameserver " $IS_DNS
    echo ""
    sleep 2
#fill interfaces
    echo "auto lo eth0" >$ROOT/etc/network/interfaces
    echo "" >>$ROOT/etc/network/interfaces
    echo "iface lo inet loopback" >>$ROOT/etc/network/interfaces
    echo "" >>$ROOT/etc/network/interfaces
    echo "iface eth0 inet static" >>$ROOT/etc/network/interfaces
    echo "  address " $IS_IP >>$ROOT/etc/network/interfaces
    echo "  netmask " $IS_NETMASK >>$ROOT/etc/network/interfaces
    echo "  gateway " $IS_GATEWAY >>$ROOT/etc/network/interfaces
    echo "" >>$ROOT/etc/network/interfaces
#fill resolv.conf
    echo " nameserver " $IS_DNS >>$ROOT/etc/resolv.conf
fi

#prepare for oscamready
cd /tmp
wget http://ss4200.homelinux.com/dockstar/prepare
chmod 777 /tmp/prepare
cp -f /tmp/prepare $ROOT/usr/local/bin/prepare

echo 'T0:2345:respawn:/sbin/getty -L ttyS0 115200 linux' >> $ROOT/etc/inittab
sed -i 's/^\([1-6]:.* tty[1-6]\)/#\1/' $ROOT/etc/inittab

#ftpd rootlogin
sed '/root/d' $ROOT/etc/ftpusers >/tmp/ftpusers
cp -f /tmp/ftpusers $ROOT/etc/ftpusers

echo HWCLOCKACCESS=no >> $ROOT/etc/default/rcS
echo CONCURRENCY=shell >> $ROOT/etc/default/rcS

if [ -e $ROOT/etc/blkid.tab ]; then
  rm $ROOT/etc/blkid.tab
fi
ln -s /dev/null $ROOT/etc/blkid.tab

if [ -e $ROOT/etc/mtab ]; then
  rm $ROOT/etc/mtab
fi
ln -s /proc/mounts $ROOT/etc/mtab

echo "root:\$1\$XPo5vyFS\$iJPfS62vFNO09QUIUknpm.:14360:0:99999:7:::" > $ROOT/etc/shadow

##### All Done
cd /
umount $ROOT > /dev/null 2>&1

clear
echo ""
echo " Installation complete"
echo ""
echo " NFS SAMBA FTP ready"
echo ""
echo " The new root password is 'root'"  
echo " Please change it immediately after"
echo " logging in."
echo " FIRST LOGIN START with"
echo ""
echo "   -----------------"
echo "   >>>> prepare <<<<"
echo "   -----------------"
echo ""
echo " for complete Oscam setup install watchdog and links"
echo ""
echo -n "Reboot now? [Y/N] "

read IN_REBOOT
if [ "$IN_REBOOT" = "" -o "$IN_REBOOT" = "n" -o "$IN_REBOOT" = "N" ];
then
    exit
else
    echo "REBOOT......."
    reboot
fi

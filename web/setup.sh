#!/bin/bash
#DEB12 OS level
​
# DEB 12 Startup
#crontab -e
#@reboot /usr/bin/sleep 5; /root/setup.sh 2>&1 | tee /tmp/logsetup.txt
#chmod +x setup.sh
​
# API KEY
API_KEY='a3Bc4D5eF6g7H8i9J0kL1mN2oP3'
​
# creating XML file from VMapp
vmtoolsd --cmd "info-get guestinfo.ovfenv" > /tmp/ovf_env.xml
TMPXML='/tmp/ovf_env.xml'
​
# getting variables from XML 
DEPLOYMENT=`cat $TMPXML| grep -e deployment |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
​
​
if  [ "$DEPLOYMENT" = "true" ]; then
    #IPV4
    IPV4=`cat $TMPXML| grep -e ip0 |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
    GATE4=`cat $TMPXML| grep -e gateway0 |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
    SUBNET4=`cat $TMPXML| grep -e netmask0 |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
    MAINGATE4=`cat $TMPXML| grep -e maingateway |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
​
    # IPV6
    IPV6=`cat $TMPXML| grep -e v6ip0 |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
    GATE6=`cat $TMPXML| grep -e v6gateway0 |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
    SUBNET6=`cat $TMPXML| grep -e v6netmask0 |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
​
    # hostname
    HOSTNAME=`cat $TMPXML| grep -e hostname |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
	DISKRESIZE=`cat $TMPXML| grep -e diskresize |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
​
    # ssh public key
    SSH_PUB=`cat $TMPXML| grep -e ssh_pub | cut -c 47- | rev | cut -c 4- | rev`
    PASSWORD=`cat $TMPXML| grep -e password |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
​
    # Extra IP 1
    EXT_IP1=`cat $TMPXML| grep -e ext1 |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
​
    # Extra IP 2
    EXT_IP2=`cat $TMPXML| grep -e ext2 |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
​
​
    # network file
    NETWORKFILE="/etc/network/interfaces"
	
​
    sed -i "s/IPv4/$IPV4/" $NETWORKFILE
    sed -i "s/IPv6/$IPV6/" $NETWORKFILE
    sed -i "s/SUBNET4/$SUBNET4/" $NETWORKFILE
    sed -i "s/SUBNET6/$SUBNET6/" $NETWORKFILE
    sed -i "s/GATE4/$GATE4/" $NETWORKFILE
    sed -i "s/GATE6/$GATE6/" $NETWORKFILE
	
	if [ $IPV6 ]; then
        echo "iface ens192 inet static" >> $NETWORKFILE
        echo "        address $IPV6/$SUBNET6" >> $NETWORKFILE
        echo "        gateway $GATE6" >> $NETWORKFILE
    fi
​
    # adding extra ip 1 and 2
    if [ $EXT_IP1 ]; then
        echo 'auto ens192:0' >> $NETWORKFILE
        echo 'iface ens192:0 inet static' >> $NETWORKFILE
        echo "        address $EXT_IP1" >> $NETWORKFILE
        echo "        gateway $GATE4" >> $NETWORKFILE
    
​
    fi
	
    if [ $EXT_IP1 ] && [ $EXT_IP2 ]; then
        echo 'auto ens192:1' >> $NETWORKFILE
        echo 'iface ens192:1 inet static' >> $NETWORKFILE
        echo "        address $EXT_IP2" >> $NETWORKFILE
        echo "        gateway $GATE4" >> $NETWORKFILE
​
    else
        echo "not valid extra IP"
	
    fi
	/etc/init.d/networking restart
		#resize disk
	if [ "$DISKRESIZE" = "YES" ]; then
​
		/usr/sbin/parted  /dev/sda mkpart primary ext4 10762 100%
		/usr/sbin/pvcreate pvcreate /dev/sda3
		/usr/sbin/vgextend debian12-vg /dev/sda3
		/usr/sbin/lvextend /dev/debian12-vg/root /dev/sda3
		/usr/sbin/resize2fs /dev/debian12-vg/root
	fi
    # ping gate to find route
    ping -c 2 $MAINGATE4
    # check internet connection
	res=$(ping -c 4 8.8.8.8)
​
	if [[ $res == *"0% packet loss"* ]] || [[ $res == *"25% packet loss"* ]]; then
	echo "VM IS ONLINE"
	else
		/etc/init.d/networking restart	
		TRYAGAIN="YES"
	fi
​
    # check internet connection again
    if  [ "$TRYAGAIN" = "YES" ]; then
		/usr/sbin/ifup ens192 && /usr/sbin/ifdown ens192 && /usr/sbin/ifup ens192
		sleep 2
        ping -c 2 $MAINGATE4
        res=$(ping -c 4 8.8.8.8)
        if [[ $res == *"0% packet loss"* ]] || [[ $res == *"25% packet loss"* ]]; then
		echo "VM IS ONLINE"
        else
			echo $res
			rm -f $TMPXML
			rm -f /root/setup.sh
			crontab -r
            shutdown -h now
			exit 1
        fi
    fi
	#hostname
	
	
    # create ssh key file
    if [[ $SSH_PUB ]]
    then	
        echo $SSH_PUB > /root/.ssh/authorized_keys
        sed -i "s/#PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
        #restart ssh service
        /etc/init.d/ssh restart
​
    else
        echo root:$PASSWORD | /usr/sbin/chpasswd
    fi
	
	sleep 1
    # deleting XML file
    rm -f $TMPXML
    rm -f /root/setup.sh
	rm -f /tmp/logsetup.txt
    crontab -r
fi
#
​
​
if  [ "$DEPLOYMENT" = "update" ]; then
​
​
​
    # update
    DEBIAN_FRONTEND=noninteractive apt upgrade -y --force-yes -fuy -o Dpkg::Optitons::='--force-confold' 
	
	
	
fi
 #       address IPv4/SUBNET4
  #      gateway GATE4
#
#command | tee /path/to/logfile
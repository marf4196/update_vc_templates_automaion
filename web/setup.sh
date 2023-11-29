#!/bin/bash -xv
#DEB12 OS level

# DEB 12 Startup
#crontab -e
#@reboot /usr/bin/sleep 5; /root/setup.sh 2>&1 | tee /tmp/logsetup.txt
#chmod +x setup.sh

# creating XML file from VMapp
vmtoolsd --cmd "info-get guestinfo.ovfenv" > /tmp/ovf_env.xml
TMPXML='/tmp/ovf_env.xml'

# getting variables from XML 
DEPLOYMENT=`cat $TMPXML| grep -e deployment |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`


if  [ "$DEPLOYMENT" = "deploy" ]; then
    #IPV4
    MAINIP=`cat $TMPXML| grep -e mainip |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
    IP4GATE=`cat $TMPXML| grep -e ip4gate |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
    MAINSUBNET=`cat $TMPXML| grep -e mainsubnet |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
    MAINGATE4=`cat $TMPXML| grep -e maingateway |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`

    # IPV6
    IPV6=`cat $TMPXML| grep -e v6ip0 |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
    GATE6=`cat $TMPXML| grep -e v6gateway0 |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
    SUBNET6=`cat $TMPXML| grep -e v6netmask0 |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`

    # hostname
    HOSTNAME=`cat $TMPXML| grep -e hostname |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
    DISKRESIZE=`cat $TMPXML| grep -e diskresize |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`

    # ssh public key
    SSH_PUB=`cat $TMPXML| grep -e ssh_pub | cut -c 47- | rev | cut -c 4- | rev`
    PASSWORD=`cat $TMPXML| grep -e password |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`

    # Extra IP 1
    EXT_IP1=`cat $TMPXML| grep -e ext1 |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`

    # Extra IP 2
    EXT_IP2=`cat $TMPXML| grep -e ext2 |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`

    # network file
    NETWORKFILE="/etc/network/interfaces"
    
    # create network file    
    echo "# This file describes the network interfaces available on your system" > $NETWORKFILE
    echo "# and how to activate them. For more information, see interfaces(5)." >> $NETWORKFILE
    echo "" >> $NETWORKFILE
    echo "source /etc/network/interfaces.d/*" >> $NETWORKFILE
    echo "" >> $NETWORKFILE
    echo "# The loopback network interface" >> $NETWORKFILE
    echo "auto lo" >> $NETWORKFILE
    echo "iface lo inet loopback" >> $NETWORKFILE
    echo "" >> $NETWORKFILE
    echo "# The primary network interface" >> $NETWORKFILE
    echo "allow-hotplug ens192" >> $NETWORKFILE

    # configure ip
    echo "iface ens192 inet static" >> $NETWORKFILE
    echo "        address $MAINIP/$MAINSUBNET" >> $NETWORKFILE
    echo "        gateway $IP4GATE" >> $NETWORKFILE
    echo "        # dns-* options are implemented by the resolvconf package, if installed" >> $NETWORKFILE
    echo "        dns-nameservers 8.8.8.8" >> $NETWORKFILE
    echo "        dns-search deb12.domain.com" >> $NETWORKFILE

    sleep 1

    # adding extra ip 1 and 2
    if [ $EXT_IP1 ]; then
        echo 'auto ens192' >> $NETWORKFILE
        echo 'iface ens192 inet static' >> $NETWORKFILE
        echo "        address $EXT_IP1" >> $NETWORKFILE
    fi
	
    if [ $EXT_IP1 ] && [ $EXT_IP2 ]; then
        echo 'auto ens192' >> $NETWORKFILE
        echo 'iface ens192 inet static' >> $NETWORKFILE
        echo "        address $EXT_IP2" >> $NETWORKFILE
    fi

    if [ $IPV6 ]; then
        echo "iface ens192 inet6 static" >> $NETWORKFILE
        echo "        address $IPV6/$SUBNET6" >> $NETWORKFILE
        echo "        gateway $GATE6" >> $NETWORKFILE
    fi

	/usr/sbin/ifdown ens192
    sleep 1
    /usr/sbin/ifup ens192
    sleep 1
	#resize disk
    if [ "$DISKRESIZE" = "YES" ]; then
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
	if [[ $res == *"0% packet loss"* ]] || [[ $res == *"25% packet loss"* ]]; then
	echo "VM IS ONLINE"
	else
		/etc/init.d/networking restart	
		TRYAGAIN="YES"
	fi

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
			# rm -f $TMPXML
			# rm -f /root/setup.sh
			# crontab -r
            # shutdown -h now
			exit 1
        fi
    fi

	#hostname
	echo $HOSTNAME > /etc/hostname
    echo '127.0.0.1    localhost' > /etc/hosts
    echo "$MAINIP    $HOSTNAME" >> /etc/hosts

    # create ssh key file
    if [[ $SSH_PUB ]]
    then	
        echo $SSH_PUB > /root/.ssh/authorized_keys
        sed -i "s/#PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
        #restart ssh service
        /etc/init.d/ssh restart

    else
        echo root:$PASSWORD | /usr/sbin/chpasswd
    fi
	
	sleep 1
    # deleting XML file
    # rm -f $TMPXML
    # rm -f /root/setup.sh
	# rm -f /tmp/logsetup.txt
    crontab -r
fi

# UPDATE PHASE
if  [ "$DEPLOYMENT" = "update" ]; then

    MAINIP=`cat $TMPXML| grep -e mainip |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
    IP4GATE=`cat $TMPXML| grep -e ip4gate |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
    MAINSUBNET=`cat $TMPXML| grep -e mainsubnet |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
    MAINGATE4=`cat $TMPXML| grep -e maingateway |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`

    # api key
    API_KEY=`cat $TMPXML| grep -e api_key |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`

    # url
    URL=`cat $TMPXML| grep -e url |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`

    NETWORKFILE="/etc/network/interfaces"
    
    # create network file    
    echo "# This file describes the network interfaces available on your system" > $NETWORKFILE
    echo "# and how to activate them. For more information, see interfaces(5)." >> $NETWORKFILE
    echo "" >> $NETWORKFILE
    echo "source /etc/network/interfaces.d/*" >> $NETWORKFILE
    echo "" >> $NETWORKFILE
    echo "# The loopback network interface" >> $NETWORKFILE
    echo "auto lo" >> $NETWORKFILE
    echo "iface lo inet loopback" >> $NETWORKFILE
    echo "" >> $NETWORKFILE
    echo "# The primary network interface" >> $NETWORKFILE
    echo "allow-hotplug ens192" >> $NETWORKFILE

    # configure ip
    echo "iface ens192 inet static" >> $NETWORKFILE
    echo "        address $MAINIP/$MAINSUBNET" >> $NETWORKFILE
    echo "        gateway $IP4GATE" >> $NETWORKFILE
    echo "        # dns-* options are implemented by the resolvconf package, if installed" >> $NETWORKFILE
    echo "        dns-nameservers 8.8.8.8" >> $NETWORKFILE
    echo "        dns-search deb12.domain.com" >> $NETWORKFILE

    /usr/sbin/ifdown ens192
    sleep 1
    /usr/sbin/ifup ens192
    sleep 1

    ping -c 2 $MAINGATE4

    res=$(ping -c 4 8.8.8.8)

    if [[ $res == *"0% packet loss"* ]] || [[ $res == *"25% packet loss"* ]]; then
	echo "VM IS ONLINE"
	else
		/etc/init.d/networking restart	
		TRYAGAIN="YES"
	fi

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

    curl -X POST -H 'Content-Type: application/json' -d "{\"api_key\": \"$API_KEY\", \"ip\": \"91.206.178.26\", \"status\": \"UPDATING\"}" $URL
    if apt update -y && DEBIAN_FRONTEND=noninteractive apt upgrade -y --force-yes -fuy -o Dpkg::Optitons::='--force-confold' && apt update -y; then
        curl -X POST -H 'Content-Type: application/json' -d "{\"api_key\": \"$API_KEY\", \"ip\": \"91.206.178.26\", \"status\": \"UPDATED\"}" $URL
    else 
        curl -X POST -H 'Content-Type: application/json' -d "{\"api_key\": \"$API_KEY\", \"ip\": \"91.206.178.26\", \"status\": \"ERROR\"}" $URL
    fi

    echo "# This file describes the network interfaces available on your system" > $NETWORKFILE
    echo "# and how to activate them. For more information, see interfaces(5)." >> $NETWORKFILE
    echo "" >> $NETWORKFILE
    echo "source /etc/network/interfaces.d/*" >> $NETWORKFILE
    echo "" >> $NETWORKFILE
    echo "# The loopback network interface" >> $NETWORKFILE
    echo "auto lo" >> $NETWORKFILE
    echo "iface lo inet loopback" >> $NETWORKFILE
    echo "" >> $NETWORKFILE
    echo "# The primary network interface" >> $NETWORKFILE
    echo "allow-hotplug ens192" >> $NETWORKFILE

    # configure ip
    echo "iface ens192 inet static" >> $NETWORKFILE
    echo "        address IP/SUBNET" >> $NETWORKFILE
    echo "        gateway GATE" >> $NETWORKFILE
    echo "        # dns-* options are implemented by the resolvconf package, if installed" >> $NETWORKFILE
    echo "        dns-nameservers 8.8.8.8" >> $NETWORKFILE
    echo "        dns-search deb12.domain.com" >> $NETWORKFILE
fi

reboot

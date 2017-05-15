# /bin/bash

# Sets the Keyboard layout
echo "Please enter keyboard layout chars. (e.g. de / gb)"
read keyboard_layout
keyboard_layout=$(echo "$a" | tr '[:upper:]' '[:lower:]')
keyboard_layout_cfg=/etc/default/keyboard
setxkbmap $keyboard_layout
sudo sed -i "s/^XKBLAYOUT=*.*/XKBLAYOUT=\"$keyboard_layout\" /" $keyboard_layout_cfg

# Enables SSH but avoids Root login via SSH
ssh_config=/etc/ssh/sshd_config
sudo sed -i "s/PermitRootLogin *.*/PermitRootLogin No/" $ssh_config
sudo systemctl enable ssh
sudo systemctl start ssh
echo "Enabled SSH"

# Ignore pings and broadcasts, this avoid intruders to ping for your ip
sysctl_config=/etc/sysctl.conf
ping_ignore_cmd=net.ipv4.icmp_echo_ignore_all
broadcast_ignore_cmd=net.ipv4.icmp_echo_ignore_broadcasts
if ! grep -q "^$ping_ignore_cmd" $sysctl_config
then
    echo "$ping_ignore_cmd = 1" | sudo tee -a $sysctl_config > /dev/null
fi
if ! grep -q "^$broadcast_ignore_cmd" $sysctl_config
then
    echo "$broadcast_ignore_cmd = 1" | sudo tee -a $sysctl_config > /dev/null
fi

# Creates a new user, because pi is the default user and should not be used.
# Remove the pi user after the reboot, so no one except you knows the users and passwords on your Raspberry Pi.
autologin_config=/etc/lightdm/lightdm.conf
is_new_user=1
while [ $is_new_user -eq 1 ]
do
    echo "Please enter a new username"
    read username

    if [ $(id -u $username > /dev/null 2>&1; echo $?) -eq 0 ];
    then
        echo "User already exists, do you want to enter a new username? (Y/N)"
	    read reenter

	    if [[ $reenter =~ ^[Nn]$ ]];
            then
                is_new_user=0
            fi
    else
        sudo adduser $username
        sudo adduser $username sudo
	sudo cp -R /home/pi/* /home/$username
        sudo chown -R $username:$username /home/$username


	sudo sed -i "s/^ExecStart=-\/sbin\/agetty --autologin *.*/ExecStart=-\/sbin\/agetty --autologin $username --noclear %I \$TERM/" /etc/systemd/system/autologin@.service
        sudo sed -i "s/^autologin-user=.*/autologin-user=/" $autologin_config

	is_new_user=0
    fi
done

# Disable autologin
# To switch back use 'ln -fs /etc/systemd/system/autologin@.service \ /etc/systemd/system/getty.target.wants/getty@tty1.service'
ln -fs /lib/systemd/system/getty@.service \ /etc/systemd/system/getty.target.wants/getty@tty1.service

# Just boot to the terminal, this would need less resources than a desktop environment.
# If you want switch back, use 'sudo systemctl set-default graphical.target'
echo "Do you want to boot only to the Terminal? (Y/N)"
read boot_terminal
if [[ $boot_terminal =~ ^[Yy]$ ]];
then
    sudo systemctl set-default multi-user.target
fi

# Configures wifi.
# Stores an encrypted wifi password.
echo "Do you want to configure wifi? (Y/N)"
read use_wifi
if [[ $use_wifi =~ ^[Yy]$ ]];
then
    echo "Please enter the wifi SSID"
    read ssid

    echo "Please enter the password for SSID $ssid"
    read wifi_password

    if [ -n $ssid ] && [ -n $wifi_password ];
    then
        wpa_cfg_file="/etc/wpa_supplicant/wpa_supplicant.conf"
        sudo echo "" | sudo tee -a $wpa_cfg_file > /dev/null
        sudo wpa_passphrase $ssid $wifi_password | sed '3d' | sudo tee -a $wpa_cfg_file  > /dev/null

        sudo ifdown wlan0
        sudo ifup wlan0
    fi
fi

# If there is a internet connection, install vim if it's not installed and update the Raspberry Pi afterwards.
if [ $(ping www.google.de | $?) == 0 ];
then
    if [ $(dpkg-query -W -f='${Status}' vim 2>/dev/null | grep -c "ok installed") -eq 0 ];
    then
        sudo apt-get -y install vim
    fi

    echo "Do you want to Reboot after the Update? (Y/N)"
    read reboot

    sudo apt-get update
    sudo apt-get -y dist-upgrade

    if [[ $reboot =~ ^[Yy]$ ]];
    then
	sudo reboot
    fi
else
    echo "There is no internet available."
fi

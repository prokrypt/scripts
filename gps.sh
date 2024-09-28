#!/usr/bin/env bash

dev=/dev/cuaU0

lat=0000.000000
lon=00000.000000
time=000000
fix=0
sats=0
hdop=000
pdop=000
vdop=000

echo -ne "\n\n\n\n"

trap killstream EXIT

function killstream(){
	kill $pid
}

while read -r line; do
	[[ -n $line ]] || continue
	IFS=, read type _ <<< $line
	case $type in
		\$GPRMC)
			#echo $line
			#IFS=, read type time status lat latd lon lond speed angle date _ <<< $line
			#printf "%s %.0f %s %s\n" $type $time $lat$latd $lon$lond
			;;
		\$GPGSV)
			#echo $line
			#IFS=, read type tnum num sats _ <<< $line
			#echo $type $num/$tnum $sats $checksum
			;;
		\$GPGGA)
			#echo $line
			IFS=, read type time lat latd lon lond fix sats hdop alt altu height heightu _ <<< $line
			#echo $type $time $lat$latd $lon$lond $fix $sats $hdop
			;;
		\$GPGSA)
			IFS=, read type mode fixtype sat1 sat2 sat3 sat4 sat5 sat6 sat7 sat8 sat9 sat10 sat11 sat12 pdop hdop vdop <<< $line
			IFS='*' read vdop _ <<< $vdop
			#echo $pdop $hdop $vdop
			;;
		*)
			echo unknon type $type;;
	esac
	for i in time lat lon fix sats hdop pdop vdop; do
		#[[ -n ${!i} ]] || continue
		eval oldv=\$old_$i
		[[ ! "$oldv" = "${!i}" ]] && {
			lats="${lat:0:${#lat}-9}° ${lat: -9}\"$latd";
			lons="${lon:0:${#lon}-9}° ${lon: -9}\"$lond";
			times="${time:0:2}:${time:2:2}:${time:4:2}"
			printf "\r\033[4ATime: %8s\nSats: %-2i  Fix: $fix\nLat: %17s\nLon: %17s\n(p/h/v)dop: %4.2f %4.2f %4.2f" "$times" "$sats" "$lats" "$lons" "$pdop" "$hdop" "$vdop"
		}
		eval old_$i=\$$i
	done
done < $dev&

pid=$!

read

killstream

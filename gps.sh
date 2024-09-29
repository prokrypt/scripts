#!/usr/bin/env bash

dev=/dev/cuaU0

time=000000
fix=0
sats=0
hdop=0
pdop=0
vdop=0
latd=X
lond=X
alt=00.00


trap killstream EXIT

function killstream(){
	kill $pid
}

echo -ne "GPS Info from $dev\n\n\n\n\n\n"

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
	hash="$time$lat$lon$fix$sats$hdop$pdop$vdop"
	[[ ! "$oldhash" = "$hash" ]] && {
		[[ -n $lat ]] && lats="${lat:0:${#lat}-9}° ${lat: -9}'$latd";
		[[ -n $lon ]] && lons="${lon:0:${#lon}-9}° ${lon: -9}'$lond";
		[[ -n $alt ]] && printf -v alts "%7.2f$altu" $alt
		times="${time:0:2}:${time:2:2}:${time:4:2}"
		((x++))
		printf "    \r\033[5ATime: %8s\nSats: %-2i  Fix: $fix\nLat: %17s\nLon: %17s\nAlt: %s\n[phv]dop: %5.2f %5.2f %5.2f"\
			"$times" "$sats" "$lats" "$lons" "$alts" "$pdop" "$hdop" "$vdop"
	}
	oldhash="$hash"
done < $dev&

pid=$!

read

killstream

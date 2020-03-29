#!/bin/bash

##############
# Add these rules to /etc/udev/rules.d/10-cpupower.rules
# ACTION=="change", SUBSYSTEM=="drm", ENV{HOTPLUG}=="1", RUN+="/home/torvalds/scripts/display.sh udev"
##############

X_USER=torvalds
X_UID=1000								   #User id echo $UID
HOME=/home/$X_USER						   #Home path

SUBLIME=$HOME/.config/sublime-text-3       #Sublime-text config path to update dpi. Remove if not installed

POLYBAR=$HOME/.config/polybar/config.ini   #Polybar config file to update dpi. Remove if not installed
								           #To make it work dpi-x and dpi-y must already exist for each bar on config file

LOG=$HOME/scripts/display.log 

MAINMONITOR="DP1"  						   #Primary display when more then one attached
ALTMONITOR="eDP1"  						   #Secondary display when more then one attached
ALTPOS="b" 		   						   #Position on second display t = top, b = bottom, l = left, r = right

MAINDPI=108		   						   #DPI of primary display
ALTDPI=168		 						   #DPI of second display	
DEFDPI=168		   						   #DPI when no external monitor attached

MAINCURSOR=24	   						   #Cursor size when more displays attached
DEFCURSOR=56	   						   #Cursor size no external monitor attached

UDEVSLEEP=3		   						   #Seconds to sleep when udev find dysplay changes 

DEBUG=1			   						   #Enable debug 0/1

####################################
# DO NOT TOUCH BELOW
####################################
if [ $# -gt 0 ]; then
	sleep $UDEVSLEEP
fi

export DISPLAY=:0
export XAUTHORITY=$HOME/.Xauthority
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$UID/bus

SUBLIMECONFIG=$SUBLIME/Packages/User/Preferences.sublime-settings
BASEDPI=96
LOWX=10000
MAXX=0
IDX=0
IDXOFF=0
declare -A arrName
declare -A arrRis
declare -A arrOff

if [ ! -d "$HOME" ]; then
	echo "HOME folder $HOME does not exist, check your config"
	[ $DEBUG -eq 1 ] && echo "" > $LOG
	exit
fi

if [ ! -z "$SUBLIME" ] && [ ! -d "$SUBLIME" ]; then
	echo "SUBLIME folder $SUBLIME does not exist, check your config"
	[ $DEBUG -eq 1 ] && echo "" > $LOG
	exit
fi

if [ ! -z "$POLYBAR" ] && [ ! -f "$POLYBAR" ]; then
	echo "POLYBAR folder $POLYBAR does not exist, check your config"
	[ $DEBUG -eq 1 ] && echo "" > $LOG
	exit
fi

for i in /sys/class/drm/card0-*/status; do
	CONT="$(<$i)"
	x=$(echo "$i" | cut -d'-' -f2)
	x+=$(echo "$i" | cut -d'-' -f3 | cut -d'/' -f1)
	[ $DEBUG -eq 1 ] && echo "Display $x $CONT" > $LOG
	if [ $CONT == "connected" ]; then
 		RIS=$(xrandr | awk '/\y'"$x"'\y/{print; nr[NR+1]; next}; NR in nr' | sed -n '2,${p;n;}' | awk '{print $1}')
 		[ $DEBUG -eq 1 ] && echo "Display $x max resolution  $RIS" >> $LOG
 		arrName[$IDX]=$x
 		arrRis[$IDX]=$RIS
 		X=$(echo $RIS  | cut -d'x' -f1 )
 		Y=$(echo $RIS  | cut -d'x' -f2 )
 		if [ "$X" -lt "$LOWX" ]; then
 			LOWRIS=$RIS
 			LOWX=$X
 			LOWY=$Y
 		fi
 		if [ "$X" -gt "$MAXX" ]; then
 			MAXRIS=$RIS
 			MAXX=$X
 			MAXY=$Y
 		fi
 		IDX=$((IDX + 1))
 	elif [ $CONT == "disconnected" ]; then
 		[ $DEBUG -eq 1 ] && echo "Display $x not connected" >> $LOG
 		arrOff[$IDXOFF]=$x
 		IDXOFF=$((IDXOFF + 1))
 	fi
done

[ $DEBUG -eq 1 ] && echo $'\n'"Max resolution $MAXRIS" >> $LOG
[ $DEBUG -eq 1 ] && echo "Lowest resolution $LOWRIS" >> $LOG
[ $DEBUG -eq 1 ] && echo "Best resolution $LOWRIS"$'\n' >> $LOG

case "$ALTPOS" in
	b) POSMAIN="--pos 0x0"
	   POSALT="--pos 0x$LOWY"
	   ;;
	r) POSMAIN="--pos 0x0"
	   POSALT="--pos $LOWXx0"
		;;
	l) POSMAIN="--pos $LOWXx0"
	   POSALT="--pos 0x0"
		;;
	t) POSMAIN=" --pos 0x$LOWY"
	   POSALT="--pos 0x0"
	   ;;
	*) POSMAIN=""
	   POSALT=""
	   ;;
esac

IDX=0

for i in ${arrName[@]}; 
do
	[ $DEBUG -eq 1 ] && echo "Set display $i to $LOWRIS" >> $LOG
	if [ "$i" == "$MAINMONITOR" ] && [ ${#arrName[@]} -gt 1 ]; then
		t=" --output $i --primary --mode $LOWRIS $xrdb $POSMAIN --rotate normal --dpi $MAINDPI$t"
		DPI=$MAINDPI
		CURSOR=$MAINCURSOR
	elif [ "$i" == "$ALTMONITOR" ] && [ ${#arrName[@]} -gt 1 ]; then
		t=" --output $i --mode $LOWRIS $POSALT --rotate normal$t"
	else
		t=" --output $i --mode $LOWRIS --pos 0x0 --rotate normal --dpi $DEFDPI$t"
		DPI=$DEFDPI
		CURSOR=$DEFCURSOR
	fi
	
	IDX=$((IDX + 1))
done

for i in ${arrOff[@]}; 
do
	[ $DEBUG -eq 1 ] && echo "Set display $i to OFF" >> $LOG
	t=" --output $i --off$t"
done

[ $DEBUG -eq 1 ] && echo $'\nCalculating scale...' >> $LOG

SCALE=$(bc <<< "scale=2; (($DPI-$BASEDPI)/$BASEDPI)>0 && (($DPI-$BASEDPI)/$BASEDPI)<1")

if [ "$SCALE" == "1" ]
then
	SCALE=$(bc <<< "scale=2; 1+($DPI-$BASEDPI)/$BASEDPI")
else
	SCALE=$(bc <<< "scale=2; (($DPI-$BASEDPI)/$BASEDPI)+1")
fi
[ $DEBUG -eq 1 ] && echo "$SCALE" >> $LOG

[ $DEBUG -eq 1 ] && echo $'\nCommand output: \n'"$t"$'\n' >> $LOG

if [ -d "$SUBLIME" ]; then
	if [ -f "$SUBLIMECONFIG" ]; then
		[ $DEBUG -eq 1 ] && echo $'Sublime preferences file exists' >> $LOG
		if grep -q "ui_scale" "$SUBLIMECONFIG"
		then
			[ $DEBUG -eq 1 ] && echo "Sublime ui_scale params exists, replacing..."  >> $LOG
			sed -i "s#\"ui_scale\":.*#\"ui_scale\": $SCALE,#" $SUBLIMECONFIG
		else
			[ $DEBUG -eq 1 ] && echo "Sublime ui_scale does not exists, adding..." >> $LOG
			sed -i "1 a\"ui_scale\": $SCALE," $SUBLIMECONFIG
		fi
	else
		[ $DEBUG -eq 1 ] && echo "Sublime preferences file does not exists, creating..." >> $LOG
		printf "{\n\t\"ui_scale\": $SCALE,\n}" > $SUBLIMECONFIG
	fi
else
	[ $DEBUG -eq 1 ] && echo "Sublime not found" >> $LOG
fi

if [ -f "$POLYBAR" ]; then
	[ $DEBUG -eq 1 ] && echo $'\nSetting dpi-x '"($DPI) in $POLYBAR..." >> $LOG
	sed -i "/dpi-x =/c\dpi-x = $DPI" $POLYBAR
	[ $DEBUG -eq 1 ] && echo "Setting dpi-y ($DPI) in $POLYBAR..."$'\n' >> $LOG
	sed -i "/dpi-y =/c\dpi-y = $DPI" $POLYBAR
else
	[ $DEBUG -eq 1 ] && echo $'\nPolybar not found\n' >> $LOG
fi

[ $DEBUG -eq 1 ] && echo "Setting DPI ($DPI) in $HOME/.Xresources..."$'\n' >> $LOG
sed -i "/Xft.dpi:/c\Xft.dpi: $DPI" $HOME/.Xresources

[ $DEBUG -eq 1 ] && echo "Setting mouse cursor size ($CURSOR) in  $HOME/.Xresources..." >> $LOG
sed -i "/Xcursor.size:/c\Xcursor.size: $CURSOR" $HOME/.Xresources

[ $DEBUG -eq 1 ] && echo $'\nReloading Xresources...' >> $LOG
xrdb $HOME/.Xresources

[ $DEBUG -eq 1 ] && echo $'\nSettings xrandr settings...' >> $LOG
xrandr $t 

if [ $# -gt 0 ]; then
	[ $DEBUG -eq 1 ] && echo $'\nRestarting i3...' >> $LOG
	i3-msg restart &
fi

#!/bin/bash
#################
# Add these rules to /etc/udev/rules.d/10-cpupower.rules
# ACTION=="change", SUBSYSTEM=="power_supply", ENV{POWER_SUPPLY_ONLINE}=="1", RUN+="/home/torvalds/scripts/cpupower.sh up"
# ACTION=="change", SUBSYSTEM=="power_supply", ENV{POWER_SUPPLY_ONLINE}=="0" RUN+="/home/torvalds/scripts/cpupower.sh down"
#################


export DISPLAY=:0
export XAUTHORITY=$HOME/.Xauthority
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$UID/bus

if [ $1 == 'down' ]; then
	notify-send AC power disconnected setting cpu in powersave 
	cpupower frequency-set -g powersave
else
	notify-send AC power connected setting cpu in performance 
	cpupower frequency-set -g performance
fi
#!/usr/bin/env bash

choice=$(printf " Poweroff\n Reboot\n Lock\n Logout" | rofi -dmenu -p "Power")

case "$choice" in
    " Poweroff") systemctl poweroff ;;
    " Reboot") systemctl reboot ;;
    " Lock") hyprlock ;;
    " Logout") hyprctl dispatch exit ;;
esac

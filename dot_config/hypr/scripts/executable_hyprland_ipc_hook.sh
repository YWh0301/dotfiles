#!/bin/sh

handle() {
  case $1 in
    openwindow*) 
        window_address=$(echo "$1" | sed 's/openwindow>>//' | cut -d',' -f1)
        if [ -n "$window_address" ]; then
            xwayland=$(echo -n "j/clients" | socat - UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket.sock | jq -r ".[] | select(.address == \"0x$window_address\") | .xwayland")
            if [ "$xwayland" = "true" ]; then
                xkbcomp -w 0 ~/.config/xkb/custom.xkb $DISPLAY >/dev/null 2>&1
            fi
        fi ;;
  esac
}

socat -U - UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock | while read -r line; do handle "$line"; done

#!/usr/bin/bash

if [ "$1" = "+" ]; then
    if [[ $(( ( $(hyprctl -j activeworkspace | jq -r .id) +1 ) % 10 )) -ne 1 ]]; then
        hyprctl dispatch workspace r+1
    fi
elif [ "$1" = "-" ]; then
    if [[ $((($(hyprctl -j activeworkspace | jq -r .id) -1) % 10)) -ne 0 ]]; then
        hyprctl dispatch workspace r-1
    fi
fi

#!/usr/bin/bash

current_workspace=$( hyprctl -j activeworkspace | jq -r .id )
if [ "$1" = "+" ]; then
    new_workspace=$(($current_workspace +1))
    if [[ $(($new_workspace % 10)) -eq 1 ]]; then
        new_workspace=$(( $new_workspace - 1 ))
    fi
elif [ "$1" = "-" ]; then
    new_workspace=$(($current_workspace -1))
    if [[ $(($new_workspace % 10)) -eq 0 ]]; then
        new_workspace=$(($new_workspace + 1))
    fi
fi

# 获取当前工作区的所有窗口address
hyprctl dispatch movetoworkspacesilent $new_workspace,address:$(hyprctl -j activewindow | jq -r ".address" ) 

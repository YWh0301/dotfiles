#!/usr/bin/bash

if [ "$1" = "+" ]; then
    tmp_base=$(cat /tmp/hyprland_workspace_base)
    [[ "$tmp_base" -eq 90 ]] && echo 90 > /tmp/hyprland_workspace_base || echo $(($tmp_base + 10)) > /tmp/hyprland_workspace_base 
    pkill -SIGRTMIN+10 waybar
elif [ "$1" = "-" ]; then 
    tmp_base=$(cat /tmp/hyprland_workspace_base)
    [[ "$tmp_base" -eq 0 ]] && echo 0 > /tmp/hyprland_workspace_base || echo $(($tmp_base - 10)) > /tmp/hyprland_workspace_base 
    pkill -SIGRTMIN+10 waybar
else
    echo $((($1 - 1) * 10)) > /tmp/hyprland_workspace_base
    pkill -SIGRTMIN+10 waybar
fi
hyprctl keyword animation workspaces,1,3,default,slidevert &&
hyprctl dispatch workspace $(( $(cat /tmp/hyprland_workspace_base 2>/dev/null || echo 0) + $(($(hyprctl -j activeworkspace | jq -r .id) - 1)) % 10 + 1)) &&
hyprctl keyword animation workspaces,1,3,default,slide


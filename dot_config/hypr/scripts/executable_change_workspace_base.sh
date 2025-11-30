#!/usr/bin/bash

old_base=$(cat /tmp/hyprland_workspace_base)
if [ "$1" = "+" ]; then
    if [[ "$old_base" -eq 90 ]]; then
        exit
    else
        new_base=$(($old_base + 10))
    fi
elif [ "$1" = "-" ]; then 
    if [[ "$old_base" -eq 0 ]]; then
        exit
    else
        new_base=$(($old_base - 10))
    fi
else
    new_base=$((($1 - 1) * 10))
fi

echo $new_base > /tmp/hyprland_workspace_base 

hyprctl keyword animation workspaces,1,3,default,slidevert &&
# 获取当前base的所有workspace id 并重命名这样waybar可以不显示
hyprctl -j workspaces | jq -r ".[] | \"\(.id) \(.name)\"" | while read id name; do
if [[ "$(($old_base / 10 ))" = "$((($id - 1 ) / 10 ))" ]]; then
        #hyprctl dispatch renameworkspace $id "n${name##n}"
        hyprctl dispatch renameworkspace $id "$(($old_base / 10 + 1))${name##[0-9]}"
    elif [[ "$(($new_base / 10 ))" = "$((($id - 1 ) / 10 ))" ]]; then
        #hyprctl dispatch renameworkspace $id "${name##n}"
        hyprctl dispatch renameworkspace $id "${name##[0-9]}"
    fi
done
hyprctl dispatch workspace $(( $(cat /tmp/hyprland_workspace_base 2>/dev/null || echo 0) + $(($(hyprctl -j activeworkspace | jq -r .id) - 1)) % 10 + 1)) &&
pkill -SIGRTMIN+10 waybar
hyprctl keyword animation workspaces,1,3,default,slide


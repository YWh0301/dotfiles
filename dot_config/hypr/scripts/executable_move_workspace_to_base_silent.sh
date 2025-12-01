#!/usr/bin/bash

read current_workspace windows_count <<< $(hyprctl -j activeworkspace | jq -r '"\(.id) \(.windows)"')
if [ "$windows_count" -gt 0 ]; then
    tmp_base=$(cat /tmp/hyprland_workspace_base 2>/dev/null || echo 0)
    if [ "$1" = "+" ]; then
        new_workspace=$(( $([[ "$tmp_base" -eq 90 ]] && echo 90 || echo $(($tmp_base + 10)) ) + $(($current_workspace - 1)) % 10 + 1))
    elif [ "$1" = "-" ]; then 
        new_workspace=$(( $([[ "$tmp_base" -eq 0 ]] && echo 0|| echo $(($tmp_base - 10))) + $(($current_workspace - 1)) % 10 + 1))
    else
        new_workspace=$(( $((($1 - 1) * 10)) + $(($current_workspace - 1)) % 10 + 1))
    fi

    # 获取当前工作区的所有窗口address
    hyprctl -j clients | jq -r ".[] | select(.workspace.id == "$current_workspace") | .address" | while read address; do
        hyprctl dispatch movetoworkspacesilent $new_workspace,address:$address 
    done
    name=$(hyprctl -j workspaces | jq -r ".[] | select(.id == $new_workspace) | .name")
    hyprctl dispatch renameworkspace $new_workspace "n${name##n}"
fi

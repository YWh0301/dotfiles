#!/bin/bash

# 获取当前工作区
current_workspace=$(hyprctl monitors | awk '/active workspace/ {print $3}')

# 获取当前工作区的所有窗口address
window_addresses=$(hyprctl clients | awk -v ws="$current_workspace" '
    /Window / {address=$2} 
    /workspace:/ && $2 == ws {print address}')

# 关闭当前工作区的所有窗口
for window_address in $window_addresses; do
    hyprctl dispatch closewindow address:0x$window_address
done

# reset submap
hyprctl dispatch submap reset
hyprctl dispatch workspace 1

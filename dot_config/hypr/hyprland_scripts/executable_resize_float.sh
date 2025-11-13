#!/bin/bash

# 获取 hyprctl clients 的输出
output=$(hyprctl clients)

# 使用 awk 处理输出，查找 focusHistoryID 为 0 的 client
# 并找到 floating 条目，判断是否为 0
client_info=$(echo "$output" | awk '
/floating/ { floating = $2 }
/focusHistoryID/ { 
    if ($2 == 0) { 
        print floating; 
        exit 
    } 
}
')

# 判断是否找到了 focusHistoryID 0 的 client 并返回对应的 floating 值
if [ -n "$client_info" ] && [ "$client_info" == "1" ]; then
    # 如果 floating 为 1，则执行 resizeactive
    hyprctl dispatch centerwindow 1
    hyprctl dispatch resizeactive exact 40% 40%
    # echo "Resized the active window to 40% 40%."
# else
    # echo "No resize action taken."
fi

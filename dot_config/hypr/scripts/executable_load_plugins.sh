#!/bin/bash

#bind = $mainMod, D, shadewindow, activewindow, invert

check_lib_and_execute() {
    local lib_name="$1"
    local expected_version="$2"
    local command_to_execute="$3"
    local lib_path="/usr/lib/lib${lib_name}.so"
    if [ ! -e "$lib_path" ]; then
        return
    fi
    
    if [ -L "$lib_path" ]; then
        local target_file=$(readlink -f "$lib_path")
        local version=$(basename "$target_file" | sed 's/.*\.so\.//')
        
        if [ -z "$version" ]; then
            hyprctl notify 3 100000 "rgb(b8bb26)" "插件${lib_name}无法读取版本号"
            return
        fi

        # 版本匹配检查（支持通配符）
        if [[ "$version" == $expected_version ]] || 
           [[ "$expected_version" == "*" ]] || 
           [[ "$version" =~ ^${expected_version//\*/.*} ]]; then
            hyprctl plugin load $lib_path
            local exit_code=$?
            if [[ $exit_code -ne 0 ]]; then
                hyprctl notify -1 100000 "rgb(b8bb26)" "插件${lib_name}加载失败"
                return
            fi
            $command_to_execute
            local exit_code=$?
            if [[ $exit_code -ne 0 ]]; then
                hyprctl notify -1 100000 "rgb(b8bb26)" "插件${lib_name}后续命令执行失败"
                return
            fi
            return
        else
            hyprctl notify -1 100000 "rgb(b8bb26)" "插件${lib_name}版本${version}不匹配${expected_version}"
            return
        fi
    fi
}

main() {
    for lib in "${!lib_commands[@]}"; do
        IFS=':' read -r expected_version command_to_run <<< "${lib_commands[$lib]}"
        echo ""
        check_lib_and_execute "$lib" "$expected_version" "$command_to_run"
        done
}

hyprland_version=$(hyprctl -j version | jq -r '.version')
declare -A lib_commands=(
    # 格式: ["库文件名(前面不带lib,后面不带.so)"]="期望版本:要执行的命令"
    ["hyprdarkwindow"]="${hyprland_version}:hyprctl keyword bind SUPER,D,exec,hyprctl dispatch shadewindow activewindow invert"
)

main

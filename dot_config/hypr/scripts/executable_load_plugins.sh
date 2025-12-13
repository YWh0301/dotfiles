#!/bin/bash

check_lib_and_execute() {
    local lib="$1"
    local expected_version="$2"
    local command_to_execute="$3"
    local lib_path="/usr/lib/lib${lib}.so"
    lib_commands[$lib]=":"
    if [ ! -e "$lib_path" ]; then
        return
    fi
    
    if [ -L "$lib_path" ]; then
        local target_file=$(readlink -f "$lib_path")
        local version=$(basename "$target_file" | sed 's/.*\.so\.//')
        
        if [ -z "$version" ]; then
            hyprctl notify 3 100000 "rgb(b8bb26)" "插件${lib}无法读取版本号"
            return
        fi
        # 版本匹配检查（支持通配符）
        if [[ "$version" == $expected_version ]] || 
           [[ "$expected_version" == "all" ]] || 
           [[ "$version" =~ ^${expected_version//\*/.*} ]]; then
            hyprctl plugin load $lib_path
            local exit_code=$?
            if [[ $exit_code -ne 0 ]]; then
                hyprctl notify -1 100000 "rgb(b8bb26)" "插件${lib}加载失败"
                return
            fi
            lib_commands[$lib]="$command_to_execute"
            return
        else
            hyprctl notify -1 100000 "rgb(b8bb26)" "插件${lib}版本${version}不匹配${expected_version}"
            return
        fi
    fi
}

main() {
    for lib in "${!lib_commands[@]}"; do
        IFS=':' read -r expected_version command_to_run <<< "${lib_commands[$lib]}"
        check_lib_and_execute "$lib" "$expected_version" "$command_to_run"
        done
    for lib in "${!lib_commands[@]}"; do
        ${lib_commands[$lib]}
        local exit_code=$?
        if [[ $exit_code -ne 0 ]]; then
            hyprctl notify -1 100000 "rgb(b8bb26)" "插件${lib}后续命令执行失败"
        fi
        done
}

hyprland_version=$(hyprctl -j version | jq -r '.version')
declare -A lib_commands=(
    # 格式: ["库文件名(前面不带lib,后面不带.so)"]="期望版本:要执行的命令"
    ["hyprdynamiccursors"]="all:echo hello"
    #["hyprdarkwindow"]="${hyprland_version}:hyprctl keyword bind SUPER,D,shadewindow, activewindow invert"
)

main

-- WirePlumber Pro Audio dedicated link script
--
-- This script implements fixed channel mapping of proaudio_sink to hardware devices
-- Supports minimal audio processing and auto-connect

local cutils = require ("common-utils")
local putils = require ("proaudio_utils")
local lutils = require ("linking-utils")

-- 初始化日志
local log = Log.open_topic ("s_proaudio")

-- Global state
local state = {
    channel_mapping = {},
    last_scan_time = 0,
    scan_interval = 3000  -- Scan interval (milliseconds)
}

-- 默认通道映射配置
local default_channel_mapping = {
    AUX0 = {
        device_pattern = "alsa_output.*.analog-stereo",
        description = "Main analog output",
        required = true
    },
    AUX1 = {
        device_pattern = "alsa_output.usb-*", 
        description = "USB audio device",
        required = false
    },
    AUX2 = {
        device_pattern = "bluez_output.*",
        description = "Bluetooth audio device",
        required = false
    },
    AUX3 = {
        device_pattern = "alsa_output.*.hdmi-*",
        description = "HDMI audio output",
        required = false
    }
}

-- 加载通道映射配置
local function load_channel_mapping()
    -- 这里可以从设置中加载，暂时使用默认配置
    state.channel_mapping = default_channel_mapping
    log:info("使用默认通道映射配置")
end

-- Establish proaudio links
local function establish_proaudio_links(om)
    if not Settings.get_boolean("proaudio.auto_connect") then
        return
    end
    
    log:info("Establishing proaudio links...")
    
    -- 获取所有 proaudio_sink 的 monitor
    local monitors = putils.get_proaudio_sink_monitors(om)
    if not next(monitors) then
        log:warning("proaudio_sink monitor not found")
        return
    end
    
    local connected_count = 0
    
    -- 为每个 monitor 建立链接
    for channel, monitor in pairs(monitors) do
        -- 检查是否已有链接
        local existing_link = putils.find_existing_link(monitor, om)
        if existing_link then
            log:debug("通道 " .. channel .. " 已有链接，跳过")
            connected_count = connected_count + 1
            goto continue
        end
        
        -- 根据通道映射查找设备
        local mapping = state.channel_mapping[channel] or state.channel_mapping["AUX0"]
        if mapping then
            local device = putils.find_device_by_pattern(om, mapping.device_pattern)
            if device then
                local link = putils.create_proaudio_link(monitor, device, om)
                if link then
                    connected_count = connected_count + 1
                    log:info("通道 " .. channel .. " 已连接到: " .. 
                            (device.properties["node.name"] or "unknown"))
                else
                    log:warning("通道 " .. channel .. " 链接创建失败")
                end
            else
                if mapping.required then
                    log:warning("Required mapping device not found: " .. mapping.device_pattern)
                else
                    log:debug("Optional mapping device not found: " .. mapping.device_pattern)
                end
            end
        else
            log:warning("Channel " .. channel .. " has no mapping configuration")
        end
        
        ::continue::
    end
    
    log:info("proaudio links established, connected " .. connected_count .. " channels")
end

-- 扫描并更新链接
local function scan_and_update()
    local om = cutils.get_object_manager("session-item")
    if not om then
        return
    end
    
    local current_time = Core.clock()
    if current_time - state.last_scan_time < state.scan_interval then
        return
    end
    
    state.last_scan_time = current_time
    establish_proaudio_links(om)
end

-- Pro Audio 链接选择钩子
-- 这个钩子在标准链接钩子之前执行，专门处理 proaudio_sink 的链接
SimpleEventHook {
    name = "linking/find_proaudio_target",
    after = { "linking/find-defined-target",
              "linking/find-filter-target",
              "linking/find-media-role-target",
              "linking/find-media-role-sink-target" },
    before = "linking/find-default-target",
    interests = {
        EventInterest {
            Constraint { "event.type", "=", "select-target" },
        },
    },
    execute = function(event)
        if not Settings.get_boolean("proaudio.auto_connect") then
            return
        end
        
        local source, om, si, si_props, si_flags, target =
            lutils:unwrap_select_target_event(event)
        
        -- 如果目标已选择，跳过
        if target then
            return
        end
        
        -- 检查是否是 proaudio_sink 的 monitor
        local node_name = si_props["node.name"] or ""
        if not string.find(node_name, "proaudio_sink") then
            return  -- 不是 proaudio_sink，让其他钩子处理
        end
        
        log:info("Processing proaudio_sink link: " .. node_name)
        
        -- 确定是哪个 AUX 通道（简化处理）
        local channel = putils.determine_aux_channel(si_props)
        
        -- 根据通道映射查找设备
        local mapping = state.channel_mapping[channel] or state.channel_mapping["AUX0"]
        if mapping then
            local device = putils.find_device_by_pattern(om, mapping.device_pattern)
            if device then
                log:info("通道 " .. channel .. " 映射到设备: " .. 
                        (device.properties["node.name"] or "unknown"))
                
                -- 检查是否可以链接
                if lutils.canLink(si_props, device) then
                    local passthrough_compatible, can_passthrough =
                        lutils.checkPassthroughCompatibility(si, device)
                    
                    if passthrough_compatible then
                        si_flags.can_passthrough = can_passthrough
                        event:set_data("target", device)
                        log:info("proaudio_sink link target set")
                    end
                end
            else
                if mapping.required then
                    log:warning("Required mapping device not found: " .. mapping.device_pattern)
                end
            end
        end
    end
}:register()

-- 设备变化事件处理（后台监控）
SimpleEventHook {
    name = "proaudio/device_changed",
    interests = {
        EventInterest {
            Constraint { "event.type", "=", "device-changed" },
        },
    },
    execute = function(event)
        if not Settings.get_boolean("proaudio.auto_connect") then
            return
        end
        
        local device = event:get_subject()
        if not device then
            return
        end
        
        local props = device.properties
        local device_name = props["node.name"] or ""
        
        log:debug("设备变化: " .. device_name)
        
        -- 延迟扫描，避免频繁更新
        Core.timeout_add(1000, function()
            scan_and_update()
            return false
        end)
    end
}:register()

-- 节点变化事件处理（后台监控）
SimpleEventHook {
    name = "proaudio/node_changed",
    interests = {
        EventInterest {
            Constraint { "event.type", "=", "node-changed" },
        },
    },
    execute = function(event)
        if not Settings.get_boolean("proaudio.auto_connect") then
            return
        end
        
        local node = event:get_subject()
        if not node then
            return
        end
        
        local props = node.properties
        local node_name = props["node.name"] or ""
        
        -- 检查是否是 proaudio_sink 或输出设备
        if string.find(node_name, "proaudio_sink") or
           (props["item.node.direction"] == "output" and 
            (props["media.class"] or ""):find("Sink")) then
            log:debug("相关节点变化: " .. node_name)
            
            -- 延迟扫描
            Core.timeout_add(1000, function()
                scan_and_update()
                return false
            end)
        end
    end
}:register()

-- 初始扫描
Core.timeout_add(3000, function()
    log:info("Initializing proaudio link system")
    
    -- 加载配置
    load_channel_mapping()
    
    -- 执行初始扫描
    scan_and_update()
    
    -- 启动定期扫描（比desktop sink长一些，proaudio不需要频繁扫描）
    Core.timeout_add_seconds(60, function()
        scan_and_update()
        return true
    end)
    
    return false
end)

-- 导出函数供命令行工具使用
local M = {}

-- 重新连接所有 proaudio 链接（一键刷新）
function M.reconnect_all()
    local om = cutils.get_object_manager("session-item")
    if not om then
        return false, "Cannot get object manager"
    end
    
    log:info("执行一键重联...")
    
    -- 重新加载配置
    load_channel_mapping()
    
    -- 执行重联
    local count = putils.reconnect_all_proaudio_links(om, state.channel_mapping)
    return true, "已重新连接 " .. count .. " 个链接"
end

-- Disconnect all proaudio links
function M.disconnect_all()
    local om = cutils.get_object_manager("session-item")
    if not om then
        return false, "Cannot get object manager"
    end
    
    log:info("Disconnecting all proaudio links...")
    
    local count = putils.disconnect_all_proaudio_links(om)
    return true, "已断开 " .. count .. " 个链接"
end

-- 获取当前状态
function M.get_status()
    local om = cutils.get_object_manager("session-item")
    if not om then
        return nil, "无法获取对象管理器"
    end
    
    local status = putils.get_proaudio_link_status(om)
    return status, nil
end

-- 启用/禁用自动连接
function M.enable()
    Settings.set_boolean("proaudio.auto_connect", true)
    log:info("Enabled proaudio auto-connect")
    scan_and_update()
    return true
end

function M.disable()
    Settings.set_boolean("proaudio.auto_connect", false)
    log:info("Disabled proaudio auto-connect")
    return true
end

-- 手动连接特定设备
function M.connect_device(device_pattern)
    local om = cutils.get_object_manager("session-item")
    if not om then
        return false, "Cannot get object manager"
    end
    
    local device = putils.find_device_by_pattern(om, device_pattern)
    if not device then
        return false, "Device not found: " .. device_pattern
    end
    
    -- 获取第一个 proaudio monitor
    local monitors = putils.get_proaudio_sink_monitors(om)
    local first_monitor = nil
    for _, monitor in pairs(monitors) do
        first_monitor = monitor
        break
    end
    
    if not first_monitor then
        return false, "proaudio_sink monitor not found"
    end
    
    -- 创建链接
    local link = putils.create_proaudio_link(first_monitor, device, om)
    if link then
        return true, "已连接到: " .. (device.properties["node.name"] or "unknown")
    else
        return false, "链接创建失败"
    end
end

-- 注册为全局模块
_G.proaudio = M

log:info("Pro Audio 链接脚本已加载")

return M
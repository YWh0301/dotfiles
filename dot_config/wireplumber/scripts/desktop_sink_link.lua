-- WirePlumber Desktop Sink auto-link script
--
-- This script implements automatic connection of desktop_sink monitor interface
-- to actual audio devices based on configured rules

local cutils = require ("common-utils")
local dutils = require ("desktop_sink_utils")
local lutils = require ("linking-utils")

-- 初始化日志
local log = Log.open_topic ("s_desktop_sink")

-- Global state
local state = {
    desktop_sink_monitor = nil,
    current_link = nil,
    last_scan_time = 0,
    scan_interval = 2000  -- Scan interval (milliseconds)
}

-- 设备选择配置
local device_config = {
    -- Device matching patterns (in priority order)
    patterns = {
        { pattern = "bluez_output.*", priority = 100, name = "Bluetooth device" },
        { pattern = "alsa_output.*.hdmi-*", priority = 90, name = "HDMI device" },
        { pattern = "alsa_output.*.displayport-*", priority = 85, name = "DisplayPort device" },
        { pattern = "alsa_output.*.analog-stereo", priority = 80, name = "Analog audio" },
        { pattern = "alsa_output.usb-*", priority = 75, name = "USB audio" },
        { pattern = "alsa_output.*", priority = 70, name = "Other ALSA device" },
    },
    
    -- Excluded device patterns
    exclude_patterns = {
        ".*%.monitor$",      -- All monitor devices
        "desktop_sink",      -- desktop_sink itself
        "Virtual.*",         -- Virtual devices
    },
    
    -- Minimum priority threshold
    min_priority = 50
}

-- Check if device should be excluded
local function should_exclude_device(device_name)
    for _, pattern in ipairs(device_config.exclude_patterns) do
        if string.find(device_name, pattern) then
            return true
        end
    end
    return false
end

-- Calculate device matching score
local function calculate_device_score(device_name, device_props)
    local score = 0
    
    -- 基于模式匹配的分数
    for _, rule in ipairs(device_config.patterns) do
        if string.find(device_name, rule.pattern) then
            score = score + rule.priority
            break
        end
    end
    
    -- 基于会话优先级的加分
    local session_priority = tonumber(device_props["priority.session"] or "0")
    score = score + math.floor(session_priority / 10)
    
    -- 基于连接时间的加分（新连接的设备优先）
    local plugged_time = tonumber(device_props["item.plugged.usec"] or "0")
    if plugged_time > 0 then
        -- 转换为相对分数（每10分钟加1分）
        score = score + math.floor(plugged_time / 600000000)
    end
    
    -- 活动状态加分
    if device_props["device.state"] == "active" then
        score = score + 20
    end
    
    return score
end

-- 选择最佳输出设备
local function select_best_output_device(om)
    local best_device = nil
    local best_score = -1
    local best_name = ""
    
    for device in om:iterate {
        type = "SiLinkable",
        Constraint { "item.node.direction", "=", "output" },
        Constraint { "media.class", "c", "Audio" }
    } do
        local props = device.properties
        local device_name = props["node.name"] or ""
        local media_class = props["media.class"] or ""
        
        -- Skip excluded devices
        if should_exclude_device(device_name) then
            log:debug("Skipping excluded device: " .. device_name)
            goto continue
        end
        
        -- Only process Sink type devices
        if not media_class:find("Sink") then
            goto continue
        end
        
        -- Calculate device score
        local score = calculate_device_score(device_name, props)
        
        log:debug("设备评分: " .. device_name .. " = " .. score)
        
        -- Select device with highest score
        if score > best_score and score >= device_config.min_priority then
            best_score = score
            best_device = device
            best_name = device_name
        end
        
        ::continue::
    end
    
    if best_device then
        log:info("Selected best device: " .. best_name .. " (score: " .. best_score .. ")")
    else
        log:warning("No suitable output device found")
    end
    
    return best_device
end

-- Update desktop_sink link
local function update_desktop_sink_link(om)
    if not Settings.get_boolean("desktop_sink.auto_connect") then
        return
    end
    
    -- Get desktop_sink monitor
    local monitor = dutils.get_desktop_sink_monitor(om)
    if not monitor then
        log:debug("desktop_sink monitor not found")
        return
    end
    
    state.desktop_sink_monitor = monitor
    
    -- Check current link status
    local current_status = dutils.get_link_status(monitor, om)
    if current_status then
        log:debug("Currently linked to: " .. current_status.target_name)
        state.current_link = current_status.link
        return  -- Already linked, no need to update
    end
    
    -- Select best output device
    local best_device = select_best_output_device(om)
    if not best_device then
        log:warning("No available output devices")
        return
    end
    
    -- Create new link
    local new_link = dutils.create_link(monitor, best_device, om)
    if new_link then
        state.current_link = new_link
        log:info("Successfully created link to: " .. (best_device.properties["node.name"] or "unknown"))
    else
        log:error("Failed to create link")
    end
end

-- 切换到指定设备
local function switch_to_device(device_name, om)
    log:info("Switching to device: " .. device_name)
    
    local monitor = dutils.get_desktop_sink_monitor(om)
    if not monitor then
        log:error("desktop_sink monitor not found")
        return false
    end
    
    -- 查找目标设备
    local target_device = nil
    for device in om:iterate {
        type = "SiLinkable",
        Constraint { "item.node.direction", "=", "output" },
        Constraint { "node.name", "=", device_name }
    } do
        target_device = device
        break
    end
    
    if not target_device then
        log:error("Device not found: " .. device_name)
        return false
    end
    
    -- 创建链接
    local link = dutils.create_link(monitor, target_device, om)
    if link then
        state.current_link = link
        return true
    else
        return false
    end
end

-- 扫描并更新链接（定时任务）
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
    update_desktop_sink_link(om)
end

-- Desktop Sink 链接选择钩子
-- 这个钩子在标准链接钩子之前执行，专门处理 desktop_sink 的链接
SimpleEventHook {
    name = "linking/find_desktop_sink_target",
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
        if not Settings.get_boolean("desktop_sink.auto_connect") then
            return
        end
        
        local source, om, si, si_props, si_flags, target =
            lutils:unwrap_select_target_event(event)
        
        -- 如果目标已选择，跳过
        if target then
            return
        end
        
        -- 检查是否是 desktop_sink 的 monitor
        local node_name = si_props["node.name"] or ""
        if not string.find(node_name, "desktop_sink") then
            return  -- 不是 desktop_sink，让其他钩子处理
        end
        
        log:info("Processing desktop_sink link: " .. node_name)
        
        -- 选择最佳设备
        local best_device = select_best_output_device(om)
        if best_device then
            log:info("Selected device: " .. (best_device.properties["node.name"] or "unknown"))
            
            -- 检查是否可以链接
            if lutils.canLink(si_props, best_device) then
                local passthrough_compatible, can_passthrough =
                    lutils.checkPassthroughCompatibility(si, best_device)
                
                if passthrough_compatible then
                    si_flags.can_passthrough = can_passthrough
                    event:set_data("target", best_device)
                    log:info("desktop_sink link target set")
                end
            end
        end
    end
}:register()

-- Device change event handling (background monitoring)
SimpleEventHook {
    name = "desktop_sink/device_changed",
    interests = {
        EventInterest {
            Constraint { "event.type", "=", "device-changed" },
        },
    },
    execute = function(event)
        if not Settings.get_boolean("desktop_sink.auto_connect") then
            return
        end
        
        local device = event:get_subject()
        if not device then
            return
        end
        
        local props = device.properties
        local device_name = props["node.name"] or ""
        
        log:debug("Device changed: " .. device_name)
        
        -- 延迟扫描，避免频繁更新
        Core.timeout_add(1000, function()
            scan_and_update()
            return false
        end)
    end
}:register()

-- 节点变化事件处理（后台监控）
SimpleEventHook {
    name = "desktop_sink/node_changed",
    interests = {
        EventInterest {
            Constraint { "event.type", "=", "node-changed" },
        },
    },
    execute = function(event)
        if not Settings.get_boolean("desktop_sink.auto_connect") then
            return
        end
        
        local node = event:get_subject()
        if not node then
            return
        end
        
        local props = node.properties
        local node_name = props["node.name"] or ""
        
        -- 检查是否是 desktop_sink 或输出设备
        if string.find(node_name, "desktop_sink") or
           (props["item.node.direction"] == "output" and 
            (props["media.class"] or ""):find("Sink")) then
            log:debug("Related node changed: " .. node_name)
            
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
    log:info("Starting desktop_sink link initialization")
    scan_and_update()
    
    -- 启动定期扫描
    Core.timeout_add_seconds(30, function()
        scan_and_update()
        return true  -- 继续执行
    end)
    
    return false  -- 只执行一次
end)

-- 导出函数供命令行工具使用
local M = {}

function M.switch_to_device(device_name)
    local om = cutils.get_object_manager("session-item")
    if not om then
        return false, "无法获取对象管理器"
    end
    
    return switch_to_device(device_name, om)
end

function M.get_status()
    local om = cutils.get_object_manager("session-item")
    if not om then
        return nil, "无法获取对象管理器"
    end
    
    local monitor = dutils.get_desktop_sink_monitor(om)
    if not monitor then
        return { connected = false, error = "desktop_sink monitor not found" }
    end
    
    local status = dutils.get_link_status(monitor, om)
    if status then
        return {
            connected = true,
            target = status.target_name,
            monitor = monitor.properties["node.name"] or "unknown"
        }
    else
        return { connected = false, monitor = monitor.properties["node.name"] or "unknown" }
    end
end

function M.list_devices()
    local om = cutils.get_object_manager("session-item")
    if not om then
        return {}, "无法获取对象管理器"
    end
    
    local devices = {}
    for device in om:iterate {
        type = "SiLinkable",
        Constraint { "item.node.direction", "=", "output" },
        Constraint { "media.class", "c", "Audio" }
    } do
        local props = device.properties
        local name = props["node.name"] or ""
        local media_class = props["media.class"] or ""
        
        if not should_exclude_device(name) and media_class:find("Sink") then
            table.insert(devices, {
                name = name,
                description = props["node.description"] or name,
                type = dutils.get_device_type(props),
                priority = dutils.calculate_device_priority(props),
                active = props["device.state"] == "active"
            })
        end
    end
    
    -- 按优先级排序
    table.sort(devices, function(a, b)
        return a.priority > b.priority
    end)
    
    return devices, nil
end

function M.enable()
    Settings.set_boolean("desktop_sink.auto_connect", true)
    log:info("Enabled desktop_sink auto-linking")
    scan_and_update()
    return true
end

function M.disable()
    Settings.set_boolean("desktop_sink.auto_connect", false)
    log:info("Disabled desktop_sink auto-linking")
    return true
end

-- 注册为全局模块
_G.desktop_sink = M

log:info("Desktop Sink 链接脚本已加载")

return M
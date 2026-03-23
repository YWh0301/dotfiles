-- WirePlumber Desktop Sink utility functions
--
-- Provides utility functions for desktop sink linking

local cutils = require ("common-utils")

local dutils = {}

-- 日志主题
dutils.log = nil

-- 初始化日志
function dutils.init_log()
    if not dutils.log then
        dutils.log = Log.open_topic ("s_desktop_sink")
    end
    return dutils.log
end

-- 检查是否为 desktop_sink 的 monitor 接口
function dutils.is_desktop_sink_monitor(node_props)
    local node_name = node_props["node.name"]
    local media_class = node_props["media.class"]
    
    -- desktop_sink monitor interface name is usually "desktop_sink.monitor"
    -- or other variants, but media.class should be "Audio/Source"
    if media_class == "Audio/Source" then
        -- 检查是否与 desktop_sink 相关
        local target_node = node_props["target.node"] or ""
        local target_object = node_props["target.object"] or ""
        
        if string.find(target_node, "desktop_sink") or 
           string.find(target_object, "desktop_sink") or
           string.find(node_name, "desktop_sink") then
            return true
        end
    end
    
    return false
end

-- 获取 desktop_sink 的 monitor 接口
function dutils.get_desktop_sink_monitor(om)
    dutils.init_log()
    
    for node in om:iterate {
        type = "SiLinkable",
        Constraint { "media.class", "=", "Audio/Source" }
    } do
        local props = node.properties
        local node_name = props["node.name"] or ""
        
        -- 查找 desktop_sink 相关的 monitor
        if string.find(node_name, "desktop_sink") then
            dutils.log:debug("找到 desktop_sink monitor: " .. node_name)
            return node
        end
        
        -- 检查 target 属性
        local target_node = props["target.node"] or ""
        if string.find(target_node, "desktop_sink") then
            dutils.log:debug("找到 desktop_sink 相关的 monitor (通过 target.node): " .. node_name)
            return node
        end
    end
    
    return nil
end

-- 获取所有可用的输出设备
function dutils.get_available_outputs(om)
    dutils.init_log()
    local outputs = {}
    
    for device in om:iterate {
        type = "SiLinkable",
        Constraint { "item.node.direction", "=", "output" },
        Constraint { "media.class", "c", "Audio" }
    } do
        local props = device.properties
        local node_name = props["node.name"] or ""
        local media_class = props["media.class"] or ""
        
        -- 排除 monitor 设备和 desktop_sink 本身
        if not string.find(node_name, "%.monitor$") and
           not string.find(node_name, "desktop_sink") and
           media_class:find("Sink") then
            
            -- 计算设备优先级
            local priority = dutils.calculate_device_priority(props)
            
            table.insert(outputs, {
                device = device,
                props = props,
                name = node_name,
                priority = priority,
                type = dutils.get_device_type(props)
            })
            
            dutils.log:debug("找到输出设备: " .. node_name .. " (优先级: " .. priority .. ")")
        end
    end
    
    -- 按优先级排序
    table.sort(outputs, function(a, b)
        if a.priority == b.priority then
            -- 如果优先级相同，按连接时间排序（新的优先）
            local a_plugged = tonumber(a.props["item.plugged.usec"] or "0")
            local b_plugged = tonumber(b.props["item.plugged.usec"] or "0")
            return a_plugged > b_plugged
        end
        return a.priority > b.priority
    end)
    
    return outputs
end

-- 计算设备优先级
function dutils.calculate_device_priority(props)
    local priority = 0
    local node_name = props["node.name"] or ""
    
    -- 基于设备类型的优先级
    if string.find(node_name, "bluez_output") then
        priority = priority + 100  -- 蓝牙设备最高优先级
    elseif string.find(node_name, "hdmi") then
        priority = priority + 90   -- HDMI 设备
    elseif string.find(node_name, "displayport") then
        priority = priority + 85   -- DisplayPort 设备
    elseif string.find(node_name, "analog") then
        priority = priority + 80   -- 模拟音频设备
    elseif string.find(node_name, "usb") then
        priority = priority + 75   -- USB 音频设备
    else
        priority = priority + 70   -- 其他 ALSA 设备
    end
    
    -- 基于会话优先级
    local session_priority = tonumber(props["priority.session"] or "0")
    priority = priority + math.floor(session_priority / 100)
    
    -- 基于驱动程序优先级
    local driver_priority = tonumber(props["priority.driver"] or "0")
    priority = priority + math.floor(driver_priority / 1000)
    
    -- 连接状态加分（已连接的设备优先）
    if props["device.state"] == "active" then
        priority = priority + 10
    end
    
    return priority
end

-- 获取设备类型
function dutils.get_device_type(props)
    local node_name = props["node.name"] or ""
    
    if string.find(node_name, "bluez_output") then
        return "bluetooth"
    elseif string.find(node_name, "hdmi") then
        return "hdmi"
    elseif string.find(node_name, "displayport") then
        return "displayport"
    elseif string.find(node_name, "analog") then
        return "analog"
    elseif string.find(node_name, "usb") then
        return "usb"
    else
        return "alsa"
    end
end

-- 检查两个设备是否可以链接
function dutils.can_link(source_props, target_props)
    -- 基本兼容性检查
    local source_media_type = source_props["media.type"] or ""
    local target_media_type = target_props["media.type"] or ""
    
    if source_media_type ~= target_media_type then
        dutils.log:debug("媒体类型不匹配: " .. source_media_type .. " != " .. target_media_type)
        return false
    end
    
    -- 检查音频格式兼容性（简化版）
    local source_format = source_props["audio.format"] or ""
    local target_format = target_props["audio.format"] or ""
    
    -- 如果格式不同但都是常见格式，仍然允许链接（PipeWire 会处理转换）
    if source_format ~= "" and target_format ~= "" and source_format ~= target_format then
        dutils.log:debug("音频格式不同: " .. source_format .. " != " .. target_format .. "，但允许链接")
    end
    
    return true
end

-- 创建从 monitor 到设备的链接
function dutils.create_link(monitor, target_device, om)
    dutils.init_log()
    
    local monitor_props = monitor.properties
    local target_props = target_device.properties
    
    dutils.log:info("创建链接: " .. (monitor_props["node.name"] or "unknown") .. 
                   " -> " .. (target_props["node.name"] or "unknown"))
    
    -- 检查是否已存在链接
    local existing_link = dutils.find_existing_link(monitor, om)
    if existing_link then
        dutils.log:debug("已存在链接，先移除: " .. tostring(existing_link))
        existing_link:remove()
    end
    
    -- 创建新的链接
    local link = SessionItem("si-standard-link")
    if not link then
        dutils.log:error("无法创建 si-standard-link")
        return nil
    end
    
    -- 配置链接属性
    local config = {
        ["out.item"] = monitor,          -- monitor 是源（输出）
        ["in.item"] = target_device,     -- 目标设备是接收器（输入）
        ["passthrough"] = true,          -- 启用直通模式
        ["exclusive"] = false,           -- 非独占模式
        ["out.item.port.context"] = "output",
        ["in.item.port.context"] = "input",
        ["media.role"] = monitor_props["media.role"] or "Desktop",
        ["target.media.class"] = target_props["media.class"],
        ["desktop_sink.link"] = true,    -- 标记为 desktop_sink 链接
    }
    
    if not link:configure(config) then
        dutils.log:error("配置链接失败")
        link:remove()
        return nil
    end
    
    -- 注册链接
    link:register()
    dutils.log:debug("链接已注册: " .. tostring(link))
    
    -- 激活链接
    link:activate(Feature.SessionItem.ACTIVE, function(l, err)
        if err then
            dutils.log:error("激活链接失败: " .. tostring(err))
            l:remove()
        else
            dutils.log:info("链接已激活: " .. (target_props["node.name"] or "unknown"))
        end
    end)
    
    return link
end

-- 查找已存在的链接
function dutils.find_existing_link(monitor, om)
    local monitor_id = monitor.id
    
    for link in om:iterate {
        type = "SiLink",
        Constraint { "item.factory.name", "=", "si-standard-link" }
    } do
        local out_item = link.properties["out.item"]
        local in_item = link.properties["in.item"]
        
        if out_item == monitor_id then
            return link
        end
    end
    
    return nil
end

-- 获取当前链接状态
function dutils.get_link_status(monitor, om)
    local link = dutils.find_existing_link(monitor, om)
    if not link then
        return nil
    end
    
    local target_id = link.properties["in.item"]
    local target = om:lookup {
        Constraint { "id", "=", target_id, type = "gobject" }
    }
    
    if target then
        return {
            link = link,
            target = target,
            target_name = target.properties["node.name"] or "unknown"
        }
    end
    
    return nil
end

return dutils
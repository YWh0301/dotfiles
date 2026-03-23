-- WirePlumber Pro Audio utility functions
--
-- Provides utility functions for proaudio_sink linking

local cutils = require ("common-utils")

local putils = {}

-- 日志主题
putils.log = nil

-- 初始化日志
function putils.init_log()
    if not putils.log then
        putils.log = Log.open_topic ("s_proaudio")
    end
    return putils.log
end

-- 检查是否为 proaudio_sink 的 monitor 接口
function putils.is_proaudio_sink_monitor(node_props)
    local node_name = node_props["node.name"] or ""
    local media_class = node_props["media.class"] or ""
    
    -- proaudio_sink 的 monitor 接口
    if media_class == "Audio/Source" then
        -- 检查是否与 proaudio_sink 相关
        local target_node = node_props["target.node"] or ""
        local target_object = node_props["target.object"] or ""
        
        if string.find(target_node, "proaudio_sink") or 
           string.find(target_object, "proaudio_sink") or
           string.find(node_name, "proaudio_sink") then
            return true
        end
    end
    
    return false
end

-- 获取 proaudio_sink 的所有 monitor 接口
function putils.get_proaudio_sink_monitors(om)
    putils.init_log()
    local monitors = {}
    
    for node in om:iterate {
        type = "SiLinkable",
        Constraint { "media.class", "=", "Audio/Source" }
    } do
        local props = node.properties
        local node_name = props["node.name"] or ""
        
        -- 查找 proaudio_sink 相关的 monitor
        if string.find(node_name, "proaudio_sink") then
            putils.log:debug("找到 proaudio_sink monitor: " .. node_name)
            
            -- 尝试确定是哪个 AUX 通道
            local channel = putils.determine_aux_channel(props)
            monitors[channel] = node
        end
        
        -- 检查 target 属性
        local target_node = props["target.node"] or ""
        if string.find(target_node, "proaudio_sink") then
            putils.log:debug("找到 proaudio_sink 相关的 monitor (通过 target.node): " .. node_name)
            
            local channel = putils.determine_aux_channel(props)
            monitors[channel] = node
        end
    end
    
    return monitors
end

-- 确定 AUX 通道（简化版：按找到的顺序分配）
function putils.determine_aux_channel(props)
    -- 这里简化处理，实际可能需要根据端口索引或其他属性
    -- 暂时返回通用标识
    return "proaudio_monitor"
end

-- 根据模式查找设备
function putils.find_device_by_pattern(om, pattern)
    putils.init_log()
    
    for device in om:iterate {
        type = "SiLinkable",
        Constraint { "item.node.direction", "=", "output" },
        Constraint { "media.class", "c", "Audio" }
    } do
        local props = device.properties
        local node_name = props["node.name"] or ""
        
        -- 排除 monitor 设备和虚拟设备
        if not string.find(node_name, "%.monitor$") and
           not string.find(node_name, "proaudio_sink") and
           not string.find(node_name, "desktop_sink") and
           not string.find(node_name, "Virtual") then
            
            -- 检查是否匹配模式
            if string.find(node_name, pattern) then
                putils.log:debug("找到匹配设备: " .. node_name .. " (模式: " .. pattern .. ")")
                return device
            end
        end
    end
    
    return nil
end

-- 创建专业音频链接（最小处理）
function putils.create_proaudio_link(source_monitor, target_device, om)
    putils.init_log()
    
    local monitor_props = source_monitor.properties
    local target_props = target_device.properties
    
    putils.log:info("创建专业音频链接: " .. (monitor_props["node.name"] or "unknown") .. 
                   " -> " .. (target_props["node.name"] or "unknown"))
    
    -- 检查是否已存在链接
    local existing_link = putils.find_existing_link(source_monitor, om)
    if existing_link then
        putils.log:debug("已存在链接，先移除: " .. tostring(existing_link))
        existing_link:remove()
    end
    
    -- 创建新的链接（使用专业音频参数）
    local link = SessionItem("si-standard-link")
    if not link then
        putils.log:error("无法创建 si-standard-link")
        return nil
    end
    
    -- 专业音频配置：最小处理，直通模式
    local config = {
        ["out.item"] = source_monitor,          -- monitor 是源
        ["in.item"] = target_device,            -- 目标设备
        ["passthrough"] = true,                 -- 直通模式，减少处理
        ["exclusive"] = true,                   -- 独占模式
        ["out.item.port.context"] = "output",
        ["in.item.port.context"] = "input",
        ["media.role"] = "ProAudio",            -- 专业音频角色
        ["target.media.class"] = target_props["media.class"],
        ["stream.dont-remix"] = true,           -- 禁止重混音
        ["proaudio.link"] = true,               -- 标记为 proaudio 链接
    }
    
    if not link:configure(config) then
        putils.log:error("配置专业音频链接失败")
        link:remove()
        return nil
    end
    
    -- 注册链接
    link:register()
    putils.log:debug("专业音频链接已注册: " .. tostring(link))
    
    -- 激活链接
    link:activate(Feature.SessionItem.ACTIVE, function(l, err)
        if err then
            putils.log:error("激活专业音频链接失败: " .. tostring(err))
            l:remove()
        else
            putils.log:info("专业音频链接已激活: " .. (target_props["node.name"] or "unknown"))
        end
    end)
    
    return link
end

-- 查找已存在的链接
function putils.find_existing_link(monitor, om)
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

-- 断开所有 proaudio 链接
function putils.disconnect_all_proaudio_links(om)
    putils.init_log()
    local removed_count = 0
    
    -- 查找所有 proaudio 链接
    for link in om:iterate {
        type = "SiLink",
        Constraint { "item.factory.name", "=", "si-standard-link" }
    } do
        local props = link.properties
        local out_item_id = props["out.item"]
        
        -- 查找源设备
        local source = om:lookup {
            Constraint { "id", "=", out_item_id, type = "gobject" }
        }
        
        if source then
            local source_props = source.properties
            local source_name = source_props["node.name"] or ""
            
            -- 检查是否是 proaudio_sink 的 monitor
            if string.find(source_name, "proaudio_sink") then
                putils.log:debug("断开 proaudio 链接: " .. tostring(link))
                link:remove()
                removed_count = removed_count + 1
            end
        end
    end
    
    putils.log:info("已断开 " .. removed_count .. " 个 proaudio 链接")
    return removed_count
end

-- 重新连接所有 proaudio 链接
function putils.reconnect_all_proaudio_links(om, channel_mapping)
    putils.init_log()
    
    -- 先断开所有现有链接
    putils.disconnect_all_proaudio_links(om)
    
    -- 获取所有 proaudio_sink 的 monitor
    local monitors = putils.get_proaudio_sink_monitors(om)
    if not next(monitors) then
        putils.log:warning("未找到 proaudio_sink monitor")
        return 0
    end
    
    local connected_count = 0
    
    -- 为每个 monitor 创建链接
    for channel, monitor in pairs(monitors) do
        -- 根据通道映射查找设备
        local mapping = channel_mapping[channel] or channel_mapping["AUX0"]
        if mapping then
            local device = putils.find_device_by_pattern(om, mapping.device_pattern)
            if device then
                local link = putils.create_proaudio_link(monitor, device, om)
                if link then
                    connected_count = connected_count + 1
                end
            else
                putils.log:warning("未找到映射设备: " .. (mapping.device_pattern or "unknown"))
            end
        end
    end
    
    putils.log:info("已重新连接 " .. connected_count .. " 个 proaudio 链接")
    return connected_count
end

-- 获取当前链接状态
function putils.get_proaudio_link_status(om)
    putils.init_log()
    local status = {
        monitors = {},
        links = {},
        total_links = 0
    }
    
    -- 查找所有 proaudio_sink 的 monitor
    local monitors = putils.get_proaudio_sink_monitors(om)
    for channel, monitor in pairs(monitors) do
        local monitor_name = monitor.properties["node.name"] or "unknown"
        local link = putils.find_existing_link(monitor, om)
        
        local monitor_status = {
            name = monitor_name,
            channel = channel,
            connected = false,
            target = nil
        }
        
        if link then
            local target_id = link.properties["in.item"]
            local target = om:lookup {
                Constraint { "id", "=", target_id, type = "gobject" }
            }
            
            if target then
                monitor_status.connected = true
                monitor_status.target = target.properties["node.name"] or "unknown"
                status.total_links = status.total_links + 1
            end
        end
        
        table.insert(status.monitors, monitor_status)
    end
    
    return status
end

return putils
---@diagnostic disable: lowercase-global

local L = locale ~= nil and locale ~= "zh" and locale ~= "zhr" and locale ~= "zht" -- true 英文  false 中文

name = L and "Anchor Teleport" or "传送锚点" -- 名称
version = "1.0.0"
author = "Mengsk"
forumthread = ""

description = L and
[[
Teleport where homesign at
]]
or
[[
点击地图，开始传送
]]

dst_compatible = true   -- dst兼容
client_only_mod = false -- 是否是客户端mod
all_clients_require_mod = true  -- 是否是所有客户端都需要安装
api_version = 10    -- 饥荒api版本，固定填10
-- modicon
icon_atlas = "modicon.xml"
icon = "modicon.tex"

server_filter_tags = {"AnchorTeleport"}
-- priority = -9999

configuration_options = 
{
    {
        name = "enable",
        label = L and "Mod Enable" or "Mod开关",
        hover = L and "Enable or Disable this mod" or "是否开启此mod",
        options = L and {
				{description = "Enable", data = true},
				{description = "Disable", data = false},
			} or {
				{description = "开启", data = true},
				{description = "关闭", data = false},
			},
        default = true,
    },
	{
        name = "searchrange",
        label = L and "Search Range" or "匹配范围",
        hover = L and "Vaild range when click map" or "点击地图时的有效范围",
        options = {
			{description = "5", data = 5},
			{description = "10", data = 10},
			{description = "15", data = 15},
			{description = "20", data = 20},
			{description = "25", data = 25},
		},
        default = 10,
    },
	{
        name = "clickcooldown",
        label = L and "Map Click CD" or "地图点击冷却",
        hover = L and "The cooldown between map teleport click" or "点击地图传送的cd",
        options = {
			{description = "0.5", data = 0.5},
			{description = "1", data = 1},
			{description = "3", data = 3},
			{description = "5", data = 5},
			{description = "10", data = 10},
			{description = "60", data = 60},
			{description = "300", data = 300},
		},
        default = 1,
    },
}
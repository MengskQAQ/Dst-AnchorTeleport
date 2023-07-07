local AnchorTeleport = Class(function(self, inst)
    self.inst = inst
	self._anchorinfo = net_string(inst.GUID, "_anchorinfo")
	self._ready = net_bool(inst.GUID, "_ready")

	self._iconworldpos = nil
	self.iconworldpos = nil

	self.update = false
end)

-------------------------------------------------------

function AnchorTeleport:SetReady(ready)
	return self._ready:set(ready)
end

function AnchorTeleport:IsReady()
	return self._ready:value()
end

-------------------------------------------------------

function AnchorTeleport:GetAnchorInfo()
	return self._anchorinfo:value()
end

function AnchorTeleport:SetAnchorInfo(anchorinfo)
	self._anchorinfo:set(anchorinfo)
	self:SetUpdateStatus(false)
end

-------------------------------------------------------

function AnchorTeleport:SetIconWorldPos(worldpos)
	self.iconworldpos = worldpos
end

function AnchorTeleport:GetIconWorldPos()
	return self.iconworldpos
end

-------------------------------------------------------

function AnchorTeleport:SetIconDeafultWorldPos(worldpos)
	self._iconworldpos = worldpos
end

function AnchorTeleport:GetIconDeafultWorldPos()
	return self._iconworldpos
end

-------------------------------------------------------

function AnchorTeleport:SetUpdateStatus(val)
	self.update = val
end

function AnchorTeleport:GetUpdateStatus()
	return self.update
end

-------------------------------------------------------

local function AT_GetTableString(table , level, key)	-- 传参时请勿输入key值, key值用于函数自身调用
	local str = ""
	key = key or ""
	level = level or 1
	local indent = ""

	for i = 1, level do
		indent = indent .."  "
	end

	if key ~= "" then
		str = str .. string.format("%s%s = { \n",indent, key)
	else
		str = str .. string.format("%s{ \n",indent)
	end

	key = ""
	for k,v in pairs(table) do
		if type(v) == "table" then
			key = k
			local text = AT_GetTableString(v, level + 1, key)
			str = str .. string.format("%s \n",text)
        elseif v.IsVector3 then
            str = str .. string.format("%d, %d, %d \n", v:Get())
		else
			str = str .. string.format("%s%s = %s \n", indent .. "  ",tostring(k), tostring(v))
		end
	end
	str = str .. string.format("%s} ",indent)
	return str
end

function AnchorTeleport:GetDebugString()
	local str = string.format("[Status]:ready:%s, update:%s \n", self:IsReady(), self:GetUpdateStatus())
    str = str .. string.format("[AnchorInfo]: \n")
	str = str .. string.format("[Icon]: DeafultWorldPos:(%d, %d, %d) WorldPos:(%d, %d, %d) \n", self._iconworldpos:Get(), self.iconworldpos:Get())
	local data = AT_GetTableString(json.decode(self._anchorinfo))
	str = str .. string.format("%s \n", data)
    return str
end

return AnchorTeleport
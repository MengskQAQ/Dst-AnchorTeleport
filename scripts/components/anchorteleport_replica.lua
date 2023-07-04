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

function AnchorTeleport:GetDebugString()
	local str = string.format("[Status]:ready:%s, update:%s \n", self:IsReady(), self:GetUpdateStatus())
    str = str .. string.format("[AnchorInfo]: \n")
	str = str .. string.format("[Icon]: DeafultWorldPos:(%d, %d, %d) WorldPos:(%d, %d, %d) \n", self._iconworldpos:Get(), self.iconworldpos:Get())
	local data = AT_GetTableString(json.decode(self._anchorinfo))
	str = str .. string.format("%s \n", data)
    return str
end

return AnchorTeleport
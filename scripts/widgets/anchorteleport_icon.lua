local Image = require "widgets/image"

local function UpdateIconPosition(self, pos)
    if pos == nil then return end

    local zoom = self.mapwidget.minimap:GetZoom()
    local screen_x, screen_y = self.mapwidget:AnchorTeleport_WorldPosToScreenPos(pos.x, pos.z)

    self:SetPosition(screen_x, screen_y, 0)
    self:SetScale(self.scale / math.pow(zoom, 0.5))
end

local AT_Icon = Class(Image, function(self, mapwidget, atlas, tex)
    Image._ctor(self, atlas, tex, tex)

	self.mapwidget = mapwidget
    self.scale = Vector3(1,1,1)

	self:SetVRegPoint(ANCHOR_MIDDLE)
	self:SetHRegPoint(ANCHOR_MIDDLE)
	self:SetScale(self.scale)

    self.UpdateIconPosition = UpdateIconPosition
	self:StartUpdating()
end)

function AT_Icon:GetDebugString()
	local str = string.format("IsShowing:%s", self:IsVisible())
	local pos = ThePlayer and ThePlayer.replica.anchorteleport and ThePlayer.replica.anchorteleport:GetIconWorldPos()
	if pos then
		str = str .. string.format("worldpos: (%d, %d, %d)", pos.x, pos.y, pos.z)
	else
		str = str .. string.format("worldpos: nil")
	end
	local cpos = self:GetPosition()
	str = str .. string.format("screenpos: (%d, %d, %d)", cpos.x, cpos.y, cpos.z)
	return str
end

function AT_Icon:OnUpdate(dt)
	local pos = ThePlayer and ThePlayer.replica.anchorteleport and ThePlayer.replica.anchorteleport:GetIconWorldPos()

	if pos == nil then
		if self:IsVisible() then
			self:Hide()
		end
		return
	end

	if not self:IsVisible() then
		self:Show()
	end
	self:UpdateIconPosition(pos)
end

return AT_Icon
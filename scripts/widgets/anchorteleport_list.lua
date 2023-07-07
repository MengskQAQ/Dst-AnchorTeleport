local ImageButton = require "widgets/imagebutton"
local Widget = require "widgets/widget"
local Text = require "widgets/text"

local AT_List = Class(Widget, function(self, mapwidget, atlas, tex)
    Widget._ctor(self, "anchorteleport_list")

    self.owner = ThePlayer
    -- self.root = self:AddChild(Widget("ROOT"))
    self.mapwidget = mapwidget

    self.card_atlas = atlas
    self.card_tex = tex

    self.maxnumshow = TUNING.ANCHORTELEPORT.MAXNUMSHOW or 5
	self.currentnum = 0
    self.scale = Vector3(1,1,1)
    self.basepos = nil

    -- self:SetScaleMode(SCALEMODE_PROPORTIONAL)
    -- self:SetMaxPropUpscale(MAX_HUD_SCALE)
    self:SetPosition(0, 0, 0)
    self:SetVAnchor(ANCHOR_MIDDLE)
    self:SetHAnchor(ANCHOR_MIDDLE)
    -- self:SetScale(0.8)

	self:InitAnchorLoot()
end)

--构造单个锚点卡
function AT_List:AnchorCard()
	local imagebutton = ImageButton(self.card_atlas, self.card_tex, nil, nil, nil, nil, {1,1}, {0,0}) --生成选项卡，编号不同

    imagebutton.serial = nil
    imagebutton.iconworldpos = nil

    imagebutton:SetScale(1, 1, 1)
    imagebutton:SetPosition(0, 0, 0)
    imagebutton:SetText("Null")
    imagebutton:SetOnClick(function ()
        local serial = imagebutton.serial
        SendModRPCToServer(MOD_RPC.AnchorTeleport.DOTP, serial)
    end)

    imagebutton:SetOnGainFocus(function()
        -- imagebutton:SetScale(imagebutton.scale + .05)
        local AT = ThePlayer and ThePlayer.replica.anchorteleport
        if AT then
            AT:SetIconWorldPos(imagebutton.iconworldpos)
        end
    end)

    -- imagebutton:SetOnLoseFocus(function()
    --     imagebutton:SetScale(imagebutton.scale)
    -- end)

	return imagebutton
end

function AT_List:InitAnchorLoot(num)
    num = num and math.max(self.maxnumshow, num) or self.maxnumshow   -- 超量了就不显示了
	for i=1, num do
		self["anchorcard_"..i] = self:AddChild(self:AnchorCard())
		self["anchorcard_"..i]:SetPosition(0, 0 - 32 * i)
		self["anchorcard_"..i]:Hide()
	end
end

function AT_List:KillAnchorLoot()
	for i=1, self.maxnumshow do
        if self["anchorcard_"..i] ~= nil then
            self["anchorcard_"..i]:Kill()
            self["anchorcard_"..i] = nil
        end
	end
end

function AT_List:SetAnchorInfo()
	local player = self.owner or ThePlayer
	local anchor_data

	if player and player.replica.anchorteleport then
        player.replica.anchorteleport:SetUpdateStatus(true)
		local anchorstr = player.replica.anchorteleport:GetAnchorInfo()
		anchor_data = anchorstr and anchorstr ~= "" and json.decode(anchorstr) -- 锚点列表解包
	end

    if anchor_data then

        local server_pos = anchor_data.pos or player.replica.anchorteleport:GetIconDeafultWorldPos()
        local client_pos = player.replica.anchorteleport:GetAnchorInfo()

        -- 数据包里的锚定点位是否和客户端当前的渲染点位一致
        if ( (server_pos.x ~= client_pos.x) or (server_pos.y ~= client_pos.y) or (server_pos.z ~= client_pos.z) ) then
            self.currentnum = 0
            self:Hide()
            return
        end

        self.basepos = server_pos   -- 锚定点位

        table.sort(anchor_data, function(a,b) return a.distsq < b.distsq end)

        local count = 1 -- 计数
		for k, v in ipairs(anchor_data) do
            if k ~= "pos" then
                local anchor_name = v.text or "(Null)"
                self["buff_card_" .. count].SetText(anchor_name)
                self["buff_card_" .. count].serial = v.serial
                self["buff_card_" .. count].iconworldpos = v.pos
                self["buff_card_" .. count]:Show()
                count=count+1

                -- 保险起见
                if self.maxnumshow < count then
                    break
                end
            end
		end

		self.currentnum = count

		if count > 1 then
			self:Show()
		end

		for i=count+1, self.maxbuffnum do
			self["buff_card_"..i]:Hide()
		end
	else
        self.currentnum = 0
		self:Hide()
	end

end

function AT_List:UpdateAnchorLootPos()
    local zoom = self.mapwidget.minimap:GetZoom()
    local screen_x, screen_y = self.mapwidget:AnchorTeleport_WorldPosToScreenPos(self.basepos.x, self.basepos.z)    -- 图标默认位置
    local screen_w, screen_h = TheSim:GetScreenSize() -- 获取屏幕尺寸（宽度，高度）

    if screen_w - screen_x > 5 then -- 优先显示在右侧
        
    end

    self:SetPosition(screen_x, screen_y, 0)
    self:SetScale(self.scale / math.pow(zoom, 0.5))
end

function AT_List:OnUpdate(dt)
    local AT = ThePlayer and ThePlayer.replica.anchorteleport
    if AT then

        if not AT:GetUpdateStatus() then
            self:SetAnchorInfo()
        end

        if ( self.currentnum == 0 or self.basepos == nil ) then
            return
        end

        if not self:IsVisible() then
            self:Show()
        end

        self:UpdateAnchorLootPos()

    end
end

function AT_List:GetDebugString()
	local str = string.format("IsShowing:%s \n", self:IsVisible())
	local AT = ThePlayer and ThePlayer.replica.anchorteleport
    if not AT then
        str = str .. string.format("AnchorTeleport: nil \n")
        return str
    end

	for i=1, self.maxnumshow do
        local card = self["anchorcard_"..i]
        if card ~= nil then
            str = str .. string.format("serial:%d iconworldpos:(%d, %d, %d), text:%s \n", card.serial, card.iconworldpos:Get(), card:GetText())
        end
	end

end

return AT_List
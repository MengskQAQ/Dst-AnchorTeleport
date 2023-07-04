local Screen = require "widgets/screen"
local Widget = require "widgets/widget"
local Text = require "widgets/text"

local TEMPLATES = require "widgets/redux/templates" -- 选项ui
local ScrollableList = require "widgets/scrollablelist"

local AnchorTeleportScreen = Class(Screen, function(self, owner, attach)
    Screen._ctor(self, "AnchorTeleportScreen")

    self.owner = owner
    self.root = self:AddChild(Widget("ROOT"))

	self.circle = self:AddChild(Image("images/hud2.xml", "yotb_sewing_slot.tex"))
	self.circle:SetScale(0.55, .43, 0)
	self.circle:SetPosition(-.5, -40, 0)
    self.circle:Hide()

    self.maxnumshow = TUNING.ANCHORTELEPORT.MAXNUMSHOW
	self.currentnum = 0

    self:SetScaleMode(SCALEMODE_PROPORTIONAL)
    self:SetMaxPropUpscale(MAX_HUD_SCALE)
    self:SetPosition(0, 0, 0)
    self:SetVAnchor(ANCHOR_TOP)
    self:SetHAnchor(ANCHOR_LEFT)
    self:SetScale(0.8)

	self:InitAnchorLoot()
	self.root:Hide()
end)

--构造单个锚点卡
function AnchorTeleportScreen:AnchorCard()
	local widget = Widget() --生成选项卡，编号不同

    widget.scale = 1

	widget.bg = widget:AddChild(Image("images/global.xml", "square.tex"))
	widget.bg:SetSize(224,32)
	widget.bg:SetTint(0, 0, 0, 0.3)

	--名称
	widget.name = widget:AddChild(Text(BODYTEXTFONT, 32))
	widget.name:SetPosition(37, 0)
	widget.name:SetRegionSize(190, 32)
	widget.name:SetHAlign(ANCHOR_LEFT)
	widget.name:SetString("锚点信息")
	widget.name:SetColour(1, 1, 1, 1)

    widget:SetOnGainFocus(function()
        TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
        widget:SetScale(widget.scale + .05)
    end)

    widget:SetOnLoseFocus(function()
        widget:SetScale(widget.scale)
    end)

    widget.OnControl = function(control, down)
        if self.focus and control == CONTROL_ATTACK then
			if down then
                local player = self.owner or ThePlayer
				local serial = self.serial
                SendModRPCToServer(MOD_RPC.AnchorTeleport.DOTP, player, serial)
			end
		end
        return false
    end

	return widget
end

function AnchorTeleportScreen:InitAnchorLoot(num)
    num = num and math.max(self.maxnumshow, num) or self.maxnumshow   -- 超量了就不显示了
	for i=1, num do
		self["anchorcard_"..i] = self.root:AddChild(self:AnchorCard())
		self["anchorcard_"..i]:SetPosition(0, 0-32*i)
		-- self["anchorcard_"..i]:Hide()
	end
end

function AnchorTeleportScreen:KillAnchorLoot()
	for i=1, self.maxnumshow do
        if self["anchorcard_"..i] ~= nil then
            self["anchorcard_"..i]:Kill()
            self["anchorcard_"..i] = nil
        end
	end
end

function AnchorTeleportScreen:SetAnchorInfo()
	local player = self.owner or ThePlayer
	local anchor_data

	if player and player.replica.anchorteleport then
		local anchorstr = player.replica.anchorteleport:GetAnchorInfo()
		anchor_data = anchorstr and anchorstr~="" and json.decode(anchorstr) -- 锚点列表解包
	end

    if anchor_data then
        table.sort(anchor_data, function(a,b) return a.distsq < b.distsq end)

        local count = 1 -- 计数
		for k, v in ipairs(anchor_data) do
			local anchor_name = v.text or "(Null)"
            self["buff_card_" .. count].name:SetString(anchor_name)
            self["buff_card_" .. count].serial = v.serial
            self["buff_card_" .. count]:Show()
            count=count+1

			-- 保险起见
			if self.maxnumshow < count then
				break
			end
		end
		self.currentnum = count
		if count > 1 then
			self.root:Show()
		end

		for i=count+1,self.maxbuffnum do
			self["buff_card_"..i]:Hide()
		end
	else
		self.root:Hide()
	end

end

function AnchorTeleportScreen:HideScreen()
	self.root:Hide()
end

function AnchorTeleportScreen:SetScreenPosition()

end

function AnchorTeleportScreen:ShowCircle()

end
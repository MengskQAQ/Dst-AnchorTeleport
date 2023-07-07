-- local GLOBAL = nil
-- local AddSimPostInit = nil
-- local AddClassPostConstruct = nil
-- local AddStategraphState = nil
GLOBAL.setmetatable(env, { __index = function(t, k) return GLOBAL.rawget(GLOBAL, k) end })

local require = GLOBAL.require
local ENABLE = GetModConfigData("enable") or true
local SEARCHRANGE = GetModConfigData("searchrange") or 10
local CLICKCOOLDOWN = GetModConfigData("clickcooldown") or 1
local MAXNUMSHOW = GetModConfigData("maxnumshow") or 5

AddReplicableComponent("anchorteleport")

if not ENABLE then return end

local icon_xml = "images/anchorteleport_icon.xml"
local icon_tex = "images/anchorteleport_icon.tex"
local list_xml = "images/anchorteleport_list.xml"
local list_tex = "images/anchorteleport_list.tex"

Assets = {
    Asset("ATLAS", icon_xml),
	Asset("IMAGE", icon_tex),

    Asset("ATLAS", list_xml),
	Asset("IMAGE", list_tex)
}

-------------------------------------------------------------------------------------------------------------------
------------------------------------------------------ TUNING -----------------------------------------------------
-------------------------------------------------------------------------------------------------------------------

TUNING.ANCHORTELEPORT = {
	ENABLE = ENABLE,
	CLICKCOOLDOWN = CLICKCOOLDOWN,
	SEARCHRANGE = SEARCHRANGE,
	MAXNUMSHOW = MAXNUMSHOW,
}

-------------------------------------------------------------------------------------------------------------------
------------------------------------------------------- RPC -------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------

AddModRPCHandler("AnchorTeleport", "CHECKPOINT", function(player, x, z)
	if player.components.anchorteleport then
		player.components.anchorteleport:CheckTeleportPoint(x, z)	-- 通过组件来传输信息
	end
end)

AddModRPCHandler("AnchorTeleport", "DOTP", function(player, serial)
	if player and player.components.anchorteleport then
		player.components.anchorteleport:Activate(player, serial)
	end
end)

-------------------------------------------------------------------------------------------------------------------
----------------------------------------------------- MpaScreen ---------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
local DOUBLECLICK_PERIOD = 0.3
local DOUBLECLICK_DIST = 25

AddSimPostInit(function()
	AddClassPostConstruct("screens/mapscreen", function(self)

        self.at_lasttime = 0
        self.at_lastpos = Vector3(0,0,0)

		local old_OnMouseButton = self.OnMouseButton
		function self:OnMouseButton(button, down, ...)
			if ThePlayer and ThePlayer:HasTag("AnchorTeleport") and not ThePlayer:HasTag("playerghost")
             and ThePlayer.replica.anchorteleport and down then

                local pos = GLOBAL.TheInput:GetScreenPosition()

                -- 右键地图
                if button == GLOBAL.MOUSEBUTTON_RIGHT then
                    ThePlayer.replica.anchorteleport:SetAnchorInfo("")
                    if ThePlayer.replica.anchorteleport:IsReady() then
                        local mousemappos = self:WidgetPosToMapPos(self:ScreenPosToWidgetPos(pos))
                        local x, z, _ = self.minimap:MapPosToWorldPos(mousemappos:Get()) 
                        ThePlayer.replica.anchorteleport:SetIconWorldPos(Vector3(x, 0, z))
                        SendModRPCToServer(MOD_RPC["AnchorTeleport"]["CHECKPOINT"], x, z)
                    end
                end

                -- 双击地图
                local time = GetStaticTime()
                if (button ~= GLOBAL.MOUSEBUTTON_RIGHT)
                 and (time - self.at_lasttime) < DOUBLECLICK_PERIOD
                 and pos:Dist(self.at_lastpos) < DOUBLECLICK_DIST then
                    ThePlayer.replica.anchorteleport:SetAnchorInfo("")
                end

                self.at_lasttime = time
                self.at_lastpos = pos
            end
			if old_OnMouseButton then
				old_OnMouseButton(self, button, down, ...)
			end
		end

		local old_OnDestroy = self.OnDestroy
		function self:OnDestroy()
			if ThePlayer and ThePlayer.replica.anchorteleport then
                ThePlayer.replica.anchorteleport:SetAnchorInfo("")
            end
			if old_OnDestroy then
				old_OnDestroy(self)
			end
		end

		-- local old_OnBecomeInactive = self.OnBecomeInactive
		-- function self:OnBecomeInactive()
		-- 	ThePlayer.HUD:HideAnchorTeleportMenu()
		-- 	if old_OnBecomeInactive then
		-- 		old_OnBecomeInactive(self)
		-- 	end
		-- end
	end)
end)

-------------------------------------------------------------------------------------------------------------------
---------------------------------------------------- MapWidget ----------------------------------------------------
-------------------------------------------------------------------------------------------------------------------

local Widget = require "widgets/widget"
local AT_Icon = require "widgets/anchorteleport_icon"
local AT_List = require "widgets/anchorteleport_list"

function AT_WorldPosToScreenPos(self, x, z)
	local screen_width, screen_height = TheSim:GetScreenSize()
	local half_x, half_y = RESOLUTION_X / 2, RESOLUTION_Y / 2
	local map_x, map_y = TheWorld.minimap.MiniMap:WorldPosToMapPos(x, z, 0)
	local screen_x = ((map_x * half_x) + half_x) / RESOLUTION_X * screen_width
	local screen_y = ((map_y * half_y) + half_y) / RESOLUTION_Y * screen_height
	return screen_x, screen_y
end

AddClassPostConstruct("widgets/mapwidget", function(self)
    if self.AnchorTeleport_WorldPosToScreenPos == nil then
		self.AnchorTeleport_WorldPosToScreenPos = AT_WorldPosToScreenPos
	end

	self.anchorteleport = self:AddChild(Widget("AnchorTeleport"))

    self.anchorteleport_icon = self.anchorteleport:AddChild(AT_Icon(self, icon_xml, icon_tex))
    self.anchorteleport_list = self.anchorteleport:AddChild(AT_List(self, list_xml, list_tex))
end)

-------------------------------------------------------------------------------------------------------------------
---------------------------------------------------- State --------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
local FRAMES = GLOBAL.FRAMES
local TimeEvent = GLOBAL.TimeEvent

AddStategraphState("wilson", function()
	return GLOBAL.State
    {
        name = "anchorteleport_tp",
        tags = { "doing", "busy", "nopredict", "nomorph", "nodangle" },

        onenter = function(inst, data)
            inst.sg.statemem.isphysicstoggle = true
            inst.Physics:ClearCollisionMask()
            inst.Physics:CollidesWith(COLLISION.GROUND)

            inst.Physics:Stop()
            inst.components.locomotor:Stop()

            inst.sg.statemem.pos = data.pos

            inst.AnimState:PlayAnimation("townportal_enter_pre")

            inst.sg.statemem.fx = SpawnPrefab("townportalsandcoffin_fx")
            inst.sg.statemem.fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
        end,

        timeline =
        {
            TimeEvent(8 * FRAMES, function(inst)
                inst.sg.statemem.isteleporting = true
                inst.components.health:SetInvincible(true)
                if inst.components.playercontroller ~= nil then
                    inst.components.playercontroller:Enable(false)
                end
                inst.DynamicShadow:Enable(false)
            end),
            TimeEvent(18 * FRAMES, function(inst)
                inst:Hide()
            end),
            TimeEvent(26 * FRAMES, function(inst)
                if inst.sg.statemem.pos ~= nil then
                    inst:ScreenFade(false)
                    if inst.Physics ~= nil then
                        inst.Physics:Teleport(inst.sg.statemem.pos:Get())
                    elseif inst.Transform ~= nil then
                        inst.Transform:SetPosition(inst.sg.statemem.pos:Get())
                    end

                    inst:Hide()
                    inst.sg.statemem.fx:KillFX()
                else
                    inst.sg:GoToState("exittownportal")
                end
            end),
        },

        onexit = function(inst)
            inst.sg.statemem.fx:KillFX()

            if inst.sg.statemem.isphysicstoggle then
                inst.sg.statemem.isphysicstoggle = nil
                inst.Physics:ClearCollisionMask()
                inst.Physics:CollidesWith(COLLISION.WORLD)
                inst.Physics:CollidesWith(COLLISION.OBSTACLES)
                inst.Physics:CollidesWith(COLLISION.SMALLOBSTACLES)
                inst.Physics:CollidesWith(COLLISION.CHARACTERS)
                inst.Physics:CollidesWith(COLLISION.GIANTS)
            end

            if inst.sg.statemem.isteleporting then
                inst.components.health:SetInvincible(false)
                if inst.components.playercontroller ~= nil then
                    inst.components.playercontroller:Enable(true)
                end
                inst:Show()
                inst.DynamicShadow:Enable(true)
            end
        end,
    }
end)

-------------------------------------------------------------------------------------------------------------------
---------------------------------------------------- Player -------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------

AddPlayerPostInit(function(inst)
	if GLOBAL.TheWorld.ismastersim then
		if not inst.components.anchorteleport then
			inst:AddComponent("anchorteleport")
		end
		return inst
	end
end)

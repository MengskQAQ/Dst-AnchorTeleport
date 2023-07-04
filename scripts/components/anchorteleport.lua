local function on_anchorinfo(self, anchorinfo)
	if anchorinfo ~= "" and self.inst.replica.anchorteleport then
		self.inst.replica.anchorteleport:SetAnchorInfo(anchorinfo)
	end
end

local function on_ready(self, ready)
	if self.inst.replica.anchorteleport then
		self.inst.replica.anchorteleport:SetReady(ready)
	end
end

local AnchorTeleport = Class(function(self, inst)
    self.inst = inst
	self.anchorinfo = ""
	self.anchorlist = {}	-- 这个用于客户端通信
	self.anchorlist_tmp = {}	-- 这个用于服务端处理逻辑，主要是为了减少通讯传输的数据量

	self.searchrange = TUNING.ANCHORTELEPORT.SEARCHRANGE
	self.clickcooldown = TUNING.ANCHORTELEPORT.CLICKCOOLDOWN

	self.ready = true
	self.readytask = nil
	
	self.travelcameratime = 3
    self.travelarrivetime = 4
	self.offset = 2

	self.inst:AddTag("AnchorTeleport")
end,
nil,
{
    anchorinfo = on_anchorinfo,
	ready = on_ready
})

-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------- 配置 -----------------------------------------------------
-------------------------------------------------------------------------------------------------------------------

function AnchorTeleport:OnRemoveFromEntity()
    self.inst:RemoveTag("AnchorTeleport")
end

-- 让大手子的手长一点
function AnchorTeleport:SetSearchRange(searchrange)
    self.searchrange = searchrange
end

-- 让点击器点快一点
function AnchorTeleport:SetClickCoolDown(clickcooldown)
    self.clickcooldown = clickcooldown
end

-------------------------------------------------------------------------------------------------------------------
--------------------------------------------------- 锚点信息传输 ---------------------------------------------------
-------------------------------------------------------------------------------------------------------------------

-- 定义符合规定的传送锚点
function AnchorTeleport:IsTaret(inst)
    return inst and inst.prefab == "homesign" and inst.components.writeable ~= nil
end

function AnchorTeleport:ReadyCheck()
	if not self.ready then 
		return false 
	end
	self.ready = false
	if self.readytask ~= nil then
		self.readytask:Cancel()
		self.readytask = nil
	end
	self.readytask = self.inst:DoTaskInTime(self.clickcooldown, function() self.ready = true end)
	return true
end

local exclude_tags = { "INLIMBO", "companion", "wall", "shadowminion"}
function AnchorTeleport:CheckTeleportPoint(x, z)
	if not self:ReadyCheck() then return false end

	self.anchorinfo = ""
	self.anchorlist = {}
	self.anchorlist_tmp = {}

	-- 遍历寻找范围内锚点
	local y = 0
	local serial = 1	-- 锚点编号
	local ents = TheSim:FindEntities(x, y, z, self.searchrange, { "sign" }, exclude_tags)
	for _, ent in ipairs(ents) do
		if self:IsTaret(ent) then
			local pos_x, pos_y, pos_z = ent.Transform:GetWorldPosition()
			local anchordata = {
				serial = serial,
				pos = Vector3(pos_x, pos_y, pos_z),
				distsq = ent:GetDistanceSqToPoint(x, y, z),
				text = ent.components.writeable:GetText(),
			}
			local anchordata_tmp = {
				serial = serial,
				inst = ent,
				pos = Vector3(pos_x, pos_y, pos_z),
			}
			serial = serial + 1
			table.insert(self.anchorlist, anchordata)
			table.insert(self.anchorlist_tmp, anchordata_tmp)
		end
	end

	if #self.anchorlist <= 0 then return false end

	if self.inst.replica.anchorteleport then
		self.inst.replica.anchorteleport:SetIconDeafultWorldPos(Vector3(x, y, z))
	end

	table.sort(self.anchorlist, function(a,b) return a.distsq < b.distsq end)	--排序
	self.anchorlist.pos = Vector3(x, y, z)
	self.anchorinfo = json.encode(self.anchorlist)	-- 转码

	return true
end

-------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------- 传送 ---------------------------------------------------
-------------------------------------------------------------------------------------------------------------------

local function oncameraarrive(inst, doer)
    if doer:IsValid() then
        doer:SnapCamera()
        doer:ScreenFade(true, 2)
    end
end

local function ondoerarrive(inst, self, doer)
	doer.sg:GoToState("exittownportal_pre")
end

function AnchorTeleport:Activate(doer, serial)

	if not serial then return end
	if not doer then return end

	-- 找到服务器缓存的传送锚点
	local pos_x, pos_y, pos_z = 0, 0, 0
	local tmp = false
	for _, v in pairs(self.anchorlist_tmp) do
		if v.serial == serial then
			if self:IsTaret(v.inst) then
				if v.pos then
					pos_x, pos_y, pos_z = v.pos:Get()
				else
					pos_x, pos_y, pos_z = v.inst.Transform:GetWorldPosition()
				end
				tmp = true
			end
			break
		end
	end
	if not tmp then return end

	-- 开始传送
	self:Teleport(doer, pos_x, pos_y, pos_z)

	-- 根据SG里的时间，传送相机
    doer:ScreenFade(false)
    self.inst:DoTaskInTime(self.travelcameratime, oncameraarrive, doer)
    self.inst:DoTaskInTime(self.travelarrivetime, ondoerarrive, self, doer)

	-- 玩家的一系列跟随者也一起传送
	if doer.components.leader ~= nil then
        for follower, v in pairs(doer.components.leader.followers) do
			if not (follower.components.follower ~= nil and follower.components.follower.noleashing) then
				self:Teleport(follower, pos_x, pos_y, pos_z)
			end
        end
    end

	if doer.components.inventory ~= nil then
        for k, item in pairs(doer.components.inventory.itemslots) do
            if item.components.leader ~= nil then
                for follower, v in pairs(item.components.leader.followers) do
                    self:Teleport(follower, pos_x, pos_y, pos_z)
                end
            end
        end
        -- special special case, look inside equipped containers
        for k, equipped in pairs(doer.components.inventory.equipslots) do
            if equipped.components.container ~= nil then
                for j, item in pairs(equipped.components.container.slots) do
                    if item.components.leader ~= nil then
                        for follower, v in pairs(item.components.leader.followers) do
                            self:Teleport(follower, pos_x, pos_y, pos_z)
                        end
                    end
                end
            end
        end
    end

	if self.inst.replica.anchorteleport then
		self.inst.replica.anchorteleport:SetAnchorInfo("")	-- 清空客户端缓存
	end
end

local function NoHoles(pt)
    return not TheWorld.Map:IsPointNearHole(pt)
end

local function NoPlayersOrHoles(pt)
    return not (IsAnyPlayerInRange(pt.x, 0, pt.z, 2) or TheWorld.Map:IsPointNearHole(pt))
end

function AnchorTeleport:Teleport(obj, x, y, z)
	local offset = self.offset
	local is_aquatic = obj.components.locomotor ~= nil and obj.components.locomotor:IsAquatic()
	local allow_ocean = is_aquatic or obj.components.amphibiouscreature ~= nil or obj.components.drownable ~= nil

	if offset ~= 0 then
		local pt = Vector3(x, y, z)
		local angle = math.random() * 2 * PI

		if not is_aquatic then
			offset =
				FindWalkableOffset(pt, angle, offset, 8, true, false, NoPlayersOrHoles, allow_ocean) or
				FindWalkableOffset(pt, angle, offset * .5, 6, true, false, NoPlayersOrHoles, allow_ocean) or
				FindWalkableOffset(pt, angle, offset, 8, true, false, NoHoles, allow_ocean) or
				FindWalkableOffset(pt, angle, offset * .5, 6, true, false, NoHoles, allow_ocean)
		else
			offset =
				FindSwimmableOffset(pt, angle, offset, 8, true, false, NoPlayersOrHoles) or
				FindSwimmableOffset(pt, angle, offset * .5, 6, true, false, NoPlayersOrHoles) or
				FindSwimmableOffset(pt, angle, offset, 8, true, false, NoHoles) or
				FindSwimmableOffset(pt, angle, offset * .5, 6, true, false, NoHoles)
		end

		if offset ~= nil then
			x = x + offset.x
			z = z + offset.z
		end
	end

	local ocean_at_point = TheWorld.Map:IsOceanAtPoint(x, y, z, false)
	if ocean_at_point then
		if not allow_ocean then
			local terrestrial = obj.components.locomotor ~= nil and obj.components.locomotor:IsTerrestrial()
			if terrestrial then
				return
			end
		end
	else
		if is_aquatic then
			return
		end
	end

	if obj.Physics ~= nil then
		obj.Physics:Teleport(x, y, z)
	elseif obj.Transform ~= nil then
		obj.Transform:SetPosition(x, y, z)
	end
end

function AnchorTeleport:GetAnchorInfo()
	return self.anchorinfo
end

function AnchorTeleport:GetDebugString()
	local str =  string.format("[AnchorTeleport] \n")
	str = str .. string.format("[TUNING]:searchrange:%d, clickcooldown:%d, ", self.searchrange, self.clickcooldown)
	str = str .. string.format("travelcameratime:%d, travelarrivetime:%d, offset:%d \n", self.travelcameratime, self.travelarrivetime, self.offset)
	str = str .. string.format("[READY]:ready:%s, readytask:%s \n", self.ready, self.readytask ~= nil)
    str = str .. string.format("[AnchorList]SendToClient: \n")
	str = str .. string.format("mouseclickpos: (%d, %d, %d) \n", self.anchorlist.pos:Get() )
	-- str = str .. string.format("%s \n", AT_GetTableString(self.anchorlist))
	-- str = str .. string.format("[AnchorList_ServerBackup]: \n")
	-- str = str .. string.format("%s \n", AT_GetTableString(self.anchorlist_tmp))
	for k, v in ipairs(self.anchorlist) do
		if k ~= "pos" then
			str = str .. string.format("serial:%d, pos:(%d, %d, %d), distsq:%d, text:%s \n", v.serial, v.pos:Get(), v.distsq, v.text)
		end
	end
	str = str .. string.format("[AnchorList]ServerBackup: \n")
	for k, v in ipairs(self.anchorlist_tmp) do
		str = str .. string.format("serial:%d, pos:(%d, %d, %d), prefab:%s, guid:%d \n", v.serial, v.pos:Get(), v.inst.prefab or "nil", v.inst.guid or nil)
	end
    return str
end

return AnchorTeleport
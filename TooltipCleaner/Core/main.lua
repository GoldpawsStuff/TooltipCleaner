--[[

	The MIT License (MIT)

	Copyright (c) 2023 Lars Norberg

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.

--]]
local Addon, ns = ...

local L = LibStub("AceLocale-3.0"):GetLocale(Addon, true)

local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceGUI = LibStub("AceGUI-3.0")

ns = LibStub("AceAddon-3.0"):NewAddon(ns, Addon, "LibMoreEvents-1.0", "AceConsole-3.0", "AceHook-3.0")

-- Lua API
local select = select
local string_gsub = string.gsub
local string_match = string.match
local tonumber = tonumber

-- WoW Client Constants
-----------------------------------------------------------
local IsRetail = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)
local IsClassic = (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC)
local IsTBC = (WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC)
local IsWrath = (WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC)
local WoW10 = select(4,GetBuildInfo()) >= 100000

-- Localized search patterns
-----------------------------------------------------------
local L_SELL_PRICE = SELL_PRICE -- "Sell Price"
local L_ITEM_MIN_LEVEL = "^" .. string_gsub(ITEM_MIN_LEVEL, "%%d", "(%%d+)") -- "Requires Level %d"
local L_ITEM_MIN_SKILL = "^" .. string_gsub(string_gsub(ITEM_MIN_SKILL, "%%s", "(%%s+)"), "%%d", "(%%d+)") -- "Requires %s (%d)"
local L_DURABILITY_TEMPLATE = string_gsub(DURABILITY_TEMPLATE, "%%d", "(%%d+)") -- "Durability %d / %d"

-- Backdrop template for Lua and XML
-- Allows us to always set these templates, even in Classic.
-----------------------------------------------------------
local MixinGlobal = Addon.."BackdropTemplateMixin"
_G[MixinGlobal] = {}
if (BackdropTemplateMixin) then
	_G[MixinGlobal] = CreateFromMixins(BackdropTemplateMixin) -- Usable in XML
	ns.BackdropTemplate = "BackdropTemplate" -- Usable in Lua
end

-- Default settings.
-----------------------------------------------------------
local defaults = {
	profile = {
		hideBlizzardSellValue = true,
		hideFullDurability = true,
		hideMetRequirements = true,
		hideUnusedStats = IsRetail or nil, -- no such thing in the classics
		hideMissingSetBonuses = true,
		hidePvP = IsRetail, -- still useful on classic realms
		hideFaction = true
	}
}

-- Affected tooltips.
local tooltips = {
	[GameTooltip] = true,
	[EmbeddedItemTooltip] = true,
	[ItemRefTooltip] = true,
	[ItemRefShoppingTooltip1] = true,
	[ItemRefShoppingTooltip2] = true,
	[ShoppingTooltip1] = true,
	[ShoppingTooltip2] = true
}

ns.GetOptionsObject = function(self)
	if (not self.options) then
		local options = {
			type = "group",
			args = {
				itemHeader = {
					order = 1,
					type = "header",
					name = L["Item Tooltips"]
				},
				hideBlizzardSellValue = {
					order = 10,
					width = "full",
					name = L["Hide Blizzard vendor prices."],
					desc = L["Hides vendors prices from default tooltip when enabled."],
					type = "toggle",
					set = function(info,val)
						ns:GetSettings().profile.hideBlizzardSellValue = val
						ns:UpdateSettings()
					end,
					get = function(info) return ns:GetSettings().profile.hideBlizzardSellValue end
				},
				hideMetRequirements = {
					order = 11,
					width = "full",
					name = L["Hide superflous item requirements."],
					desc = L["Hides item requirements and equip criteria you have matched."],
					type = "toggle",
					set = function(info,val)
						ns:GetSettings().profile.hideMetRequirements = val
						ns:UpdateSettings()
					end,
					get = function(info) return ns:GetSettings().profile.hideMetRequirements end
				},
				hideFullDurability = {
					order = 12,
					width = "full",
					name = L["Hide full durability."],
					desc = L["Hides item durability when the item has full durability."],
					type = "toggle",
					set = function(info,val)
						ns:GetSettings().profile.hideFullDurability = val
						ns:UpdateSettings()
					end,
					get = function(info) return ns:GetSettings().profile.hideFullDurability end
				},
				hideUnusedStats = IsRetail and {
					order = 13,
					width = "full",
					name = L["Hide grayed out item stats."],
					desc = L["Hides grayed out item stats your character can't currently use."],
					type = "toggle",
					set = function(info,val)
						ns:GetSettings().profile.hideUnusedStats = val
						ns:UpdateSettings()
					end,
					get = function(info) return ns:GetSettings().profile.hideUnusedStats end
				} or nil,
				hideMissingSetBonuses = {
					order = 14,
					width = "full",
					name = L["Hide unachieved set bonuses."],
					desc = L["Hides set bonuses you haven't collected enough items to receive yet."],
					type = "toggle",
					set = function(info,val)
						ns:GetSettings().profile.hideUnusedStats = val
						ns:UpdateSettings()
					end,
					get = function(info) return ns:GetSettings().profile.hideUnusedStats end
				},
				unitHeader = {
					order = 20,
					type = "header",
					name = L["Unit Tooltips"]
				},
				hidePvP = {
					order = 21,
					width = "full",
					name = L["Hide PvP status."],
					desc = L["Hides a unit's PvP status."],
					type = "toggle",
					set = function(info,val)
						ns:GetSettings().profile.hidePvP = val
						ns:UpdateSettings()
					end,
					get = function(info) return ns:GetSettings().profile.hidePvP end
				},
				hideFaction = {
					order = 22,
					width = "full",
					name = L["Hide factions."],
					desc = L["Hides a unit's faction allegiance."],
					type = "toggle",
					set = function(info,val)
						ns:GetSettings().profile.hideFaction = val
						ns:UpdateSettings()
					end,
					get = function(info) return ns:GetSettings().profile.hideFaction end
				}
			}
		}
		self.options = options
	end
	return self.options
end

ns.GetSettings = function(self)
	if (not self.db) then
		self.db = LibStub("AceDB-3.0"):New("TooltipCleaner_DB", defaults, true)
	end
	return self.db
end

ns.UpdateSettings = function(self)
	local db = self:GetSettings().profile

	if (db.hideBlizzardSellValue) then
		if (WoW10) then
			if (not self:IsHooked("SetTooltipMoney", "OnSetTooltipMoney")) then
				self:SecureHook("SetTooltipMoney", "OnSetTooltipMoney")
			end
		else
			for tooltip in next,tooltips do
				tooltip:SetScript("OnTooltipAddMoney", nil)
				GameTooltip_ClearMoney(tooltip)
			end
		end
	else
		if (WoW10) then
			if (self:IsHooked("SetTooltipMoney", "OnSetTooltipMoney")) then
				self:Unhook("SetTooltipMoney", "OnSetTooltipMoney")
			end
		else
			for tooltip in next,tooltips do
				tooltip:SetScript("OnTooltipAddMoney", GameTooltip_OnTooltipAddMoney)
			end
		end
	end

	if (db.hideMetRequirements or db.hideFullDurability or db.hideUnusedStats or db.hideMissingSetBonuses) then
		if (WoW10) then
			if (not self.itemHoked) then
				TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, ...)
					if (tooltips[tooltip] and (db.hideMetRequirements or db.hideFullDurability or db.hideUnusedStats or db.hideMissingSetBonuses)) then
						self:OnTooltipSetItem(tooltip, ...)
					end
				end)
				self.itemHooked = true
			end
		else
			for tooltip in next,tooltips do
				if (not self:IsHooked(tooltip, "OnTooltipSetItem")) then
					self:SecureHookScript(tooltip, "OnTooltipSetItem", "OnTooltipSetItemClassic")
				end
			end
		end
	else
		if (not WoW10) then
			for tooltip in next,tooltips do
				if (self:IsHooked(tooltip, "OnTooltipSetItem")) then
					self:Unhook(tooltip, "OnTooltipSetItem")
				end
			end
		end
	end

	if (db.hidePvP or db.hideFaction) then
		if (WoW10) then
			if (not self.unitHooked) then
				TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, ...)
					if (tooltips[tooltip] and (db.hidePvP or db.hideFaction)) then
						self:OnTooltipSetUnit(tooltip, ...)
					end
				end)
				self.unitHooked = true
			end
		else
			for tooltip in next,tooltips do
				if (not self:IsHooked(tooltip, "OnTooltipSetUnit")) then
					self:SecureHookScript(tooltip, "OnTooltipSetUnit", "OnTooltipSetUnitClassic")
				end
			end
		end
	else
		if (not WoW10) then
			for tooltip in next,tooltips do
				self:SecureHookScript(tooltip, "OnTooltipSetUnit", "OnTooltipSetUnit")
				if (self:IsHooked(tooltip, "OnTooltipSetUnit")) then
					self:Unhook(tooltip, "OnTooltipSetUnit")
				end
			end
		end
	end

end

ns.OnSetTooltipMoney = function(self, tooltip, money, type, prefixText, suffixText)
	if (tooltips[tooltip]) then
		if (tooltip.hasMoney and prefixText and string_match(prefixText, L_SELL_PRICE)) then
			GameTooltip_ClearMoney(tooltip)

			-- SetTooltipMoney adds a blank line, and this hook is called directly after,
			-- It should be a fairly safe assumption that the last line in the tooltip is its space.
			local i = GameTooltip:NumLines()
			local tipName = tooltip:GetName()
			local tipText = _G[tipName.."TextLeft"..i]
			if (tipText and tipText:GetText() == " ") then
				tipText:SetText("")
				tipText:Hide()
			end
		end
	end
end

ns.OnTooltipSetItem = function(self, tooltip, tooltipData)
	if (not tooltip) or (tooltip:IsForbidden()) then return end

	local db = self.db.profile
	local tipName = tooltip:GetName()
	local foundLevel, foundSkill, foundDurability = false, false, false

	-- Assign data to 'type' and 'guid' fields.
	TooltipUtil.SurfaceArgs(tooltipData)

	-- Assign data to 'leftText' fields.
	for _,line in ipairs(tooltipData.lines) do
		TooltipUtil.SurfaceArgs(line)
	end

	for i = #tooltipData.lines,1,-1 do
		local line = tooltipData.lines[i]
		local msg = line.leftText

		if (not msg) then break end

		if (db.hideMetRequirements and not foundLevel) then

			local level = string_match(msg, L_ITEM_MIN_LEVEL)
			if (level) then
				local playerLevel = UnitLevel("player")
				if (playerLevel >= tonumber(level)) then
					local tipText = _G[tipName.."TextLeft"..i]
					tipText:SetText("")
					tipText:Hide()
				end
				foundLevel = true
			end

			--local skill = string_match(msg, L_ITEM_MIN_SKILL)
			--if (skill) then
			--	_G[tipName.."TextLeft"..i]:SetText(nil)
			--	_G[tipName.."TextRight"..i]:SetText(nil)
			--	print("found skill level:", skill)
			--	foundSkill = true
			--end

		end

		if (db.hideFullDurability and not foundDurability) then
			local min,max = string_match(msg, L_DURABILITY_TEMPLATE)
			if (min and max) then
				if (min == max) then
					local tipText = _G[tipName.."TextLeft"..i]
					tipText:SetText("")
					tipText:Hide()
				end
				foundDurability = true
			end
		end

		if (db.hideUnusedStats or db.hideMissingSetBonuses) then
			local r, g, b = line.leftColor.r, line.leftColor.g, line.leftColor.b
			if (r == g and g == b and r > 0.49 and r < 0.51) then
				local tipText = _G[tipName.."TextLeft"..i]
				if (db.hideUnusedStats and string_match(msg, "^%+?%-?%d+%s+%w+")) then
					tipText:SetText("")
					tipText:Hide()
				end
				if (db.hideMissingSetBonuses and string_match(msg, "^%(%d+%)%s+.+")) then
					tipText:SetText("")
					tipText:Hide()
				end
			end
		end

		if (db.hideMetRequirements == foundLevel and db.hideFullDurability == foundDurability and not db.hideUnusedStats and not db.hideMissingSetBonuses) then
			break
		end
	end

end

ns.OnTooltipSetItemClassic = function(self, tooltip)
	if (not tooltip) or (tooltip:IsForbidden()) then return end

	--local name, link = tooltip.GetItem and tooltip:GetItem()
	--if (not link) then return end

	local db = self.db.profile
	local tipName = tooltip:GetName()

	local foundLevel, foundSkill, foundDurability = false, false, false

	for i = tooltip:NumLines(),1,-1 do
		local line = _G[tipName.."TextLeft"..i]
		local msg = line and line:GetText()

		if (not msg) then break end

		if (db.hideMetRequirements and not foundLevel) then

			local level = string_match(msg, L_ITEM_MIN_LEVEL)
			if (level) then
				local playerLevel = UnitLevel("player")
				if (playerLevel >= tonumber(level)) then
					line:SetText("")
					line:Hide()
				end
				foundLevel = true
			end

			--local skill = string_match(msg, L_ITEM_MIN_SKILL)
			--if (skill) then
			--	_G[tipName.."TextLeft"..i]:SetText(nil)
			--	_G[tipName.."TextRight"..i]:SetText(nil)
			--	print("found skill level:", skill)
			--	foundSkill = true
			--end

		end

		if (db.hideFullDurability and not foundDurability) then
			local min,max = string_match(msg, L_DURABILITY_TEMPLATE)
			if (min and max) then
				if (min == max) then
					line:SetText("")
					line:Hide()
				end
				foundDurability = true
			end
		end

		if (db.hideMissingSetBonuses) then
			local r, g, b = line:GetTextColor()
			if (r == g and g == b and r > 0.49 and r < 0.51) then
				if (string_match(msg, "^%(%d+%)%s+.+")) then
					line:SetText("")
					line:Hide()
				end
			end
		end

		if (db.hideMetRequirements == foundLevel and db.hideFullDurability == foundDurability and not db.hideMissingSetBonuses) then
			break
		end
	end

end

ns.OnTooltipSetUnit = function(self, tooltip, tooltipData)
	if (not tooltip) or (tooltip:IsForbidden()) then return end

	local _, unit = tooltip:GetUnit()
	if (not unit) then
		local GMF = GetMouseFocus()
		local focusUnit = GMF and GMF.GetAttribute and GMF:GetAttribute("unit")
		if (focusUnit) then unit = focusUnit end
		if (not unit or not UnitExists(unit)) then
			return
		end
	end

	local db = self.db.profile
	local tipName = tooltip:GetName()

	-- Assign data to 'type' and 'guid' fields.
	TooltipUtil.SurfaceArgs(tooltipData)

	-- Assign data to 'leftText' fields.
	for _,line in ipairs(tooltipData.lines) do
		TooltipUtil.SurfaceArgs(line)
	end

	local foundPvP, foundFaction = false, false
	for i = #tooltipData.lines,1,-1 do
		local line = tooltipData.lines[i]
		local msg = line.leftText

		if (not msg) then break end

		if (db.hidePvP and not foundPvP) then
			if (msg == PVP) then
				local tipText = _G[tipName.."TextLeft"..i]
				tipText:SetText("")
				tipText:Hide()
				foundPvP = true
			end
		end

		if (db.hideFaction and not foundFaction) then
			if (msg == FACTION_ALLIANCE or msg == FACTION_HORDE or msg == FACTION_NEUTRAL) then
				local tipText = _G[tipName.."TextLeft"..i]
				tipText:SetText("")
				tipText:Hide()
				foundFaction = true
			end
		end

		if (db.hidePvP == foundPvP and db.hideFaction == foundFaction) then
			break
		end
	end

end

ns.OnTooltipSetUnitClassic = function(self, tooltip)
	if (not tooltip) or (tooltip:IsForbidden()) then return end

	local _, unit = tooltip:GetUnit()
	if (not unit) then
		local GMF = GetMouseFocus()
		local focusUnit = GMF and GMF.GetAttribute and GMF:GetAttribute("unit")
		if (focusUnit) then unit = focusUnit end
		if (not unit or not UnitExists(unit)) then
			return
		end
	end

	local db = self.db.profile
	local tipName = tooltip:GetName()

	local foundPvP, foundFaction = false, false

	for i = tooltip:NumLines(),1,-1 do
		local line = _G[tipName.."TextLeft"..i]
		local msg = line and line:GetText()

		if (not msg) then break end

		if (db.hidePvP and not foundPvP) then
			if (msg == PVP) then
				line:SetText("")
				line:Hide()
				foundPvP = true
			end
		end

		if (db.hideFaction and not foundFaction) then
			if (msg == FACTION_ALLIANCE or msg == FACTION_HORDE) then
				line:SetText("")
				line:Hide()
				foundFaction = true
			end
		end

		if (db.hidePvP == foundPvP and db.hideFaction == foundFaction) then
			break
		end
	end

end

ns.OnInitialize = function(self)
	AceConfigRegistry:RegisterOptionsTable(Addon, self:GetOptionsObject())
	AceConfigDialog:AddToBlizOptions(Addon, Addon)
end

ns.OnEnable = function(self)
	self:UpdateSettings()
end

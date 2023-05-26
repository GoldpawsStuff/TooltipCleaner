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
		hideMetRequirements = true
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
				hideBlizzardSellValue = {
					order = 1,
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
					order = 1,
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
					order = 1,
					width = "full",
					name = L["Hide full durability."],
					desc = L["Hides item durability when the item has full durability."],
					type = "toggle",
					set = function(info,val)
						ns:GetSettings().profile.hideFullDurability = val
						ns:UpdateSettings()
					end,
					get = function(info) return ns:GetSettings().profile.hideFullDurability end
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
	local db = self:GetSettings()
	if (db.profile.hideBlizzardSellValue) then
		if (WoW10) then
			if (not self:IsHooked("SetTooltipMoney", "OnSetTooltipMoney")) then
				self:SecureHook("SetTooltipMoney", "OnSetTooltipMoney")
			end
		else
			GameTooltip:SetScript("OnTooltipAddMoney", nil)
			GameTooltip_ClearMoney(GameTooltip)
		end
	else
		if (WoW10) then
			if (self:IsHooked("SetTooltipMoney", "OnSetTooltipMoney")) then
				self:Unhook("SetTooltipMoney", "OnSetTooltipMoney")
			end
		else
			GameTooltip:SetScript("OnTooltipAddMoney", GameTooltip_OnTooltipAddMoney)
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
			local left,right = _G[tipName.."TextLeft"..i], _G[tipName.."TextRight"..i]
			if (left and left:GetText() == " ") then
				left:SetText(nil)
				right:SetText(nil)
			end
		end
	end
end

ns.OnTooltipSetItem = function(self, tooltip, tooltipData)
	if (not tooltip) or (tooltip:IsForbidden()) then return end

	local tipName = tooltip:GetName()
	local name, link = tooltip.GetItem and tooltip:GetItem()
	if (not link) then
		return
	end

	local db = self:GetSettings().profile
	if (not db.hideBlizzardSellValue and not db.hideMetRequirements) then
		return
	end

	-- Assign data to 'type' and 'guid' fields.
	TooltipUtil.SurfaceArgs(tooltipData)

	-- Assign data to 'leftText' fields.
	for _,line in ipairs(tooltipData.lines) do
		TooltipUtil.SurfaceArgs(line)
	end

	local foundLevel,foundSkill, foundDurability
	for i,line in ipairs(tooltipData.lines) do
		local msg = line.leftText
		if (not msg) then break end

		if (db.hideMetRequirements) then

			local level = string_match(msg, L_ITEM_MIN_LEVEL)
			if (level) then
				local playerLevel = UnitLevel("player")
				if (playerLevel >= tonumber(level)) then
					_G[tipName.."TextLeft"..i]:SetText(nil)
					_G[tipName.."TextRight"..i]:SetText(nil)
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

		if (db.hideFullDurability) then
			local min,max = string_match(msg, L_DURABILITY_TEMPLATE)
			if (min and max) then
				if (min == max) then
					_G[tipName.."TextLeft"..i]:SetText(nil)
					_G[tipName.."TextRight"..i]:SetText(nil)
				end
				foundDurability = true
			end
		end

	end

end

ns.OnTooltipSetUnit = function(self, tooltip, data)
	if (not tooltip) or (tooltip:IsForbidden()) then return end

	do return end

	local _, unit = tooltip:GetUnit()
	if not unit then
		local GMF = GetMouseFocus()
		local focusUnit = GMF and GMF.GetAttribute and GMF:GetAttribute("unit")
		if focusUnit then unit = focusUnit end
		if not unit or not UnitExists(unit) then
			return
		end
	end

	if (UnitIsPlayer(unit)) then
		local color = GetUnitColor(unit)
		if (color) then

			local unitName, unitRealm = UnitName(unit)
			local unitEffectiveLevel = UnitEffectiveLevel(unit)
			local displayName = color.colorCode..unitName.."|r"
			local gray = Colors.quest.gray.colorCode
			local levelText

			--if (unitEffectiveLevel and unitEffectiveLevel > 0) then
			--	local r, g, b, colorCode = GetDifficultyColorByLevel(unitEffectiveLevel)
			--	levelText = colorCode .. unitEffectiveLevel .. "|r"
			--end
			--if (not levelText) then
			--	displayName = BOSS_TEXTURE .. " " .. displayName
			--end


			if (unitRealm and unitRealm ~= "") then

				local relationship = UnitRealmRelationship(unit)
				if (relationship == _G.LE_REALM_RELATION_COALESCED) then
					displayName = displayName ..gray.. _G.FOREIGN_SERVER_LABEL .."|r"

				elseif (relationship == _G.LE_REALM_RELATION_VIRTUAL) then
					displayName = displayName ..gray..  _G.INTERACTIVE_SERVER_LABEL .."|r"
				end
			end

			if (levelText) then
				_G.GameTooltipTextLeft1:SetText(levelText .. gray .. ": |r" .. displayName)
			else
				_G.GameTooltipTextLeft1:SetText(displayName)
			end

		end

	end

end

ns.OnInitialize = function(self)
	AceConfigRegistry:RegisterOptionsTable(Addon, self:GetOptionsObject())
	AceConfigDialog:AddToBlizOptions(Addon, Addon)
end

ns.OnEnable = function(self)

	if (WoW10) then

		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, ...)
			if (tooltips[tooltip]) then
				self:OnTooltipSetItem(tooltip, ...)
			end
		end)

		--TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, ...)
		--	if (tooltips[tooltip]) then
		--		self:OnTooltipSetUnit(tooltip, ...)
		--	end
		--end)

	else

		for tooltip in next,tooltips do
			self:SecureHookScript(tooltip, "OnTooltipSetItem", "OnTooltipSetItem")
		--	self:SecureHookScript(GameTooltip, "OnTooltipSetUnit", "OnTooltipSetUnit")
		end

	end

	self:UpdateSettings()
end

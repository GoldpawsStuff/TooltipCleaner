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
local AceGUI = LibStub("AceGUI-3.0")

ns = LibStub("AceAddon-3.0"):NewAddon(ns, Addon, "LibMoreEvents-1.0", "AceConsole-3.0", "AceHook-3.0")
ns.callbacks = LibStub("CallbackHandler-1.0"):New(ns, nil, nil, false)
ns.Hider = CreateFrame("Frame"); ns.Hider:Hide()

_G[Addon] = ns

-- Lua API
local select = select
local string_format = string.format
local string_match = string.match

-- WoW Client Constants
-----------------------------------------------------------
local IsRetail = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)
local IsClassic = (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC)
local IsTBC = (WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC)
local IsWrath = (WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC)
local WoW10 = select(4,GetBuildInfo()) >= 100000

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
	hideBlizzadSellValue = true
}

ns.GetOptionsObject = function(self)
	if (not self.options) then
		self.options = {}
	end
	return self.options
end

ns.Fire = function(self, name, ...)
	self.callbacks:Fire(name, ...)
end

ns.UpdateSettings = function(self)
	if (self.db.hideBlizzadSellValue) then
		GameTooltip:SetScript("OnTooltipAddMoney", nil)
		GameTooltip_ClearMoney(GameTooltip)
	else
		GameTooltip:SetScript("OnTooltipAddMoney", GameTooltip_OnTooltipAddMoney)
	end
end

ns.OnTooltipSetItem = function(self, tooltip, data)
	if (not tooltip) or (tooltip:IsForbidden()) then return end

	local itemID

	if (tooltip.GetItem) then -- Some tooltips don't have this func. Example - compare tooltip
		local name, link = tooltip:GetItem()
		if (link) then
			itemID = string_format("|cFFCA3C3C%s|r %s", ID, (data and data.id) or string_match(link, ":(%w+)"))
		end
	else
		local id = data and data.id
		if (id) then
			itemID = string_format("|cFFCA3C3C%s|r %s", ID, id)
		end
	end

	if (itemID) then
		tooltip:AddLine(" ")
		tooltip:AddLine(itemID)
		tooltip:Show()
	end

end

ns.OnTooltipSetUnit = function(self, tooltip, data)
	if (not tooltip) or (tooltip:IsForbidden()) then return end

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

ns.OnInit = function(self)
	self.db = LibStub("AceDB-3.0"):New("TooltipCleaner_DB", defaults, true)

end

ns.OnEnable = function(self)

	local AddTooltipPostCall = TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
	if (AddTooltipPostCall) then
		local TooltipDataType = Enum.TooltipDataType
		AddTooltipPostCall(TooltipDataType.Spell, function(tooltip, ...) self:OnTooltipSetSpell(tooltip, ...) end)
		AddTooltipPostCall(TooltipDataType.Item, function(tooltip, ...) self:OnTooltipSetItem(tooltip, ...) end)
		AddTooltipPostCall(TooltipDataType.Unit, function(tooltip, ...) self:OnTooltipSetUnit(tooltip, ...) end)
	else
		self:SecureHookScript(GameTooltip, "OnTooltipSetItem", "OnTooltipSetItem")
		self:SecureHookScript(GameTooltip, "OnTooltipSetUnit", "OnTooltipSetUnit")
	end

	self:UpdateSettings()
end

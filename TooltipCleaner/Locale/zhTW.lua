local Addon, ns = ...

local L = LibStub("AceLocale-3.0"):NewLocale(Addon, "zhTW")
if (not L) then return end

L["Hide Blizzard vendor prices."] = "隱藏物品售價"
L["Hides vendors prices from default tooltip when enabled."] = "隱藏暴雪提供的物品售價"
L["Hide superflous item requirements."] = "隱藏物品條件"
L["Hides item requirements and equip criteria you have matched."] = "當你滿足物品的使用條件或裝備條件時，隱藏條件的說明文字"
L["Hide full durability."] = "隱藏完整的耐久度"
L["Hides item durability when the item has full durability."] = "當物品完好無損，隱藏耐久度。"
L["Hide grayed out item stats."] = "隱藏灰色屬性"
L["Hides grayed out item stats your character can't currently use."] = "隱藏角色目前的專精無法使用的灰色屬性"
L["Hide unachieved set bonuses."] = "隱藏未獲得的套裝效果"
L["Hides set bonuses you haven't collected enough items to receive yet."] = "隱藏未獲得的套裝效果"
L["Hide factions."] = "隱藏陣營"
L["Hides a unit's faction allegiance."] = "隱藏陣營"
L["Hide PvP status."] = "隱藏 PvP 狀態"
L["Hides a unit's PvP status."] "隱藏 PvP 狀態"
L["Hide unit health bars."] = "隱藏血條"
L["Hide level, race, class & spec"] = "隱藏等級、種族、職業和專精"
L["Hide guilds."] = "隱藏公會"
L["Hides health bars from units and objects."] = "隱藏指向目標或物件的血量條。"
L["Hides a unit's level, class, race and specialization."] = "隱藏指向目標的等級、職業、種族和專精。"
L["Hides a unit's guild name."] = "隱藏指向目標的公會名稱"

-- GearSetProtect: Locks items in ItemRack sets from being sold or destroyed

GearSetProtect = AceLibrary("AceAddon-2.0"):new("AceEvent-2.0", "AceHook-2.1")

-- Cache of protected item IDs for performance
GearSetProtect.ProtectedItems = {}

function GearSetProtect:OnInitialize()
    -- Addon initialized
end

function GearSetProtect:OnEnable()
    -- Create a separate tooltip frame for displaying set info
    self.extratip = CreateFrame("GameTooltip", "GearSetProtect_Tooltip", UIParent, "GameTooltipTemplate")
    self.extratip:SetFrameStrata("TOOLTIP")
    
    -- Track what item is on cursor for delete protection
    self.cursorItemID = nil
    
    -- Wait for ItemRack or Outfitter to load
    self:RegisterEvent("ADDON_LOADED")
end

function GearSetProtect:ADDON_LOADED()
    if IsAddOnLoaded("ItemRack") or IsAddOnLoaded("Outfitter") then
        self:UnregisterEvent("ADDON_LOADED")
        
        -- Update protected items cache
        self:UpdateProtectedItems()
        
        -- Hook ItemRack functions to update cache
        if ItemRack and ItemRack.SaveSet then
            self:Hook(ItemRack, "SaveSet", "UpdateProtectedItems", true)
        end
        if ItemRack and ItemRack.DeleteSet then
            self:Hook(ItemRack, "DeleteSet", "UpdateProtectedItems", true)
        end
        
        -- For Outfitter, register events to update cache (simpler than hooking)
        if IsAddOnLoaded("Outfitter") then
            self:RegisterEvent("PLAYER_REGEN_ENABLED") -- Exiting combat
            self:RegisterEvent("ZONE_CHANGED_NEW_AREA") -- Zone change
        end
        
        -- Hook selling and destroying
        self:Hook("UseContainerItem", true)
        self:Hook("PickupContainerItem", true)
        self:Hook("PickupInventoryItem", true)
        self:Hook("DeleteCursorItem", true)
        
        -- Hook tooltips
        self:HookTooltips()
        
        -- Show load message with detected addons
        local msg = "GearSetProtect loaded"
        if IsAddOnLoaded("ItemRack") and IsAddOnLoaded("Outfitter") then
            msg = msg .. " - Protecting ItemRack and Outfitter sets"
        elseif IsAddOnLoaded("ItemRack") then
            msg = msg .. " - Protecting ItemRack sets"
        elseif IsAddOnLoaded("Outfitter") then
            msg = msg .. " - Protecting Outfitter sets"
        end
        
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00" .. msg .. "|r")
        
        -- Schedule a delayed update to catch any sets that weren't loaded yet
        -- This ensures protection works immediately after /reload
        self:ScheduleEvent("GearSetProtect_DelayedUpdate", self.UpdateProtectedItems, 2, self)
    end
end

-- Event: Update cache when exiting combat (for Outfitter users)
function GearSetProtect:PLAYER_REGEN_ENABLED()
    self:UpdateProtectedItems()
end

-- Event: Update cache when changing zones (for Outfitter users)
function GearSetProtect:ZONE_CHANGED_NEW_AREA()
    self:UpdateProtectedItems()
end

-- Build cache of all items in ItemRack and Outfitter sets
function GearSetProtect:UpdateProtectedItems()
    local success, errorMsg = pcall(function()
        local oldCount = 0
        for _ in pairs(self.ProtectedItems) do
            oldCount = oldCount + 1
        end
        
        self.ProtectedItems = {}
        
        local count = 0
        local setCount = 0
        
        -- Read ItemRack sets
        if IsAddOnLoaded("ItemRack") then
            local userData = Rack_User or ItemRack_Users
            
            if userData then
                local user = UnitName("player") .. " of " .. GetCVar("realmName")
                
                if userData[user] and userData[user].Sets then
                    for setName, setData in pairs(userData[user].Sets) do
                        if not string.find(setName, "^ItemRack%-") and not string.find(setName, "^Rack%-") then
                            setCount = setCount + 1
                            
                            for slot = 0, 19 do
                                local itemData = setData[slot]
                                if itemData and type(itemData) == "table" then
                                    local itemID = itemData.id
                                    
                                    if itemID and itemID ~= 0 then
                                        if type(itemID) == "string" then
                                            local _, _, extractedID = string.find(itemID, "^(%d+)")
                                            itemID = tonumber(extractedID)
                                        end
                                        
                                        if itemID and itemID > 0 then
                                            if not self.ProtectedItems[itemID] then
                                                count = count + 1
                                            end
                                            self.ProtectedItems[itemID] = true
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        
        -- Read Outfitter sets
        if IsAddOnLoaded("Outfitter") and gOutfitter_Settings and gOutfitter_Settings.Outfits then
            for cat, outfits in pairs(gOutfitter_Settings.Outfits) do
                if table.getn(outfits) > 0 then
                    for _, outfit in ipairs(outfits) do
                        if outfit.Items then
                            local hasItems = false
                            
                            for slot, item in pairs(outfit.Items) do
                                local itemID = tonumber(item.Code)
                                
                                if itemID and itemID > 0 then
                                    hasItems = true
                                    if not self.ProtectedItems[itemID] then
                                        count = count + 1
                                    end
                                    self.ProtectedItems[itemID] = true
                                end
                            end
                            
                            -- Only count outfit if it had items
                            if hasItems then
                                setCount = setCount + 1
                            end
                        end
                    end
                end
            end
        end
        
        -- Show message if count changed
        if count ~= oldCount then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Set Change Detected - Protecting " .. count .. " items|r")
        end
    end)
    
    if not success then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000GearSetProtect: Error updating protection - " .. tostring(errorMsg) .. "|r")
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Please report this error. Protection may not be working correctly.|r")
    end
end

-- Get which sets an item belongs to (from both ItemRack and Outfitter)
function GearSetProtect:GetItemSets(itemID)
    if not itemID then return nil end
    
    local success, result = pcall(function()
        local sets = {}
        
        -- Check ItemRack sets
        if IsAddOnLoaded("ItemRack") then
            local userData = Rack_User or ItemRack_Users
            
            if userData then
                local user = UnitName("player") .. " of " .. GetCVar("realmName")
                
                if userData[user] and userData[user].Sets then
                    for setName, setData in pairs(userData[user].Sets) do
                        if not string.find(setName, "^ItemRack%-") and not string.find(setName, "^Rack%-") then
                            for slot = 0, 19 do
                                local itemData = setData[slot]
                                if itemData and type(itemData) == "table" then
                                    local setItemID = itemData.id
                                    
                                    if setItemID and setItemID ~= 0 then
                                        if type(setItemID) == "string" then
                                            local _, _, extractedID = string.find(setItemID, "^(%d+)")
                                            setItemID = tonumber(extractedID)
                                        end
                                        
                                        if setItemID == itemID then
                                            table.insert(sets, setName)
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        
        -- Check Outfitter sets
        if IsAddOnLoaded("Outfitter") and gOutfitter_Settings and gOutfitter_Settings.Outfits then
            for cat, outfits in pairs(gOutfitter_Settings.Outfits) do
                if table.getn(outfits) > 0 then
                    for _, outfit in ipairs(outfits) do
                        if outfit.Items then
                            for slot, item in pairs(outfit.Items) do
                                local setItemID = tonumber(item.Code)
                                
                                if setItemID == itemID then
                                    table.insert(sets, outfit.Name)
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
        
        if table.getn(sets) > 0 then
            return sets
        end
        return nil
    end)
    
    if success then
        return result
    else
        -- Silently fail for tooltips to avoid spam
        return nil
    end
end

-- Hook: Prevent selling protected items
function GearSetProtect:UseContainerItem(bag, slot, onSelf, reagentBankOpen)
    -- Check if merchant frame is open (selling)
    if MerchantFrame:IsVisible() then
        local itemLink = GetContainerItemLink(bag, slot)
        if itemLink then
            local _, _, itemID = string.find(itemLink, "item:(%d+)")
            itemID = tonumber(itemID)
            
            if itemID and self.ProtectedItems[itemID] then
                UIErrorsFrame:AddMessage("Item is protected by gear set!", 1.0, 0.1, 0.1, 1.0, UIERRORS_HOLD_TIME)
                return
            end
        end
    end
    
    -- Call original function
    self.hooks.UseContainerItem(bag, slot, onSelf, reagentBankOpen)
end

-- Hook: Track what item is picked up from bags
function GearSetProtect:PickupContainerItem(bag, slot)
    local itemLink = GetContainerItemLink(bag, slot)
    if itemLink then
        local _, _, itemID = string.find(itemLink, "item:(%d+)")
        self.cursorItemID = tonumber(itemID)
    else
        self.cursorItemID = nil
    end
    
    self.hooks.PickupContainerItem(bag, slot)
end

-- Hook: Track what item is picked up from equipped slots
function GearSetProtect:PickupInventoryItem(slot)
    local itemLink = GetInventoryItemLink("player", slot)
    if itemLink then
        local _, _, itemID = string.find(itemLink, "item:(%d+)")
        self.cursorItemID = tonumber(itemID)
    else
        self.cursorItemID = nil
    end
    
    self.hooks.PickupInventoryItem(slot)
end

-- Hook: Prevent destroying protected items
function GearSetProtect:DeleteCursorItem()
    if self.cursorItemID and self.ProtectedItems[self.cursorItemID] then
        UIErrorsFrame:AddMessage("Item is protected by gear set!", 1.0, 0.1, 0.1, 1.0, UIERRORS_HOLD_TIME)
        self.cursorItemID = nil
        return
    end
    
    self.hooks.DeleteCursorItem()
    self.cursorItemID = nil
end

-- Hook tooltips to show set information
function GearSetProtect:HookTooltips()
    -- Hook GameTooltip SetBagItem for bag items
    self:SecureHook(GameTooltip, "SetBagItem", function(this, bag, slot)
        local itemLink = GetContainerItemLink(bag, slot)
        if itemLink then
            GearSetProtect:AddSetsToTooltip(GameTooltip, itemLink)
        else
            if GearSetProtect.extratip:IsVisible() then
                GearSetProtect.extratip:Hide()
            end
        end
    end)
    
    -- Hook GameTooltip SetInventoryItem for equipped items
    self:SecureHook(GameTooltip, "SetInventoryItem", function(this, unit, slot)
        local itemLink = GetInventoryItemLink(unit, slot)
        if itemLink then
            GearSetProtect:AddSetsToTooltip(GameTooltip, itemLink)
        else
            if GearSetProtect.extratip:IsVisible() then
                GearSetProtect.extratip:Hide()
            end
        end
    end)
    
    -- Hook GameTooltip SetLootItem for loot
    self:SecureHook(GameTooltip, "SetLootItem", function(this, slot)
        local itemLink = GetLootSlotLink(slot)
        if itemLink then
            GearSetProtect:AddSetsToTooltip(GameTooltip, itemLink)
        else
            if GearSetProtect.extratip:IsVisible() then
                GearSetProtect.extratip:Hide()
            end
        end
    end)
    
    -- Hook GameTooltip SetMerchantItem for vendor items
    self:SecureHook(GameTooltip, "SetMerchantItem", function(this, id)
        local itemLink = GetMerchantItemLink(id)
        if itemLink then
            GearSetProtect:AddSetsToTooltip(GameTooltip, itemLink)
        else
            if GearSetProtect.extratip:IsVisible() then
                GearSetProtect.extratip:Hide()
            end
        end
    end)
    
    -- Hook OnHide to hide our extra tooltip
    self:HookScript(GameTooltip, "OnHide", function()
        if GearSetProtect.extratip:IsVisible() then
            GearSetProtect.extratip:Hide()
        end
    end)
end

-- Add set information to separate tooltip
function GearSetProtect:AddSetsToTooltip(tooltip, itemLink)
    -- Always check if we should hide the tooltip first
    if not itemLink then
        if self.extratip:IsVisible() then
            self.extratip:Hide()
        end
        return
    end
    
    local _, _, itemID = string.find(itemLink, "item:(%d+)")
    itemID = tonumber(itemID)
    
    if not itemID then
        if self.extratip:IsVisible() then
            self.extratip:Hide()
        end
        return
    end
    
    local sets = self:GetItemSets(itemID)
    if sets then
        -- Clear and position our separate tooltip
        self.extratip:ClearLines()
        self.extratip:SetOwner(tooltip, "ANCHOR_NONE")
        
        -- Add set information - limit to 3 sets
        local totalSets = table.getn(sets)
        local displayCount = math.min(3, totalSets)
        
        self.extratip:AddLine("Set:", 1.0, 0.82, 0)
        for i = 1, displayCount do
            self.extratip:AddLine(sets[i], 0.7, 0.7, 1.0)
        end
        
        -- If there are more than 3, show count
        if totalSets > 3 then
            self.extratip:AddLine("+" .. (totalSets - 3) .. " more...", 0.5, 0.5, 0.5)
        end
        
        -- Force tooltip to render so we can get its height
        self.extratip:Show()
        
        -- Get the main tooltip position and our tooltip height
        local tooltipTop = tooltip:GetTop()
        local extratipHeight = self.extratip:GetHeight()
        local screenHeight = UIParent:GetHeight()
        
        -- Check if there's enough room above the main tooltip
        local roomAbove = tooltipTop and (tooltipTop + extratipHeight < screenHeight)
        
        if roomAbove then
            -- Place above (current behavior)
            self.extratip:ClearAllPoints()
            self.extratip:SetPoint("BOTTOMLEFT", tooltip, "TOPLEFT", 0, 0)
        else
            -- Place below
            self.extratip:ClearAllPoints()
            self.extratip:SetPoint("TOPLEFT", tooltip, "BOTTOMLEFT", 0, 0)
        end
        
        self.extratip:Show()
    else
        -- Hide if item is not in any sets
        if self.extratip:IsVisible() then
            self.extratip:Hide()
        end
    end
end

-- Slash commands
SLASH_GEARSETPROTECT1 = "/gsp"
SLASH_GEARSETPROTECT2 = "/gearsetprotect"
SlashCmdList["GEARSETPROTECT"] = function(msg)
    msg = string.lower(msg or "")
    
    if msg == "update" or msg == "refresh" then
        GearSetProtect:UpdateProtectedItems()
    elseif msg == "count" then
        local count = 0
        for _ in pairs(GearSetProtect.ProtectedItems) do
            count = count + 1
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00GearSetProtect is protecting " .. count .. " unique items.|r")
    elseif msg == "list" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Protected Item IDs:|r")
        for itemID, _ in pairs(GearSetProtect.ProtectedItems) do
            DEFAULT_CHAT_FRAME:AddMessage("  ItemID: " .. itemID)
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00GearSetProtect commands:|r")
        DEFAULT_CHAT_FRAME:AddMessage("/gsp update - Refresh protected items cache")
        DEFAULT_CHAT_FRAME:AddMessage("/gsp count - Show how many items are protected")
        DEFAULT_CHAT_FRAME:AddMessage("/gsp list - List all protected item IDs")
    end
end

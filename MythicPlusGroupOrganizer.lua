-- MythicPlusGroupOrganizer.lua
local addonName, addonTable = ...

-- C_GuildInfo = C_GuildInfo
-- IsInGuild = IsInGuild
-- CreateFrame = CreateFrame
-- GetNumGuildMembers = GetNumGuildMembers
-- GetGuildRosterInfo = GetGuildRosterInfo
-- GetMaxLevelForExpansionLevel = GetMaxLevelForExpansionLevel
-- GetExpansionLevel = GetExpansionLevel
RaiderIO = RaiderIO

-- configs
local MPGOIsDebugMode = true
local MPGODebugLevels = {
    Info = 0,
    Warning = 1,
    Error = 2,
    Critical = 3
}
local MPGODebugLevel = MPGODebugLevels.Info
local horizontalMargin = 10

MPGOColorsQuality = {
    Poor = { red = 0.6157, green = 0.6157, blue = 0.6157 }, -- Gray
    Common = { red = 1, green = 1, blue = 1 },              -- White
    Uncommon = { red = 0.1176, green = 1, blue = 0 },       -- Green
    Rare = { red = 0, green = 0.4392, blue = 0.8667 },      -- Blue
    Epic = { red = 0.6392, green = 0.2078, blue = 0.9333 }, -- Purple
    Legendary = { red = 1, green = 0.502, blue = 0 },       -- Orange
}

MPGOColorsClasses = {
    ["Warrior"] = { red = 0.78, green = 0.61, blue = 0.43 },
    ["Paladin"] = { red = 0.96, green = 0.55, blue = 0.73 },
    ["Hunter"] = { red = 0.67, green = 0.83, blue = 0.45 },
    ["Rogue"] = { red = 1.00, green = 0.96, blue = 0.41 },
    ["Priest"] = { red = 1.00, green = 1.00, blue = 1.00 },
    ["Death Knight"] = { red = 0.77, green = 0.12, blue = 0.23 },
    ["Shaman"] = { red = 0.00, green = 0.44, blue = 0.87 },
    ["Mage"] = { red = 0.41, green = 0.80, blue = 0.94 },
    ["Warlock"] = { red = 0.58, green = 0.51, blue = 0.79 },
    ["Monk"] = { red = 0.00, green = 1.00, blue = 0.59 },
    ["Druid"] = { red = 1.00, green = 0.49, blue = 0.04 },
    ["Demon Hunter"] = { red = 0.64, green = 0.19, blue = 0.79 },
    ["Evoker"] = { red = 0.20, green = 0.58, blue = 0.50 }
}

-- Event frame to handle addon loading
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("GUILD_ROSTER_UPDATE")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        MPGODebug(addonName .. " loaded!", MPGODebugLevels.Info)
        -- Initialize your addon here
        InitializeFrames()
        RegisterSlashCommand()
        ShowFrame()
    elseif event == "PLAYER_LOGIN" then
        if IsInGuild() then
            C_GuildInfo.GuildRoster() -- Request guild roster update
        end
    elseif event == "GUILD_ROSTER_UPDATE" then
        PopulateGuildmembersList()
    end
end)

-- InitializeFrames: Sets up the initial frames for the addon, including the main frame, guildmates list frame, and groups frame.
-- Ensures there is always an empty row at the bottom of the groups frame.
function InitializeFrames()
    local frame = _G["MythicPlusGroupOrganizerFrame"]
    if frame then
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            tile = true,
            tileSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:SetResizable(true) -- Make the frame resizable
        -- frame:SetMinResize(600, 400) -- Set minimum resize dimensions (removed)

        -- Create a resize handle in the bottom-right corner
        local resizeHandle = CreateFrame("Frame", "MPGOResizeHandle", frame, "BackdropTemplate")
        resizeHandle:SetSize(16, 16)
        resizeHandle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
        resizeHandle:EnableMouse(true)
        resizeHandle:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then
                frame:StartSizing("BOTTOMRIGHT")
            end
        end)
        resizeHandle:SetScript("OnMouseUp", function(self, button)
            frame:StopMovingOrSizing()
            AdjustGuildmatesListFrameSize()
        end)
        resizeHandle:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up",
            edgeFile = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })

        -- Add key binding to close the window when the escape key is pressed
        frame:SetPropagateKeyboardInput(true)
        frame:SetScript("OnKeyDown", function(self, key)
            if key == "ESCAPE" then
                self:Hide()
            else
                self:SetPropagateKeyboardInput(true)
            end
        end)
    end

    local guildmatesListFrame = _G["GuildmatesListFrame"]
    if guildmatesListFrame then
        -- guildmatesListFrame:SetBackdrop({
        --     bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        --     tile = true, tileSize = 32,
        --     insets = { left = 11, right = 12, top = 12, bottom = 11 }
        -- })

        -- Create ScrollFrame and ScrollChild
        local scrollFrame = CreateFrame("ScrollFrame", "GuildmatesScrollFrame", guildmatesListFrame,
            "UIPanelScrollFrameTemplate")
        scrollFrame:SetSize(180, 280)
        scrollFrame:SetPoint("TOPLEFT", 10, -10)

        local scrollChild = CreateFrame("Frame", "GuildmatesScrollChildFrame", scrollFrame)
        scrollChild:SetSize(180, guildmatesListFrame:GetHeight() - 20)
        scrollFrame:SetScrollChild(scrollChild)
    end

    local mpgogroupsFrame = _G["MPGOGroupsFrame"]
    if mpgogroupsFrame then
        -- mpgogroupsFrame:SetBackdrop({
        --     bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        --     tile = true, tileSize = 32,
        --     insets = { left = 11, right = 12, top = 12, bottom = 11 }
        -- })
        CreateNewRowOfMPGOGroups() -- Ensure there is always an empty row at the bottom
    end

    local placeholderButtonsFrame = _G["PlaceholderButtonsFrame"]
    if placeholderButtonsFrame then
        placeholderButtonsFrame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            tile = true,
            tileSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })

        local announceButton = _G["MPGOAnnounceButton"]
        local button2 = _G["PlaceholderButton2"]
        local button3 = _G["PlaceholderButton3"]

        if announceButton then
            announceButton:SetScript("OnClick", function()
                MPGODebug("Announce clicked", MPGODebugLevels.Info)
                MPGOPrintGroupMembers()
            end)
        end
        button2:SetText(MPGOIsDebugMode and "Disable Debug Mode" or "Enable Debug Mode")

        if button2 then
            button2:SetScript("OnClick", function()
                MPGOIsDebugMode = not MPGOIsDebugMode
                button2:SetText(MPGOIsDebugMode and "Disable Debug Mode" or "Enable Debug Mode")
                MPGODebug("Debug mode " .. (MPGOIsDebugMode and "enabled" or "disabled"), MPGODebugLevels.Critical)
            end)
        end

        if button3 then
            button3:SetScript("OnClick", function()
                MPGODebug("Reset All clicked", MPGODebugLevels.Info)
                ResetGuildMemberFrames()
            end)
        end
    end
end

function AdjustGuildmatesListFrameSize()
    local frame = _G["MythicPlusGroupOrganizerFrame"]
    local guildmatesListFrame = _G["GuildmatesListFrame"]
    local guildmatesScrollFrame = _G["GuildmatesScrollFrame"]
    local mpgogroupsFrame = _G["MPGOGroupsFrame"]
    if frame and guildmatesListFrame and mpgogroupsFrame and guildmatesScrollFrame then
        local frameHeight = frame:GetHeight()
        local frameWidth = frame:GetWidth()
        guildmatesListFrame:SetHeight(frameHeight - 20)                                             -- Maintain a vertical offset of 10 from the top and bottom
        guildmatesScrollFrame:SetHeight(guildmatesListFrame:GetHeight() - 20)
        mpgogroupsFrame:SetSize(frameWidth - guildmatesListFrame:GetWidth() - 30, frameHeight - 20) -- Maintain a padding of 10

        -- Adjust the size of each row and contained guild member frames
        for i = 1, mpgogroupsFrame:GetNumChildren() do
            local row = select(i, mpgogroupsFrame:GetChildren())
            row:SetWidth(mpgogroupsFrame:GetWidth() - 20) -- Set row width with a margin of 10 on each side
            for j = 1, row:GetNumChildren() do
                local guildmemberFrame = select(j, row:GetChildren())
                local left = (row:GetWidth() * 0.2) - (horizontalMargin * 0.5)                     -- Set width to 20% of row width
                guildmemberFrame:SetWidth(left)                                                    -- Set guild member frame width to 20% of row width
                guildmemberFrame:SetPoint("LEFT", row, "LEFT", left * (j - 1) + horizontalMargin, 0) -- Align guild member frame to the left of the row
            end
        end
    end
end

-- MythicPlusGroupOrganizerFrame_OnMouseDown: Starts moving the frame when the left mouse button is pressed.
function MythicPlusGroupOrganizerFrame_OnMouseDown(self, button)
    if button == "LeftButton" then
        self:StartMoving()
    end
end

-- MythicPlusGroupOrganizerFrame_OnMouseUp: Stops moving the frame when the left mouse button is released.
function MythicPlusGroupOrganizerFrame_OnMouseUp(self, button)
    if button == "LeftButton" then
        self:StopMovingOrSizing()
    end
end

-- PopulateGuildmatesList: Populates the guildmates list with online guild members at max level who are not already in a group or attached to a row group slot frame.
-- Clears previous entries, sorts guildmates alphabetically and by role (TANK, HEALER, DPS), and creates new frames for each eligible guildmate.
function PopulateGuildmembersList()
    local scrollChild = _G["GuildmatesScrollChildFrame"]

    -- Check if the scroll child exists or if a frame is being dragged then do not populate the list
    if not scrollChild or addonTable.draggedFrame then
        MPGODebug("Scroll child does not exist or a frame is being dragged, skipping population", MPGODebugLevels.Warning)
        return
    end
    if _G["MythicPlusGroupOrganizerFrame"]:IsShown() then
        MPGODebug("Populating guildmates list", MPGODebugLevels.Info)
    end
    -- Clear previous children
    for i = 1, scrollChild:GetNumChildren() do
        local child = select(i, scrollChild:GetChildren())
        child:Hide()
    end

    local numGuildMembers = GetNumGuildMembers()
    local maxLevel = GetMaxPlayerLevel()
    local guildmates = {}

    for i = 1, numGuildMembers do
        local name, _, _, level, class, _, _, _, online = GetGuildRosterInfo(i)
        if online and level == maxLevel and not IsPlayerInMPGOGroups(name) then
            local role = GetPlayerRole(name)
            MPGODebug(name .. " is a " .. role, MPGODebugLevels.Info)
            table.insert(guildmates, { name = name, role = role, class = class })
        end
    end

    -- Sort guildmates first alphabetically, then by role (TANK, HEALER, DPS)
    table.sort(guildmates, function(a, b)
        if a.role == b.role then
            return a.name < b.name
        else
            local roleOrder = { TANK = 1, HEALER = 2, DPS = 3 }
            return roleOrder[a.role] < roleOrder[b.role]
        end
    end)

    local roleIcons = {
        TANK = "Interface\\Addons\\Mythic Plus Group Organizer\\textures\\UI-LFG-ICON-PORTRAITROLES-CROPPED",
        HEALER = "Interface\\Addons\\Mythic Plus Group Organizer\\textures\\UI-LFG-ICON-PORTRAITROLES-CROPPED",
        DPS = "Interface\\Addons\\Mythic Plus Group Organizer\\textures\\UI-LFG-ICON-PORTRAITROLES-CROPPED"
    }

    local roleCoords = {
        TANK = { 0, 0.5, 0.5, 1 },
        HEALER = { 0.5, 1, 0, 0.5 },
        DPS = { 0.5, 1, 0.5, 1 }
    }

    local index = 1
    for _, guildmateInfo in ipairs(guildmates) do
        local guildmate = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
        local guildmadeFrameHeight = 20
        local guildmadeFrameOpacity = 0.5
        guildmate:SetSize(scrollChild:GetWidth() - 20, guildmadeFrameHeight)
        guildmate:SetPoint("TOPLEFT", 10, -1 * (guildmadeFrameHeight + 5) * (index - 1))
        -- guildmate:SetBackdrop({
        --     edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        --     tile = true, tileSize = 16, edgeSize = 16,
        --     insets = { left = 4, right = 4, top = 4, bottom = 4 }
        -- })
        guildmate.texture = guildmate:CreateTexture()
        guildmate.texture:SetAllPoints()
        guildmate.mythicPlusRating = GetPlayerMythicPlusRating(guildmateInfo.name)
        local useClassAsBackground = true
        local classColor = MPGOColorsClasses[guildmateInfo.class]
        local qualityColor = MPGOGetPlayerIOColor(guildmate.mythicPlusRating)
        local backgroundColor = useClassAsBackground and classColor or qualityColor
        local scoreColor = useClassAsBackground and qualityColor or classColor

        guildmate.texture:SetColorTexture(backgroundColor.red, backgroundColor.green, backgroundColor.blue, guildmadeFrameOpacity) -- Set black background with 50% opacity

        local roleIcon = guildmate:CreateTexture(nil, "OVERLAY")
        roleIcon:SetSize(20, 20)
        -- roleIcon:SetAllPoints()
        roleIcon:SetPoint("LEFT", guildmate, "LEFT", 3, 0)
        roleIcon:SetTexture(roleIcons[guildmateInfo.role])
        roleIcon:SetTexCoord(unpack(roleCoords[guildmateInfo.role]))
        roleIcon:Show()

        guildmate.text = guildmate:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        guildmate.text:SetPoint("LEFT", roleIcon, "RIGHT", 5, 0)
        guildmate.text:SetText(guildmateInfo.name)
        guildmate.text:SetTextColor(1, 1, 1) -- Set text color to white

        guildmate.score = guildmate:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        guildmate.score:SetPoint("RIGHT", guildmate, "RIGHT", -5, 0)
        guildmate.score:SetText(tostring(guildmate.mythicPlusRating))
        
        guildmate.score:SetTextColor(scoreColor.red, scoreColor.green, scoreColor.blue) -- Set text color to match background color
        guildmate:EnableMouse(true)
        guildmate:SetMovable(true)
        guildmate:RegisterForDrag("LeftButton")
        guildmate.originalPoint = { guildmate:GetPoint() }
        guildmate.originalParent = guildmate:GetParent() -- Store the original parent
        guildmate:SetScript("OnDragStart", function(self)
            self:StartMoving()
            self:SetParent(UIParent)                         -- Change parent to UIParent to make it visible everywhere
            self.originalFrameStrata = self:GetFrameStrata() -- Store the original frame strata
            self:SetFrameStrata("HIGH")                      -- Set frame strata to HIGH to appear on top
            addonTable.draggedFrame = self                   -- Store the dragged frame in the addonTable
            MPGODebug("Drag started for " .. self.text:GetText(), MPGODebugLevels.Info)
        end)
        guildmate:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            local isValidDropTarget, dropTarget = CheckDropTarget(self)
            if isValidDropTarget and dropTarget then
                self:ClearAllPoints()
                local numChildren = dropTarget:GetNumChildren()
                local totalWidth = dropTarget:GetWidth() - (horizontalMargin * 2)
                local widthForChild = totalWidth * 0.2 -- Set width to 20% of row width
                if numChildren == 0 then
                    self:SetPoint("LEFT", dropTarget, "LEFT", horizontalMargin, 0)
                    MPGODebug("First child in row, setting left to " .. horizontalMargin, MPGODebugLevels.Info)
                    CreateNewRowOfMPGOGroups() -- Create a new row since we always want an empty row
                elseif numChildren < 5 then
                    local left = (numChildren * widthForChild) + horizontalMargin
                    MPGODebug("Setting left to " .. left .. " numChildren: " .. numChildren, MPGODebugLevels.Info)
                    self:SetPoint("LEFT", dropTarget, "LEFT", left, 0)
                elseif numChildren == 5 then
                    -- here we will reject the move and put it back in the guildmember list
                    MPGODebug("Row is full, rejecting move", MPGODebugLevels.Warning)
                end
                self:SetWidth(widthForChild) -- Set guild member frame width to 20% of row width
                self:SetParent(dropTarget)
                self:Show()
                C_GuildInfo.GuildRoster()
                MPGODebug("Dropped on row " .. dropTarget:GetID(),MPGODebugLevels.Info)
            else
                self:SetParent(self.originalParent) -- Revert to original parent if not dropped on a group slot
                self:ClearAllPoints()
                self:SetPoint(unpack(self.originalPoint))
            end
            self:SetFrameStrata(self.originalFrameStrata)
            addonTable.draggedFrame = nil -- Clear the dragged frame
            MPGODebug("Drag stopped for " .. self.text:GetText(), MPGODebugLevels.Info)
        end)
        guildmate.role = guildmateInfo.role -- Attach the role as a data attribute
        index = index + 1
    end
end

-- IsPlayerInMPGOGroups: Checks if a player is already in one of the group row.
-- Returns true if the player is found, false otherwise.
function IsPlayerInMPGOGroups(playerName)
    local mpgogroupsFrame = _G["MPGOGroupsFrame"]
    if not mpgogroupsFrame then return false end

    for i = 1, mpgogroupsFrame:GetNumChildren() do
        local row = select(i, mpgogroupsFrame:GetChildren())
        for j = 1, row:GetNumChildren() do
            local guildmemberFrame = select(j, row:GetChildren())
            if guildmemberFrame.text:GetText() == playerName then
                return true
            end
        end
    end
    return false
end

-- CheckDropTarget: Checks if the frame is being dropped over a valid group slot.
-- If so, attaches the frame to the slot and returns true. Otherwise, returns false.
function CheckDropTarget(guildmemberFrame)
    local mpgogroupsFrame = _G["MPGOGroupsFrame"]
    if mpgogroupsFrame then
        for i = 1, mpgogroupsFrame:GetNumChildren() do
            local row = select(i, mpgogroupsFrame:GetChildren())
            if MouseIsOver(row) then
                MPGODebug("Mouse is over row " .. i, MPGODebugLevels.Info)
                return true, row
            end
        end
    end
    MPGODebug("No valid drop target found", MPGODebugLevels.Warning)
    return false, nil
end

-- MoveToMPGOGroupsFrame: Moves the frame to the next available group slot.
-- If no slots are available, creates a new row of slots and moves the frame to the first slot of the new row.
function MoveToMPGOGroupsFrame(frame)
    local mpgogroupsFrame = _G["MPGOGroupsFrame"]
    if not mpgogroupsFrame then return end

    local slotFound = false
    for i = 1, mpgogroupsFrame:GetNumChildren() do
        local row = select(i, mpgogroupsFrame:GetChildren())
        if row:GetNumChildren() < 5 then
            frame:SetParent(row)
            frame:ClearAllPoints()
            frame:SetPoint("CENTER")
            slotFound = true
            break
        end
    end

    if not slotFound then
        CreateNewRowOfMPGOGroups()
        local newRow = select(mpgogroupsFrame:GetNumChildren(), mpgogroupsFrame:GetChildren())
        frame:SetParent(newRow)
        frame:ClearAllPoints()
        frame:SetPoint("CENTER")
    end
end

-- CreateNewRowOfMPGOGroups: Creates a new row of group slots.
-- Each row contains 5 slots, and the row is positioned below the previous row.
function CreateNewRowOfMPGOGroups()
    local mpgogroupsFrame = _G["MPGOGroupsFrame"]
    if not mpgogroupsFrame then return end

    -- Check if there are any rows with zero children
    for i = 1, mpgogroupsFrame:GetNumChildren() do
        local row = select(i, mpgogroupsFrame:GetChildren())
        if row:GetNumChildren() == 0 then
            return -- Exit the function if a row with zero children is found
        end
    end

    local numRows = mpgogroupsFrame:GetNumChildren()
    local rowNumber = numRows + 1

    local newRow = CreateFrame("Frame", "Row" .. rowNumber, mpgogroupsFrame, "BackdropTemplate")
    MPGODebug("Created row " .. rowNumber, MPGODebugLevels.Warning)
    newRow:SetSize(mpgogroupsFrame:GetWidth() - 20, 50) -- Adjust width to match MPGOGroupsFrame width with 10 margin on each side
    if rowNumber == 1 then
        newRow:SetPoint("TOPLEFT", mpgogroupsFrame, "TOPLEFT", 10, -10)                -- Start at the top with an offset of 10
    else
        newRow:SetPoint("TOPLEFT", _G["Row" .. (rowNumber - 1)], "BOTTOMLEFT", 0, -10) -- Position below the previous row with an offset of 10
    end
    newRow:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        tile = true,
        tileSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    newRow:Show()
end

-- MPGOPrintGroupMembers: Iterates over the group rows and prints the names of each guild member in that row.
function MPGOPrintGroupMembers()
    local mpgogroupsFrame = _G["MPGOGroupsFrame"]
    if not mpgogroupsFrame then return end

    for i = 1, mpgogroupsFrame:GetNumChildren() do
        local row = select(i, mpgogroupsFrame:GetChildren())
        local numChildren = row:GetNumChildren()
        if numChildren == 0 then
            break
        end

        local groupText = "Group " .. i .. ":"
        for j = 1, numChildren do
            local guildmemberFrame = select(j, row:GetChildren())
            groupText = groupText .. "  " .. guildmemberFrame.text:GetText()
        end
        MPGODebug(groupText, MPGODebugLevels.Info)
        -- SendChatMessage(groupText, "GUILD")
    end
end

-- RegisterSlashCommand: Registers a slash command to show or hide the main frame.
function RegisterSlashCommand()
    SLASH_MYTHICPLUSGROUPORGANIZER1 = "/mpgo"
    SlashCmdList["MYTHICPLUSGROUPORGANIZER"] = function(msg)
        local frame = _G["MythicPlusGroupOrganizerFrame"]
        if frame then
            if frame:IsShown() then
                frame:Hide()
            else
                frame:Show()
            end
        end
    end
end

-- ShowFrame: Shows the main frame.
function ShowFrame()
    local frame = _G["MythicPlusGroupOrganizerFrame"]
    if frame then
        frame:Show()
    end
end

-- GetMaxPlayerLevel: Returns the maximum player level for the current expansion.
function GetMaxPlayerLevel()
    return GetMaxLevelForExpansionLevel(GetExpansionLevel())
end

-- GetPlayerRole: Returns the player's role based on their class and specialization.
function GetPlayerRole(playerName)
    -- Implement logic to determine the player's role (e.g., Tank, Healer, DPS)
    -- This is a placeholder implementation and should be replaced with actual logic
    return GetPlayerMythicPlusRole(playerName)
end

-- GetPlayerMythicPlusRating: Retrieves the player's Mythic Plus rating from the RaiderIO addon.
function GetPlayerMythicPlusRating(playerNameAndRealm)
    if not RaiderIO then
        MPGODebug("RaiderIO addon is not installed.", MPGODebugLevels.Warning)
        return 0
    end

    local playerName, realm = strsplit("-", playerNameAndRealm)
    MPGODebug("Getting RaiderIO score for " .. playerName .. " on realm " .. realm, MPGODebugLevels.Info)

    local profile = RaiderIO.GetProfile(playerName, realm)
    if profile then
        local score = profile.mythicKeystoneProfile.currentScore
        MPGODebug("Score for " .. playerName .. ": " .. score, MPGODebugLevels.Info)
        return score or 0
    else
        MPGODebug("No RaiderIO profile found for " .. playerName, MPGODebugLevels.Warning)
        return 0
    end
end

function GetPlayerMythicPlusRole(playerNameAndRealm)
    if not RaiderIO then
        MPGODebug("RaiderIO addon is not installed.", MPGODebugLevels.Warning)
        return "DPS"
    end

    local playerName, realm = strsplit("-", playerNameAndRealm)
    MPGODebug("Getting RaiderIO role for " .. playerName .. " on realm " .. realm, MPGODebugLevels.Info)

    local profile = RaiderIO.GetProfile(playerName, realm)
    if profile and profile.mythicKeystoneProfile and profile.mythicKeystoneProfile.mplusCurrent and profile.mythicKeystoneProfile.mplusCurrent.roles and profile.mythicKeystoneProfile.mplusCurrent.roles[1] then
        local role = string.upper(profile.mythicKeystoneProfile.mplusCurrent.roles[1][1]) or "DPS"
        MPGODebug("Role for " .. playerName .. ": " .. role, MPGODebugLevels.Info)
        return role
    else
        MPGODebug("No RaiderIO profile found for " .. playerName, MPGODebugLevels.Warning)
        return "DPS"
    end
end

function MPGOLerpColors(amount, color1, color2)
    local red = MPGOLerpColor(amount, color1.red, color2.red)
    local green = MPGOLerpColor(amount, color1.green, color2.green)
    local blue = MPGOLerpColor(amount, color1.blue, color2.blue)
    return { red = red, green = green, blue = blue }
end

function MPGOLerpColor(amount, color1, color2)
    return Round(Lerp(color1, color2, amount), 2)
end

function Lerp(v0, v1, t)
    return v0 + (v1 - v0) * t
end

function Round(num, numDecimalPlaces)
    local mult = 10 ^ (numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

function MPGOGetPlayerIOColor(io)
    local amount = (io % 500) / 500
    local startColor = MPGOGetQualityColorByIO(io)
    local endColor = MPGOGetQualityColorByIO(io + 501)
    return MPGOLerpColors(amount, startColor, endColor)
end

function MPGOGetQualityColorByIO(io)
    local color = MPGOColorsQuality["Poor"]
    io = tonumber(io)
    if io >= 2500 then
        color = MPGOColorsQuality["Legendary"]
    elseif io >= 2000 then
        color = MPGOColorsQuality["Epic"]
    elseif io >= 1500 then
        color = MPGOColorsQuality["Rare"]
    elseif io >= 1000 then
        color = MPGOColorsQuality["Uncommon"]
    elseif io >= 500 then
        color = MPGOColorsQuality["Common"]
    end
    return color
end

function MPGODebug( msg, level)
    level = level or MPGODebugLevels.Critical
    if MPGOIsDebugMode and level >= MPGODebugLevel or level == MPGODebugLevels.Critical then
        local DebugColors = {
            [0] = {1, 1, 1},    -- White
            [1] = {1, 1, 0},    -- Yellow
            [2] = {1, 0.5, 0},  -- Orange
            [3] = {1, 0, 0}     -- Red
        }
        local color = DebugColors[level] or {1, 0, 0}  -- Default to red if level is not found
        DEFAULT_CHAT_FRAME:AddMessage(msg, color[1], color[2], color[3])
    end
end

function ResetGuildMemberFrames()
    local mpgogroupsFrame = _G["MPGOGroupsFrame"]
    local mpgoGuildmatesScrollChildFrame = _G["GuildmatesScrollChildFrame"]
    if not mpgogroupsFrame or not mpgoGuildmatesScrollChildFrame then return end

    -- Remove all guild member frames from rows
    for i = 1, mpgogroupsFrame:GetNumChildren() do
        local row = select(i, mpgogroupsFrame:GetChildren())
        for j = 1, row:GetNumChildren() do
            local guildmemberFrame = select(j, row:GetChildren())
            if not guildmemberFrame then break end
            guildmemberFrame:SetParent(mpgoGuildmatesScrollChildFrame)
            ResetGuildMemberFrames()
        end
    end

    -- Repopulate the guild list frame
    PopulateGuildmembersList()
end

function MPGODump(value, indent)
    indent = indent or ""
    if type(value) == "table" then
        for k, v in pairs(value) do
            if type(v) == "table" then
                print(indent .. tostring(k) .. ":")
                MPGODump(v, indent .. "  ")
            else
                print(indent .. tostring(k) .. ": " .. tostring(v))
            end
        end
    else
        print(indent .. tostring(value))
    end
end
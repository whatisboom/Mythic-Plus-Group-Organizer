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
        print(addonName .. " loaded!")
        -- Initialize your addon here
        InitializeFrames()
        RegisterSlashCommand()
        ShowFrame()
    elseif event == "PLAYER_LOGIN" then
        if IsInGuild() then
            C_GuildInfo.GuildRoster() -- Request guild roster update
        end
    elseif event == "GUILD_ROSTER_UPDATE" then
        PopulateGuildmatesList()
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
                print("Announce button clicked")
                MPGOPrintGroupMembers()
            end)
        end

        if button2 then
            button2:SetScript("OnClick", function()
                print("Button 2 clicked")
            end)
        end

        if button3 then
            button3:SetScript("OnClick", function()
                print("Button 3 clicked")
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
function PopulateGuildmatesList()
    local scrollChild = _G["GuildmatesScrollChildFrame"]
    if not scrollChild then return end
    if _G["MythicPlusGroupOrganizerFrame"]:IsShown() then
        print("Populating guildmates list")
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
        local name, _, _, level, _, _, _, _, online = GetGuildRosterInfo(i)
        if online and level == maxLevel and not IsPlayerInMPGOGroups(name) then
            local role = GetPlayerRole(name)
            table.insert(guildmates, { name = name, role = role })
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
        TANK = "Interface\\Addons\\Mythic Plus Group Organizer\\UI-LFG-ICON-PORTRAITROLES",
        HEALER = "Interface\\Addons\\Mythic Plus Group Organizer\\UI-LFG-ICON-PORTRAITROLES",
        DPS = "Interface\\Addons\\Mythic Plus Group Organizer\\UI-LFG-ICON-PORTRAITROLES"
    }

    local roleCoords = {
        TANK = { 0, 0.296875, 0.015625, 0.3125 },
        HEALER = { 0.296875, 0.59375, 0.015625, 0.3125 },
        DPS = { 0.59375, 0.890625, 0.015625, 0.3125 }
    }

    local index = 1
    for _, guildmateInfo in ipairs(guildmates) do
        local guildmate = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
        local guildmadeFrameHeight = 40
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
        local red, green, blue = MPGOGetPlayerIOColor(guildmate.mythicPlusRating)
        guildmate.texture:SetColorTexture(red, green, blue, 0.5) -- Set black background with 50% opacity

        local roleIcon = guildmate:CreateTexture(nil, "OVERLAY")
        roleIcon:SetSize(16, 16)
        roleIcon:SetPoint("LEFT")
        roleIcon:SetTexture(roleIcons[guildmateInfo.role])
        roleIcon:SetTexCoord(unpack(roleCoords[guildmateInfo.role]))

        guildmate.text = guildmate:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        guildmate.text:SetPoint("LEFT", roleIcon, "RIGHT", 5, 0)
        guildmate.text:SetText(guildmateInfo.name)
        guildmate.text:SetTextColor(1, 1, 1) -- Set text color to white

        guildmate.score = guildmate:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        guildmate.score:SetPoint("RIGHT", guildmate, "RIGHT", -5, 0)
        guildmate.score:SetText(tostring(guildmate.mythicPlusRating))

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
            print("Drag started for " .. self.text:GetText())
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
                    print("First child in row, setting left to " .. horizontalMargin)
                    CreateNewRowOfMPGOGroups() -- Create a new row since we always want an empty row
                elseif numChildren < 5 then
                    local left = (numChildren * widthForChild) + horizontalMargin
                    print("Setting left to " .. left .. " numChildren: " .. numChildren)
                    self:SetPoint("LEFT", dropTarget, "LEFT", left, 0)
                elseif numChildren == 5 then
                    -- here we will reject the move and put it back in the guildmember list
                    print("Row is full, rejecting move")
                end
                self:SetWidth(widthForChild) -- Set guild member frame width to 20% of row width
                self:SetParent(dropTarget)
                self:Show()
                C_GuildInfo.GuildRoster()
                print("Dropped on row " .. dropTarget:GetID())
            else
                self:SetParent(self.originalParent) -- Revert to original parent if not dropped on a group slot
                self:ClearAllPoints()
                self:SetPoint(unpack(self.originalPoint))
            end
            self:SetFrameStrata(self.originalFrameStrata)
            -- addonTable.draggedFrame = nil -- Clear the dragged frame
            print("Drag stopped for " .. self.text:GetText())
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
                print("Mouse is over row " .. i)
                return true, row
            end
        end
    end
    print("No valid drop target found")
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

    local numRows = mpgogroupsFrame:GetNumChildren()
    local rowNumber = numRows + 1

    local newRow = CreateFrame("Frame", "Row" .. rowNumber, mpgogroupsFrame, "BackdropTemplate")
    print("Created row " .. rowNumber)
    newRow:SetSize(500, 50)
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
        print(groupText)
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
    return "DPS"
end

-- GetPlayerMythicPlusRating: Retrieves the player's Mythic Plus rating from the RaiderIO addon.
function GetPlayerMythicPlusRating(playerNameAndRealm)
    if not RaiderIO then
        print("RaiderIO addon is not installed.")
        return 0
    end

    local playerName, realm = strsplit("-", playerNameAndRealm)
    print("Getting RaiderIO profile for " .. playerName .. " on realm " .. realm)

    local profile = RaiderIO.GetProfile(playerName, realm)
    if profile then
        return profile.mythicKeystoneProfile.currentScore or 0
    else
        print("No RaiderIO profile found for " .. playerName)
        return 0
    end
end

function MPGOLerpColors(amount, color1, color2)
    local red = MPGOLerpColor(amount, color1.red, color2.red)
    local green = MPGOLerpColor(amount, color1.green, color2.green)
    local blue = MPGOLerpColor(amount, color1.blue, color2.blue)
    return red, green, blue
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

-- MythicPlusGroupOrganizer.lua
local addonName, addonTable = ...

-- C_GuildInfo = C_GuildInfo
-- IsInGuild = IsInGuild
-- CreateFrame = CreateFrame
-- GetNumGuildMembers = GetNumGuildMembers
-- GetGuildRosterInfo = GetGuildRosterInfo
-- GetMaxLevelForExpansionLevel = GetMaxLevelForExpansionLevel
-- GetExpansionLevel = GetExpansionLevel

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
            tile = true, tileSize = 32,
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
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
    end

    local guildmatesListFrame = _G["GuildmatesListFrame"]
    if guildmatesListFrame then
        guildmatesListFrame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            tile = true, tileSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })

        -- Create ScrollFrame and ScrollChild
        local scrollFrame = CreateFrame("ScrollFrame", "GuildmatesScrollFrame", guildmatesListFrame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetSize(180, 280)
        scrollFrame:SetPoint("TOPLEFT", 10, -10)

        local scrollChild = CreateFrame("Frame", "GuildmatesScrollChildFrame", scrollFrame)
        scrollChild:SetSize(180, 280)
        scrollFrame:SetScrollChild(scrollChild)
    end

    local mpgogroupsFrame = _G["MPGOGroupsFrame"]
    if mpgogroupsFrame then
        mpgogroupsFrame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            tile = true, tileSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        CreateNewRowOfMPGOGroups() -- Ensure there is always an empty row at the bottom
    end
end

function AdjustGuildmatesListFrameSize()
    local frame = _G["MythicPlusGroupOrganizerFrame"]
    local guildmatesListFrame = _G["GuildmatesListFrame"]
    local mpgogroupsFrame = _G["MPGOGroupsFrame"]
    if frame and guildmatesListFrame and mpgogroupsFrame then
        local frameHeight = frame:GetHeight()
        local frameWidth = frame:GetWidth()
        guildmatesListFrame:SetHeight(frameHeight - 20) -- Maintain a vertical offset of 10 from the top and bottom
        mpgogroupsFrame:SetSize(frameWidth - guildmatesListFrame:GetWidth() - 30, frameHeight - 20) -- Maintain a padding of 10
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
        if online and level == maxLevel and not IsPlayerInMPGOGroups(name) and not IsPlayerInRowGroupSlot(name) then
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
        TANK = {0, 0.296875, 0.015625, 0.3125},
        HEALER = {0.296875, 0.59375, 0.015625, 0.3125},
        DPS = {0.59375, 0.890625, 0.015625, 0.3125}
    }

    local index = 1
    for _, guildmateInfo in ipairs(guildmates) do
        local guildmate = CreateFrame("Frame", nil, scrollChild)
        guildmate:SetSize(180, 20)
        guildmate:SetPoint("TOPLEFT", 10, -20 * (index - 1))

        local roleIcon = guildmate:CreateTexture(nil, "OVERLAY")
        roleIcon:SetSize(16, 16)
        roleIcon:SetPoint("LEFT")
        roleIcon:SetTexture(roleIcons[guildmateInfo.role])
        roleIcon:SetTexCoord(unpack(roleCoords[guildmateInfo.role]))

        guildmate.text = guildmate:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        guildmate.text:SetPoint("LEFT", roleIcon, "RIGHT", 5, 0)
        guildmate.text:SetText(guildmateInfo.name)

        guildmate:EnableMouse(true)
        guildmate:SetMovable(true)
        guildmate:RegisterForDrag("LeftButton")
        guildmate.originalPoint = { guildmate:GetPoint() }
        guildmate.originalParent = guildmate:GetParent() -- Store the original parent
        guildmate:SetScript("OnDragStart", function(self)
            self:StartMoving()
            self:SetParent(UIParent) -- Change parent to UIParent to make it visible everywhere
            self.originalFrameStrata = self:GetFrameStrata() -- Store the original frame strata
            self:SetFrameStrata("HIGH") -- Set frame strata to HIGH to appear on top
            addonTable.draggedFrame = self -- Store the dragged frame in the addonTable
            print("Drag started for " .. self.text:GetText())
        end)
        guildmate:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            if not CheckDropTarget(self) then
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

-- IsPlayerInMPGOGroups: Checks if a player is already in one of the group slots.
-- Returns true if the player is found, false otherwise.
function IsPlayerInMPGOGroups(playerName)
    local mpgogroupsFrame = _G["MPGOGroupsFrame"]
    if not mpgogroupsFrame then return false end

    for i = 1, mpgogroupsFrame:GetNumChildren() do
        local slot = select(i, mpgogroupsFrame:GetChildren())
        if slot:GetChildren() then
            local child = select(1, slot:GetChildren())
            if child and child.text and child.text:GetText() == playerName then
                return true
            end
        end
    end
    return false
end

-- IsPlayerInRowGroupSlot: Checks if a player is already attached to a row group slot frame.
-- Returns true if the player is found, false otherwise.
function IsPlayerInRowGroupSlot(playerName)
    local mpgogroupsFrame = _G["MPGOGroupsFrame"]
    if not mpgogroupsFrame then return false end

    for i = 1, mpgogroupsFrame:GetNumChildren() do
        local row = select(i, mpgogroupsFrame:GetChildren())
        for j = 1, row:GetNumChildren() do
            local slot = select(j, row:GetChildren())
            if slot:GetChildren() then
                local child = select(1, slot:GetChildren())
                if child and child.text and child.text:GetText() == playerName then
                    return true
                end
            end
        end
    end
    return false
end

-- CheckDropTarget: Checks if the frame is being dropped over a valid group slot.
-- If so, attaches the frame to the slot and returns true. Otherwise, returns false.
function CheckDropTarget(frame)
    local mpgogroupsFrame = _G["MPGOGroupsFrame"]
    if mpgogroupsFrame then
        for i = 1, mpgogroupsFrame:GetNumChildren() do
            local row = select(i, mpgogroupsFrame:GetChildren())
            if MouseIsOver(row) then
                print("Mouse is over row " .. i)
                row:GetScript("OnReceiveDrag")(row)
                local numChildren = row:GetNumChildren()
                local totalWidth = row:GetWidth()
                local spacing = (totalWidth - (numChildren * frame:GetWidth())) / (numChildren + 1)
                if numChildren == 0 then
                    frame:SetPoint("LEFT", row, "LEFT", spacing, 0)
                else
                    frame:SetPoint("LEFT", row, "LEFT", spacing * numChildren, 0)
                end
                frame:SetParent(row)
                frame:ClearAllPoints()
                return true
            end
        end
    end
    print("No valid drop target found")
    return false
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
-- Ensures the slots are not draggable.
function CreateNewRowOfMPGOGroups()
    local mpgogroupsFrame = _G["MPGOGroupsFrame"]
    if not mpgogroupsFrame then return end

    local numRows = mpgogroupsFrame:GetNumChildren()
    local rowNumber = numRows + 1

    local newRow = CreateFrame("Frame", "Row" .. rowNumber, mpgogroupsFrame, "BackdropTemplate")
    print("Created row " .. rowNumber)
    newRow:SetSize(500, 50)
    if rowNumber == 1 then
        newRow:SetPoint("TOPLEFT", mpgogroupsFrame, "TOPLEFT", 0, -10) -- Start at the top with an offset of 10
    else
        newRow:SetPoint("TOPLEFT", _G["Row" .. (rowNumber - 1)], "BOTTOMLEFT", 0, -10) -- Position below the previous row with an offset of 10
    end
    newRow:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        tile = true, tileSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    newRow:Show()

    newRow:SetScript("OnReceiveDrag", function(self)
        print("OnReceiveDrag called for row " .. rowNumber)
        local numChildren = self:GetNumChildren()
        local totalWidth = newRow:GetWidth()
        local spacing = (totalWidth - (numChildren * 100)) / (numChildren + 1)
        local frame = addonTable.draggedFrame
        if frame then
            print("Dragged frame: " .. frame.text:GetText())
            print("Setting Parent to " .. newRow:GetName())
            frame:SetParent(newRow)
            print("Parent set to " .. frame:GetParent():GetName())
            frame:ClearAllPoints()
            frame:SetPoint("LEFT", newRow, "LEFT", spacing * (numChildren + 1), 0)
            print("Set point to " .. frame:GetPoint())
            frame:Show() -- Ensure the frame is visible
            print("Frame shown: " .. tostring(frame:IsShown()))
            addonTable.draggedFrame = nil
        else
            print("No dragged frame found")
        end
    end)
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
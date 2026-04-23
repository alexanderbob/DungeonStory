--- @alias PlayerData { name: string, class: string, equippedItemLevel: number, mPlusRating: number }
--- @alias PlayerDataFeedback { name: string, class: string, equippedItemLevel: number, mPlusRating: number, score: number | nil, comment: string | nil }
--- @alias DungeonStoryEntry { time: number, ilvl: number, mPlusRating: number, comment: string | nil, score: number | nil, runIndex: number | nil }
--- @alias DungeonStorySinglePlayerData DungeonStoryEntry[]
--- @alias DungeonStoryPlayers { [string]: DungeonStorySinglePlayerData }
--- @alias DungeonState { isActive: boolean, dungeonID: number, startTime: number, deathCount: number, keystoneLevel: number, party: PlayerData[] }
--- @alias DungeonCompletionData { dungeonID: number, startTime: number, onTime:boolean, deathCount: number, keystoneLevel: number, keystoneUpgradeLevels: number, party: PlayerData[], isAbandoned: boolean | nil }
--- @alias DungeonStoryRuns DungeonCompletionData[]

-- dropdown menu related code comes from RaiderIO

---@class PlayerLocationPolyfill
---@field public guid? string
---@field public unit? string
---@field public IsValid fun(self: PlayerLocationPolyfill): boolean
---@field public IsGUID fun(self: PlayerLocationPolyfill): boolean
---@field public GetGUID fun(self: PlayerLocationPolyfill): string
---@field public GetUnit fun(self: PlayerLocationPolyfill): string
---@field public IsUnit fun(self: PlayerLocationPolyfill): boolean
---@field public IsCommunityData fun(self: PlayerLocationPolyfill): boolean

---@class ModifyMenuCallbackRootDescriptionContextDataPolyfill
---@field public fromPlayerFrame? boolean
---@field public isMobile? boolean
---@field public isRafRecruit? boolean
---@field public name? string
---@field public server? string
---@field public unit? string
---@field public which? string
---@field public accountInfo? BNetAccountInfo
---@field public playerLocation? PlayerLocationPolyfill
---@field public friendsList? number

---@class ModifyMenuCallbackRootDescriptionPolyfill
---@field public tag string
---@field public contextData? ModifyMenuCallbackRootDescriptionContextDataPolyfill
---@field public CreateDivider fun(self: ModifyMenuCallbackRootDescriptionPolyfill)
---@field public CreateTitle fun(self: ModifyMenuCallbackRootDescriptionPolyfill, text: string)
---@field public CreateButton fun(self: ModifyMenuCallbackRootDescriptionPolyfill, text: string, callback: fun())

---@class ModifyMenuReturnPolyfill
---@field public Unregister fun(self: ModifyMenuReturnPolyfill)
---@alias ModifyMenuCallbackFuncPolyfill fun(owner: Frame, rootDescription: ModifyMenuCallbackRootDescriptionPolyfill, contextData: ModifyMenuCallbackRootDescriptionContextDataPolyfill)
---@alias ModifyMenu fun(tag: string, callback: ModifyMenuCallbackFuncPolyfill): ModifyMenuReturnPolyfill

local addonName = ... ---@type string @The name of the addon.

local isRaiderIoInstalled = false
local classic = false
local isLFGFrameHooked = false
local dungeonState = { isActive = false, dungeonID = 0, startTime = 0, deathCount = 0, keystoneLevel = 0, party = {} } --[[@as DungeonState]]
local currentPlayerRealmName = ""
local VALID_TYPES = {
    ARENAENEMY = true,
    BN_FRIEND = true,
    -- BN_FRIEND_OFFLINE = true,
    CHAT_ROSTER = true,
    COMMUNITIES_GUILD_MEMBER = true,
    COMMUNITIES_WOW_MEMBER = true,
    ENEMY_PLAYER = true,
    FOCUS = true,
    FRIEND = true,
    -- FRIEND_OFFLINE = true,
    GUILD = true,
    GUILD_OFFLINE = true,
    PARTY = true,
    PLAYER = true,
    RAID = true,
    RAID_PLAYER = true,
    SELF = true,
    TARGET = true,
    WORLD_STATE_SCORE = true,
}
---@type table<string, number?> `1` LFD
local VALID_TAGS = {
    MENU_LFG_FRAME_SEARCH_ENTRY = 1,
    MENU_LFG_FRAME_MEMBER_APPLY = 1,
}
local UNIT_TOKENS = {
    mouseover = true,
    player = true,
    target = true,
    focus = true,
    pet = true,
    vehicle = true,
}

do
    for i = 1, 40 do
        UNIT_TOKENS["raid" .. i] = true
        UNIT_TOKENS["raidpet" .. i] = true
        UNIT_TOKENS["nameplate" .. i] = true
    end

    for i = 1, 4 do
        UNIT_TOKENS["party" .. i] = true
        UNIT_TOKENS["partypet" .. i] = true
    end

    for i = 1, 5 do
        UNIT_TOKENS["arena" .. i] = true
        UNIT_TOKENS["arenapet" .. i] = true
    end

    for i = 1, (MAX_BOSS_FRAMES or 10) do
        UNIT_TOKENS["boss" .. i] = true
    end

    for k, _ in pairs(UNIT_TOKENS) do
        UNIT_TOKENS[k .. "target"] = true
    end
end


if select(4, GetBuildInfo()) < 100200 then
    classic = true
end

--[[@type ModifyMenu]]
local ModifyMenu = Menu and Menu.ModifyMenu
local AceGUI = LibStub("AceGUI-3.0") --[[@as AceGUI-3.0]]

local function print(a)
    DEFAULT_CHAT_FRAME:AddMessage(a)
end


---@param fullName string player full name (Name-Realm)
---@return DungeonStorySinglePlayerData | nil
local function DS_GetStoredData(fullName)
    return DungeonStoryPlayers[fullName]
end

---@param timestamp number
---@return string|osdate
local function FormatDateTime(timestamp)
    return date("%Y-%m-%d %H:%M:%S", timestamp)
end

---@param playerData PlayerDataFeedback
---@param runIndex number | nil Index of the run in DungeonStoryRuns
local function SavePlayerFeedback(playerData, runIndex)
    local fullName = playerData.name

    if DungeonStoryPlayers[fullName] == nil then
        DungeonStoryPlayers[fullName] = {}
    end

    local toSave = DungeonStoryPlayers[fullName] --[[@as DungeonStorySinglePlayerData]]
    local val --[[@as DungeonStoryEntry]] = {
        comment = playerData.comment,
        score = playerData.score,
        mPlusRating = playerData.mPlusRating,
        ilvl = playerData.equippedItemLevel,
        time = GetServerTime(),
        runIndex = runIndex
    }

    toSave[#toSave + 1] = val
end

---@param i number
---@param groupState {selectedIdx: number, checkboxes: AceGUICheckBox[]}
---@param checkboxValue number
---@param data PlayerDataFeedback
---@return function
local function checkboxCallback(i, groupState, checkboxValue, data)
    return function(widget, event, value)
        if not value then
            groupState.selectedIdx = nil
            data.score = nil
            return
        end

        if groupState.selectedIdx then
            groupState.checkboxes[groupState.selectedIdx]:SetValue(false)
        end

        groupState.selectedIdx = i
        groupState.checkboxes[groupState.selectedIdx]:SetValue(true)
        data.score = checkboxValue
    end
end

---@param data PlayerDataFeedback
---@return function
local function feedbackCommentCallback(data)
    return function(widget, event, text)
        data.comment = text
    end
end

---@param parent AceGUIContainer
---@param text string
---@param color {r: number, g: number, b: number} | nil
---@param fontSize number
local function createLabel(parent, text, color, fontSize)
    local label = AceGUI:Create("Label") --[[@as AceGUILabel]]
    label:SetText(text)
    if color then
        label:SetColor(color.r, color.g, color.b)
    end
    label:SetFont("fonts/arialn.ttf", fontSize, "")
    label:SetJustifyV("MIDDLE")
    parent:AddChild(label)
end

---@param feedbackType -3 | -1 | 1 | 3
---@return {r: number, g: number, b: number} | nil
local function GetFeedbackColors(feedbackType)
    if feedbackType == -3 then
        return {r = 0.647, g = 0, b = 0}
    elseif feedbackType == -1 then
        return {r = 0.863, g = 0.510, b = 0}
    elseif feedbackType == 1 then
        return {r = 0.824, g = 0.745, b = 0}
    elseif feedbackType == 3 then
        return {r = 0, g = 0.502, b = 0}
    end
end

---@param feedbackType -3 | -1 | 1 | 3
---@return string
local function GetFeedbackHexColors(feedbackType)
    if feedbackType == -3 then
        return "|cffa50000"
    elseif feedbackType == -1 then
        return "|cffdc8200"
    elseif feedbackType == 1 then
        return "|cffd2be00"
    elseif feedbackType == 3 then
        return "|cff008000"
    end
end

---@param parent AceGUIContainer
---@param data PlayerDataFeedback
local function createCheckboxGroup(parent, data)
    local groupState = {
        selectedIdx = nil,
        checkboxes = {}
    }
    local labelFontSize = 16

    local scoreValue = -3
    local cb1 = AceGUI:Create("CheckBox") --[[@as AceGUICheckBox]]
    cb1:SetCallback("OnValueChanged", checkboxCallback(1, groupState, scoreValue, data))
    table.insert(groupState.checkboxes, cb1)
    parent:AddChild(cb1)
    local color = GetFeedbackColors(scoreValue)
    createLabel(parent, "--", color, labelFontSize)

    local cb2 = AceGUI:Create("CheckBox") --[[@as AceGUICheckBox]]
    scoreValue = -1
    cb2:SetCallback("OnValueChanged", checkboxCallback(2, groupState, scoreValue, data))
    table.insert(groupState.checkboxes, cb2)
    parent:AddChild(cb2)
    color = GetFeedbackColors(scoreValue)
    createLabel(parent, "-", color, labelFontSize)

    local cb3 = AceGUI:Create("CheckBox") --[[@as AceGUICheckBox]]
    scoreValue = 1
    cb3:SetCallback("OnValueChanged", checkboxCallback(3, groupState, scoreValue, data))
    table.insert(groupState.checkboxes, cb3)
    parent:AddChild(cb3)
    color = GetFeedbackColors(scoreValue)
    createLabel(parent, "+", color, labelFontSize)

    local cb4 = AceGUI:Create("CheckBox") --[[@as AceGUICheckBox]]
    scoreValue = 3
    cb4:SetCallback("OnValueChanged", checkboxCallback(4, groupState, scoreValue, data))
    table.insert(groupState.checkboxes, cb4)
    parent:AddChild(cb4)
    color = GetFeedbackColors(scoreValue)
    createLabel(parent, "++", color, labelFontSize)
end

---@param parent AceGUIContainer
---@param playerName string
---@param className string
---@return AceGUIInlineGroup
local function createInlineGroup(parent, playerName, className)
    -- this is a custom function in InlineGroup
    local group = AceGUI:Create("ColoredInlineGroup") --[[@as AceGUIInlineGroup]]
    if className then
        local classColor = C_ClassColor.GetClassColor(className)
        if classColor then
            group:SetTitleColor(classColor.r, classColor.g, classColor.b)
        end
    end
    group:SetLayout("Table")
    group:SetTitle(playerName)
    group:SetFullWidth(true)
    group:SetUserData("table", {
        columns = { 25, 50, 25, 50, 25, 50, 25, 50 },
        spaceH = 1
    })

    parent:AddChild(group)
    return group
end

---@param parent AceGUIContainer
---@param data PlayerDataFeedback
local function groupPlayerFeedback(parent, data)
    local group = createInlineGroup(parent, data.name, data.class)
    createCheckboxGroup(group, data)

    local multiLine = AceGUI:Create("MultiLineEditBox") --[[@as AceGUIMultiLineEditBox]]
    multiLine:SetLabel("Comments:")
    multiLine:SetFullWidth(true)
    multiLine:SetUserData("cell", { colspan = 8 })
    multiLine:DisableButton(true)
    multiLine:SetCallback("OnTextChanged", feedbackCommentCallback(data))
    group:AddChild(multiLine)
end

---@param data PlayerDataFeedback[]
---@param runIndex number | nil Index of the run in DungeonStoryRuns
---@return function
local function FeedbackFrameCloseHandler(data, runIndex)
    return function(widget, event)
        AceGUI:Release(widget)
        for i, playerData in pairs(data) do
            SavePlayerFeedback(playerData, runIndex)
        end
    end
end

---@param data PlayerData[]
---@param runIndex number | nil Index of the run in DungeonStoryRuns
local function ShowFeedbackFrame(data, runIndex)
    local f = AceGUI:Create("Frame") --[[@as AceGUIFrame]]
    f:SetCallback("OnClose", FeedbackFrameCloseHandler(data, runIndex))
    f:SetTitle("Dungeon Story")
    f:SetStatusText("Score your team members!")
    f:SetLayout("Fill")

    local sf = AceGUI:Create("ScrollFrame") --[[@as AceGUIScrollFrame]]
    sf:SetLayout("Flow")

    for i, playerData in pairs(data) do
        -- casting PlayerData to PlayerDataFeedback to allow adding score and comment fields
        groupPlayerFeedback(sf, playerData --[[@as PlayerDataFeedback]])
    end

    f:AddChild(sf)
    f:Show()
end

---@param parent AceGUIContainer
---@param data DungeonStoryEntry
---@return AceGUIInlineGroup
local function CreateHistoryInlineGroup(parent, data)
    -- this is a custom function in InlineGroup
    local group = AceGUI:Create("InlineGroup") --[[@as AceGUIInlineGroup]]
    local userFriendlyTime = tostring(FormatDateTime(data.time))
    group:SetTitle(userFriendlyTime)
    group:SetLayout("Table")
    group:SetFullWidth(true)
    group:SetUserData("table", {
        columns = { 50, 25, 75, 50, 25, 50, 75, 200 },
        spaceH = 1
    })

    parent:AddChild(group)
    return group
end

---@param fullName string
---@param playerData DungeonStorySinglePlayerData
local function ShowHistoryFrame(fullName, playerData)
    local f = AceGUI:Create("Frame") --[[@as AceGUIFrame]]
    f:SetCallback("OnClose", function() AceGUI:Release(f) end)
    f:SetTitle("Dungeon Story")
    f:SetStatusText("Review past activities with " .. fullName)
    f:SetLayout("Fill")

    local sf = AceGUI:Create("ScrollFrame") --[[@as AceGUIScrollFrame]]
    sf:SetLayout("Flow")

    for i = #playerData, 1, -1 do
        local data = playerData[i]
        local entryGroup = CreateHistoryInlineGroup(sf, data)
        createLabel(entryGroup, "Score", nil, 14)
        createLabel(entryGroup, tostring(data.score or 0), GetFeedbackColors(data.score), 14)
        
        createLabel(entryGroup, "M+ rating", nil, 14)
        local r, g, b = 1, 1, 1
        if isRaiderIoInstalled then
            r, g, b = _G.RaiderIO.GetScoreColor(data.mPlusRating)
        else
            local scoreColor = C_ChallengeMode.GetDungeonScoreRarityColor(data.mPlusRating)
            r, g, b = scoreColor.r, scoreColor.g, scoreColor.b
        end
        createLabel(entryGroup, tostring(data.mPlusRating), {r = r, g = g, b = b}, 14)

        createLabel(entryGroup, "iLvl", nil, 14)
        createLabel(entryGroup, data.ilvl > 0 and tostring(data.ilvl) or "N/A", nil, 14)

        if data.comment ~= nil then
            createLabel(entryGroup, "Comment", nil, 14)
            createLabel(entryGroup, data.comment, nil, 14)
        end
    end

    f:AddChild(sf)
    f:Show()
end

---@param tooltip any
---@param data DungeonStorySinglePlayerData
---@param unit UnitToken
local function AddTooltipInfo(tooltip, data)
    local line = string.format("You met %d times.", #data)
    tooltip:AddLine(line, 1, 1, 1)

    local lastMet = data[#data]
    line = string.format("Last met %s",
        FormatDateTime(lastMet.time),
        lastMet.mPlusRating)
    tooltip:AddLine(line, 1, 1, 1)

    local mixin --[[@ColorMixin]]
    if isRaiderIoInstalled then
        local r, g, b = _G.RaiderIO.GetScoreColor(lastMet.mPlusRating)
        mixin = CreateColor(r, g, b)
    else
        mixin = C_ChallengeMode.GetDungeonScoreRarityColor(lastMet.mPlusRating)
    end
    local wrappedScore = mixin:WrapTextInColorCode(tostring(lastMet.mPlusRating))
    line = string.format("M+ rating was %s", wrappedScore)
    tooltip:AddLine(line, 1, 1, 1)

    local totalPositive, totalNegative, lastComment = 0, 0, nil
    for i, entry in ipairs(data) do
        totalPositive = totalPositive + (entry.score and entry.score > 0 and entry.score or 0)
        totalNegative = totalNegative + (entry.score and entry.score < 0 and entry.score or 0)
        if entry.comment then
            lastComment = entry.comment
        end
    end

    local col = GetFeedbackColors(3)
    local pc = CreateColor(col.r, col.g, col.b)
    col = GetFeedbackColors(-3)
    local nc = CreateColor(col.r, col.g, col.b)
    tooltip:AddLine(string.format("Positive: %s", pc:WrapTextInColorCode(tostring(totalPositive))), 1, 1, 1)
    tooltip:AddLine(string.format("Negative: %s", nc:WrapTextInColorCode(tostring(totalNegative))), 1, 1, 1)
    if lastComment ~= nil then
        tooltip:AddLine(string.format("Comment: '%s'", lastComment), 1, 1, 1)
    end
end

if not classic then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, tooltipData)
        -- In instances (and elsewhere in retail 11.x+/12.x), unit tooltips can be
        -- dispatched for "restricted" / secret unit tokens that belong to Blizzard's
        -- protected targeting system. Calling tooltip:GetUnit() in that case causes
        -- TooltipUtil.GetDisplayedUnit -> UnitName(unit) to throw:
        --   "Secret values are only allowed during untainted execution"
        -- Avoid the unit token entirely and work off the tooltipData.guid that the
        -- secure tooltip pipeline hands us. When the tooltip is restricted, guid is
        -- absent (or not a usable string) and we simply bail.
        if not tooltipData then return end
        local guid = tooltipData.guid
        -- IMPORTANT: check issecretvalue BEFORE any equality / string op on
        -- guid. A secret string is still type=="string", but comparing it
        -- ("guid == ...", string.sub, etc.) throws:
        --   "attempt to compare local 'guid' (a secret string value, while execution tainted)"
        if guid == nil then return end
        if issecretvalue and issecretvalue(guid) then return end
        if type(guid) ~= "string" or guid == "" then return end
        if string.sub(guid, 1, 6) ~= "Player" then return end

        local _, _, _, _, _, name, realmName = GetPlayerInfoByGUID(guid)
        if not name or name == "" then return end

        realmName = (realmName and realmName ~= "") and realmName or currentPlayerRealmName
        local fullName = name .. "-" .. realmName
        if DungeonStoryPlayers[fullName] then
            AddTooltipInfo(tooltip, DungeonStoryPlayers[fullName])
        end
    end)
end

---@param unitInfo PlayerData
---@return string
local function generateLink(unitInfo)
    return string.format(
        "|cff71d5ff|Haddon:DungeonStory:Save:%s:%s:%s:%s|h[DungeonStory save %s]|h|r",
        unitInfo.name,
        unitInfo.class,
        unitInfo.equippedItemLevel,
        unitInfo.mPlusRating,
        unitInfo.name)
end

---@param unit UnitToken
---@return PlayerData | nil
local function collectUnitInfo(unit)
    if not UnitIsPlayer(unit) then
        return nil
    end

    -- Use GUID-based lookup for clean name/realm (guards against tainted values)
    local guid = UnitGUID(unit)
    if not guid then return nil end

    local _, fileName, _, _, _, name, server = GetPlayerInfoByGUID(guid)
    if not name or name == "" then return nil end

    server = (server and server ~= "") and server or currentPlayerRealmName
    local ratingSummary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary(unit)
    local mPlusRating = 0
    if ratingSummary and ratingSummary.currentSeasonScore then
        mPlusRating = ratingSummary.currentSeasonScore
    end

    -- very unreliable, can be 0 when not inspected
    local equippedItemLevel = C_PaperDollInfo.GetInspectItemLevel(unit)
    return {
        name = name.."-"..server,
        class = fileName,
        equippedItemLevel = equippedItemLevel or 0,
        mPlusRating = mPlusRating
    }
end

---@param unit UnitToken
local function handleUnit(unit)
    if not UnitIsPlayer(unit) then
        return
    end

    -- ilvl is unreliable when the unit is not in your party/raid
    -- mplusRating is unreliable when target is far away
    -- should be ok in real life usage since players are usually in your party when dungeon is completed
    local unitInfo = collectUnitInfo(unit)
    if not unitInfo then
        return
    end
    local link = generateLink(unitInfo)
    print(link)
end

---@return PlayerData[]
local function retrieveRaidInfo()
    local data = {}
    for i = 1, 40 do
        local unit = "raid" .. i
        if UnitExists(unit) and UnitIsPlayer(unit) and not UnitIsUnit(unit, "player") then
            local unitInfo = collectUnitInfo(unit)
            if unitInfo then
                table.insert(data, unitInfo)
            end
        end
    end
    return data
end

---@return PlayerData[]
local function retrieveGroupInfo()
    local data = {}
    local numMembers = GetNumSubgroupMembers()
    for i = 1, numMembers do
        local unit = "party" .. i
        if UnitExists(unit) and UnitIsPlayer(unit) then
            local unitInfo = collectUnitInfo(unit)
            if unitInfo then
                table.insert(data, unitInfo)
            end
        end
    end
    return data
end

---@return PlayerData[]
local function collectDataForScoring()
    local data = {}

    if (IsInRaid()) then
        data = retrieveRaidInfo()
    else
        data = retrieveGroupInfo()
    end
    return data
end

---@param fullName string
---@return number | nil, number | nil
local function GatherPlayerStats(fullName)
    local data = DS_GetStoredData(fullName)
    if data then
        local totalNegative, totalPositive = 0, 0
        for key, value in pairs(data) do
            if value.score ~= nil and value.score < 0 then
                totalNegative = totalNegative + value.score
            elseif value.score ~= nil and value.score > 0 then
                totalPositive = totalPositive + value.score
            end
        end
        return totalPositive, totalNegative
    end

    return nil, nil
end

---@param name string Player name (may or may not include "-Realm")
---@param realmsToProbe string[] Realms to try when name has no realm suffix
---@return number positive, number negative
local function GetAggregatedFeedback(name, realmsToProbe)
    if not name or name == "" then return 0, 0 end
    if string.find(name, "-", nil, true) then
        local p, n = GatherPlayerStats(name)
        return p or 0, n or 0
    end
    local pos, neg = 0, 0
    for _, realm in ipairs(realmsToProbe) do
        if realm and realm ~= "" then
            local p, n = GatherPlayerStats(name .. "-" .. realm)
            pos = pos + (p or 0)
            neg = neg + (n or 0)
        end
    end
    return pos, neg
end

---@param tooltip GameTooltip
---@param totalPositive number
---@param totalNegative number
local function AppendDungeonStoryTooltip(tooltip, totalPositive, totalNegative)
    if totalPositive == 0 and totalNegative == 0 then return end
    local negColor = GetFeedbackHexColors(-3)
    local posColor = GetFeedbackHexColors(3)
    tooltip:AddLine(
        string.format("DungeonStory: %s%d|r / %s+%d|r", negColor, totalNegative, posColor, totalPositive),
        1, 1, 1
    )
end



local function ResetCurrentDungeonState()
    dungeonState = { isActive = false, dungeonID = 0, startTime = 0, deathCount = 0, keystoneLevel = 0, party = {} } --[[@as DungeonState]]
end

local function IncreaseDeathCount()
    dungeonState.deathCount = dungeonState.deathCount + 1
end

local function StartChallengeMode()
    ResetCurrentDungeonState()
    dungeonState.isActive = true
    dungeonState.dungeonID = C_ChallengeMode.GetActiveChallengeMapID() or 0
    dungeonState.keystoneLevel = C_ChallengeMode.GetActiveKeystoneInfo()
    dungeonState.party = collectDataForScoring()
    dungeonState.startTime = GetServerTime()
end

local function ResetChallengeMode()
    ResetCurrentDungeonState()
end

---@param completionData ChallengeCompletionInfo | nil
---@param isAbandon boolean
---@return number Index of the saved dungeon run
local function SaveDungeonRun(completionData, isAbandon)
    local dungeon = {
        dungeonID = dungeonState.dungeonID or completionData and completionData.mapChallengeModeID,
        keystoneLevel = dungeonState.keystoneLevel or completionData and completionData.level,
        startTime = dungeonState.startTime or completionData and completionData.time,
        deathCount = dungeonState.deathCount,
        party = dungeonState.party,
        keystoneUpgradeLevels = completionData and completionData.keystoneUpgradeLevels or 0,
        onTime = completionData and completionData.onTime or false
    } --[[@as DungeonCompletionData]]
    table.insert(DungeonStoryRuns, dungeon)
    return #DungeonStoryRuns
end

local function CompleteChallengeMode()
    local completionData = C_ChallengeMode.GetChallengeCompletionInfo()
    local runIndex = SaveDungeonRun(completionData, false)
    local data = collectDataForScoring()
    ShowFeedbackFrame(data, runIndex)
    ResetChallengeMode()
end

---@param votePassed boolean
local function AbandonVoteFinished(votePassed)
    if votePassed then
        local runIndex = SaveDungeonRun(nil, true)
        local data = collectDataForScoring()
        ShowFeedbackFrame(data, runIndex)
        ResetChallengeMode()
    end
end

local function GroupRosterUpdate()
    if dungeonState.isActive or C_ChallengeMode.IsChallengeModeActive() then
        local numSubgroupMembers = GetNumSubgroupMembers()
        if numSubgroupMembers ~= #dungeonState.party then
            -- party composition changed, did someone leave?
            local currentGroup = collectDataForScoring()
            for i, cachedTeammate in pairs(dungeonState.party) do
                for j, currentTeammate in pairs(currentGroup) do
                    if cachedTeammate.name == currentTeammate.name then
                        -- still in group
                        break
                    end
                    if j == #currentGroup then
                        -- not found in current group, must have left
                        print("Party member left: " .. cachedTeammate.name)
                        print(generateLink(cachedTeammate))
                    end
                end
            end
        end
    end
end

-- LFG integration.
--
-- Historically we hooked LFGListSearchEntry_Update and
-- LFGListApplicationViewer_UpdateApplicantMember via hooksecurefunc and
-- mutated the row widgets (Name:SetText / Rating:SetText / SetWidth).
-- Those updates run on Blizzard's secure execution path for the Sign Up /
-- Invite buttons, so any write to the row frames propagated taint and
-- produced "AddOn tried to call a protected function" errors when the
-- user clicked Sign Up. Retail 12.0.5 tightened this.
--
-- To keep at-a-glance scores without tainting the rows we draw our own
-- FontString overlays. The overlays live on our own (insecure) host
-- frame and are positioned relative to each row via SetPoint. Anchoring
-- an insecure frame TO a secure frame does not propagate taint; only
-- writes to the secure frame (SetText / SetParent / SetWidth / adding
-- children) do. We never write anything to the row widgets.

-- Host frame that owns all overlay FontStrings. Strata is raised above
-- the default LFG frames so the overlays render on top of the rows.
local lfgOverlayHost = CreateFrame("Frame", nil, UIParent)
lfgOverlayHost:SetFrameStrata("HIGH")
lfgOverlayHost:SetAllPoints(UIParent)

---@type table<Frame, FontString>
local searchOverlays = {}
---@type table<Frame, FontString>
local applicantOverlays = {}

---@param anchorFrame Frame
---@param store table<Frame, FontString>
---@return FontString
local function LFG_GetOrCreateOverlay(anchorFrame, store)
    local fs = store[anchorFrame]
    if fs then return fs end
    fs = lfgOverlayHost:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetJustifyH("RIGHT")
    fs:Hide()
    store[anchorFrame] = fs
    return fs
end

---@param fs FontString
---@param pos number
---@param neg number
local function LFG_SetOverlayScore(fs, pos, neg)
    if pos == 0 and neg == 0 then
        fs:Hide()
        return
    end
    local negColor = GetFeedbackHexColors(-3)
    local posColor = GetFeedbackHexColors(3)
    fs:SetText(string.format("%s%d|r %s+%d|r", negColor, neg, posColor, pos))
    fs:Show()
end

---@param row Frame @LFGListFrame.SearchPanel.ScrollBox row (LFGListSearchEntry)
local function LFG_UpdateSearchRow(row)
    local fs = LFG_GetOrCreateOverlay(row, searchOverlays)
    local resultID = row.resultID
    if not resultID or not row:IsShown() then fs:Hide(); return end
    local info = C_LFGList.GetSearchResultInfo(resultID)
    if not info or not info.numMembers then fs:Hide(); return end

    local realmsToProbe = { currentPlayerRealmName }
    if info.leaderName and string.find(info.leaderName, "-", nil, true) then
        local _, realm = strsplit("-", info.leaderName)
        if realm and realm ~= "" and realm ~= currentPlayerRealmName then
            table.insert(realmsToProbe, realm)
        end
    end

    local pos, neg = 0, 0
    for i = 1, info.numMembers do
        local memberInfo = C_LFGList.GetSearchResultPlayerInfo(resultID, i)
        if memberInfo and memberInfo.name then
            local p, n = GetAggregatedFeedback(memberInfo.name, realmsToProbe)
            pos = pos + p
            neg = neg + n
        end
    end

    fs:ClearAllPoints()
    -- Anchor near the row's right edge; nudge left of the DataDisplay/
    -- activity-name area. The exact offset is deliberately conservative
    -- so we don't overlap the "Sign Up" button or role icons.
    fs:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    LFG_SetOverlayScore(fs, pos, neg)
end

---@param memberBtn Frame @LFGListApplicationViewer row .Members[i] button
---@param applicantID number
---@param memberIdx number
local function LFG_UpdateApplicantMember(memberBtn, applicantID, memberIdx)
    local fs = LFG_GetOrCreateOverlay(memberBtn, applicantOverlays)
    if not memberBtn:IsShown() then fs:Hide(); return end
    local fullName = C_LFGList.GetApplicantMemberInfo(applicantID, memberIdx)
    if not fullName then fs:Hide(); return end

    local nameToProbe = fullName
    if not string.find(nameToProbe, "-", nil, true) then
        nameToProbe = nameToProbe .. "-" .. currentPlayerRealmName
    end
    local pos, neg = GatherPlayerStats(nameToProbe)
    pos = pos or 0
    neg = neg or 0

    fs:ClearAllPoints()
    fs:SetPoint("RIGHT", memberBtn, "RIGHT", -4, 0)
    LFG_SetOverlayScore(fs, pos, neg)
end

local function LFG_RefreshSearchRows(frames)
    if not frames then return end
    for _, row in ipairs(frames) do
        if row.resultID then
            LFG_UpdateSearchRow(row)
        end
    end
end

local function LFG_RefreshApplicantRows(frames)
    if not frames then return end
    for _, row in ipairs(frames) do
        local applicantID = row.applicantID
        local members = row.Members
        if applicantID and members then
            for i, btn in ipairs(members) do
                if btn.memberIdx then
                    LFG_UpdateApplicantMember(btn, applicantID, btn.memberIdx)
                else
                    LFG_UpdateApplicantMember(btn, applicantID, i)
                end
            end
        end
    end
end

---@param scrollBox Frame
---@param cb fun(frames: Frame[])
local function LFG_ObserveScrollBox(scrollBox, cb)
    if not scrollBox or not scrollBox.RegisterCallback then return end
    local frames = scrollBox.GetFrames and scrollBox:GetFrames()
    if frames then cb(frames) end
    if ScrollBoxListMixin and ScrollBoxListMixin.Event then
        if ScrollBoxListMixin.Event.OnUpdate then
            scrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnUpdate, function()
                cb(scrollBox:GetFrames())
            end)
        end
        if ScrollBoxListMixin.Event.OnScroll then
            scrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnScroll, function()
                cb(scrollBox:GetFrames())
            end)
        end
    end
end

local function TryInitLFG()
    if isLFGFrameHooked then return end
    if not LFGListFrame or not LFGListFrame.ApplicationViewer or not LFGListFrame.SearchPanel then return end
    isLFGFrameHooked = true

    LFG_ObserveScrollBox(LFGListFrame.SearchPanel.ScrollBox, LFG_RefreshSearchRows)
    LFG_ObserveScrollBox(LFGListFrame.ApplicationViewer.ScrollBox, LFG_RefreshApplicantRows)
end

local function addonLoadedHandler(addonName)
    if addonName == "DungeonStory" then
        if DungeonStoryPlayers == nil then --[[@as DungeonStoryPlayers]]
            DungeonStoryPlayers = {}
        end
        if DungeonStoryRuns == nil then --[[@as DungeonStoryRuns]]
            DungeonStoryRuns = {}
        end
        currentPlayerRealmName = GetRealmName()
    end
    TryInitLFG()
end

---@return boolean @If the unit provided is a unit token this returns true, otherwise false
local function IsUnitToken(unit)
    return type(unit) == "string" and UNIT_TOKENS[unit]
end

---@param arg1 string @"unit", "name", or "name-realm"
---@param arg2 string|any @"realm" or nil
---@return boolean, boolean, boolean @If the args used in the call makes it out to be a proper unit, arg1 is true and only then is arg2 true if unit exists and arg3 is true if unit is a player.
local function IsUnit(arg1, arg2)
    if not arg2 and type(arg1) == "string" and arg1:find("-", nil, true) then
        arg2 = true
    end
    local isUnit = not arg2 or IsUnitToken(arg1)
    return isUnit, isUnit and UnitExists(arg1), isUnit and UnitIsPlayer(arg1)
end

local function GetNameRealm(arg1, arg2)
    local unit, name, realm
    local _, unitExists, unitIsPlayer = IsUnit(arg1, arg2)
    if unitExists then
        unit = arg1
        if unitIsPlayer then
            name, realm = UnitNameUnmodified(arg1)
            realm = realm and realm ~= "" and realm or GetNormalizedRealmName()
        end
        return name, realm
    end
    if type(arg1) == "string" then
        if arg1:find("-", nil, true) then
            name, realm = strsplit("-", arg1)
        else
            name = arg1 -- assume this is the name
        end
        if not realm or realm == "" then
            if type(arg2) == "string" and arg2 ~= "" then
                realm = arg2
            else
                realm = GetNormalizedRealmName() -- assume they are on our realm
            end
        end
    end
    return name, realm
end

---@param owner any
---@return string? name, string? realm, string? unit
local function GetLFGListInfo(owner)
    local resultID = owner.resultID
    if resultID then
        local searchResultInfo = C_LFGList.GetSearchResultInfo(resultID)
        local name, realm = GetNameRealm(searchResultInfo.leaderName)
        local faction = searchResultInfo.leaderFactionGroup
        return name, realm, nil
    end
    local memberIdx = owner.memberIdx
    if not memberIdx then
        return
    end
    local parent = owner:GetParent()
    if not parent then
        return
    end
    local applicantID = parent.applicantID
    if not applicantID then
        return
    end
    local fullName, _, _, level = C_LFGList.GetApplicantMemberInfo(applicantID, memberIdx)
    local name, realm = GetNameRealm(fullName)
    return name, realm, nil
end

---@param accountInfo BNetAccountInfo
---@return string? name, string? realm, string? unit
local function GetBNetAccountInfo(accountInfo)
    local gameAccountInfo = accountInfo.gameAccountInfo
    local characterName = gameAccountInfo.characterName
    local realmName = gameAccountInfo.realmName
    return characterName, realmName, nil
end

---@param owner any
---@param rootDescription ModifyMenuCallbackRootDescriptionPolyfill
---@param contextData? ModifyMenuCallbackRootDescriptionContextDataPolyfill
---@return string? name, string? realm, string? unit
local function GetNameRealmForMenu(owner, rootDescription, contextData)
    if not contextData then
        local tagType = VALID_TAGS[rootDescription.tag]
        if tagType == 1 then
            return GetLFGListInfo(owner)
        end
        return
    end
    local unit = contextData.unit
    local name, realm, level, faction ---@type string?, string?, number?, number?
    if unit and UnitExists(unit) then
        name, realm = GetNameRealm(unit)        
        return name, realm, unit
    end
    local accountInfo = contextData.accountInfo
    if accountInfo then
        name, realm, unit = GetBNetAccountInfo(accountInfo)
        if not realm then
            return -- HOTFIX: characters on classic when on retail will have their realm missing so this ensures we skip showing the dropdown menu unless we have the realm available
        end
        return name, realm, unit
    end
    name, realm, unit = GetNameRealm(contextData.name, contextData.server)
    return name, realm, unit
end

---@param rootDescription ModifyMenuCallbackRootDescriptionPolyfill
---@param contextData? ModifyMenuCallbackRootDescriptionContextDataPolyfill
local function IsValidMenu(rootDescription, contextData)
    if not contextData then
        local tagType = VALID_TAGS[rootDescription.tag]
        return not tagType or tagType == 1
    end
    local which = contextData.which
    return which and VALID_TYPES[which]
end

---@type ModifyMenuCallbackFuncPolyfill
local function OnMenuShow(menuFrame, description, context)
    if not IsValidMenu(description, context) then
        return
    end

    local name, realm, unit = GetNameRealmForMenu(menuFrame, description, context)

    if not name or not realm then
        return
    end

    local fullName = name.."-"..realm
    local storedData = DS_GetStoredData(fullName)
    if storedData == nil then
        return
    end

    description:CreateDivider()
    description:CreateTitle(addonName)
    description:CreateButton("Story", function() ShowHistoryFrame(fullName, storedData) end)
end

if ModifyMenu then
    for name, enabled in pairs(VALID_TYPES) do
        if enabled then
            local tag = format("MENU_UNIT_%s", name)
            ModifyMenu(tag, GenerateClosure(OnMenuShow))
        end
    end
    for tag, _ in pairs(VALID_TAGS) do
        ModifyMenu(tag, GenerateClosure(OnMenuShow))
    end
end

-- handler to process clicks on addon links
hooksecurefunc("SetItemRef", function(link)
    local linkType, addon, action, name, class, ilvl, mPlusRating = strsplit(":", link)
    if linkType == "addon" and addon == "DungeonStory" then
        if action == "Save" and name and class then
            local data = {
                {
                    name = name,
                    class = class,
                    equippedItemLevel = tonumber(ilvl) or 0,
                    mPlusRating = tonumber(mPlusRating) or 0
                }
            }
            ShowFeedbackFrame(data, nil)
        end
    end
end)

local function Main_OnEvent(self, event, ...)
    if event == "PLAYER_TARGET_CHANGED" then
        handleUnit("target")
    elseif event == "PLAYER_ENTERING_WORLD" then
        isRaiderIoInstalled = C_AddOns.IsAddOnLoaded("RaiderIO")
    elseif event == "ADDON_LOADED" then
        addonLoadedHandler(...)
    elseif event == "CHALLENGE_MODE_START" then
        StartChallengeMode()
    elseif event == "CHALLENGE_MODE_RESET" then
        ResetChallengeMode()
    elseif event == "GROUP_LEFT" then --technically it is the same as when we reset
        ResetChallengeMode()
    elseif event == "INSTANCE_ABANDON_VOTE_FINISHED" then
        AbandonVoteFinished(...)
    elseif event == "CHALLENGE_MODE_COMPLETED" then
        CompleteChallengeMode()
    elseif event == "CHALLENGE_MODE_DEATH_COUNT_UPDATED" then
        IncreaseDeathCount()
    elseif event == "GROUP_ROSTER_UPDATE" then
        GroupRosterUpdate()
    end
end

local main = CreateFrame("Frame")
main:RegisterEvent("ADDON_LOADED")
main:RegisterEvent("GROUP_JOINED")        -- I join a group
main:RegisterEvent("GROUP_FORMED")        -- I create a group
main:RegisterEvent("GROUP_ROSTER_UPDATE") -- Someone is invited/kicked/left/joined
main:RegisterEvent("GROUP_LEFT")          -- I leave a group
main:RegisterEvent("PLAYER_ENTERING_WORLD")
main:RegisterEvent("PLAYER_TARGET_CHANGED")
main:RegisterEvent("SAVED_VARIABLES_TOO_LARGE")
if not classic then
    main:RegisterEvent("CHALLENGE_MODE_START")
    main:RegisterEvent("CHALLENGE_MODE_RESET")
    main:RegisterEvent("CHALLENGE_MODE_DEATH_COUNT_UPDATED")
    main:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    main:RegisterEvent("INSTANCE_ABANDON_VOTE_FINISHED")
end
main:RegisterEvent("BOSS_KILL")
main:SetScript("OnEvent", Main_OnEvent)

SLASH_DUNGEONSTORY1 = "/dungeonstory"
SlashCmdList["DUNGEONSTORY"] = function(msg)
    if msg == "save" then
        local data = collectDataForScoring()
        ShowFeedbackFrame(data)
    else
        print("Available commands:")
        print("/dungeonstory save - show feedback frame")
    end
end

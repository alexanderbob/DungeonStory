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
local doMockData = false

local isRaiderIoInstalled = false
local classic = false
local isLFGFrameHooked = false
local dungeonState = { isActive = false, dungeonID = 0, startTime = 0, deathCount = 0, keystoneLevel = 0, party = {} } --[[@as DungeonState]]
local currentPlayerRealmName = ""
-- cached inspect data to reduce number of inspect requests
-- stores itemlevel and specialization
local inspectCache = {}
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

    for i = 1, MAX_BOSS_FRAMES do
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


local function ZOMGConfig(widget, event)
    AceGUI:Release(widget.userdata.parent)

    local f = AceGUI:Create("Frame")

    f:SetCallback("OnClose", function(widget, event)
        print("Closing")
        AceGUI:Release(widget)
    end)
    f:SetTitle("ZOMG Config!")
    f:SetStatusText("Status Bar")
    f:SetLayout("Fill")

    local maingroup = AceGUI:Create("DropdownGroup")
    maingroup:SetLayout("Fill")
    maingroup:SetGroupList({ Addons = "Addons !!", Zomg = "Zomg Addons" })
    maingroup:SetGroup("Addons")
    maingroup:SetTitle("")

    f:AddChild(maingroup)

    local tree = { "A", "B", "C", "D", B = { "B1", "B2", B1 = { "B11", "B12" } }, C = { "C1", "C2", C1 = { "C11", "C12" } } }
    local text = {
        A = "Option 1",
        B = "Option 2",
        C = "Option 3",
        D = "Option 4",
        J = "Option 10",
        K = "Option 11",
        L = "Option 12",
        B1 = "Option 2-1",
        B2 = "Option 2-2",
        B11 = "Option 2-1-1",
        B12 = "Option 2-1-2",
        C1 = "Option 3-1",
        C2 = "Option 3-2",
        C11 = "Option 3-1-1",
        C12 = "Option 3-1-2"
    }
    local t = AceGUI:Create("TreeGroup")
    t:SetLayout("Fill")
    t:SetTree(tree, text)
    maingroup:AddChild(t)

    local tab = AceGUI:Create("TabGroup")
    tab:SetTabs({ "A", "B", "C", "D" }, { A = "Yay", B = "We", C = "Have", D = "Tabs" })
    tab:SetLayout("Fill")
    tab:SelectTab(1)
    t:AddChild(tab)

    local component = AceGUI:Create("DropdownGroup")
    component:SetLayout("Fill")
    component:SetGroupList({ Blah = "Blah", Splat = "Splat" })
    component:SetGroup("Blah")
    component:SetTitle("Choose Componet")

    tab:AddChild(component)

    local more = AceGUI:Create("DropdownGroup")
    more:SetLayout("Fill")
    more:SetGroupList({ ButWait = "But Wait!", More = "Theres More" })
    more:SetGroup("More")
    more:SetTitle("And More!")

    component:AddChild(more)

    local sf = AceGUI:Create("ScrollFrame")
    sf:SetLayout("Flow")
    more:AddChild(sf)
    local stuff = AceGUI:Create("Heading")
    stuff:SetText("Omg Stuff Here")
    stuff.width = "fill"
    sf:AddChild(stuff)

    for i = 1, 10 do
        local edit = AceGUI:Create("EditBox")
        edit:SetText("")
        edit:SetWidth(200)
        edit:SetLabel("Stuff!")
        edit:SetCallback("OnEnterPressed", function(widget, event, text) widget:SetLabel(text) end)
        edit:SetCallback("OnTextChanged", function(widget, event, text) print(text) end)
        sf:AddChild(edit)
    end

    f:Show()
end

local function GroupA(content)
    content:ReleaseChildren()

    local sf = AceGUI:Create("ScrollFrame")
    sf:SetLayout("Flow")

    local edit = AceGUI:Create("EditBox")
    edit:SetText("Testing")
    edit:SetWidth(200)
    edit:SetLabel("Group A Option")
    edit:SetCallback("OnEnterPressed", function(widget, event, text) widget:SetLabel(text) end)
    edit:SetCallback("OnTextChanged", function(widget, event, text) print(text) end)
    sf:AddChild(edit)

    local slider = AceGUI:Create("Slider")
    slider:SetLabel("Group A Slider")
    slider:SetSliderValues(0, 1000, 5)
    slider:SetDisabled(false)
    sf:AddChild(slider)

    local zomg = AceGUI:Create("Button")
    zomg.userdata.parent = content.userdata.parent
    zomg:SetText("Zomg!")
    zomg:SetCallback("OnClick", ZOMGConfig)
    sf:AddChild(zomg)

    local heading1 = AceGUI:Create("Heading")
    heading1:SetText("Heading 1")
    heading1.width = "fill"
    sf:AddChild(heading1)

    for i = 1, 5 do
        local radio = AceGUI:Create("CheckBox")
        radio:SetLabel("Test Check " .. i)
        radio:SetCallback("OnValueChanged",
            function(widget, event, value) print(value and "Check " .. i .. " Checked" or "Check " .. i .. " Unchecked") end)
        sf:AddChild(radio)
    end

    local heading2 = AceGUI:Create("Heading")
    heading2:SetText("Heading 2")
    heading2.width = "fill"
    sf:AddChild(heading2)

    for i = 1, 5 do
        local radio = AceGUI:Create("CheckBox")
        radio:SetLabel("Test Check " .. i + 5)
        radio:SetCallback("OnValueChanged",
            function(widget, event, value) print(value and "Check " .. i .. " Checked" or "Check " .. i .. " Unchecked") end)
        sf:AddChild(radio)
    end

    local heading1 = AceGUI:Create("Heading")
    heading1:SetText("Heading 1")
    heading1.width = "fill"
    sf:AddChild(heading1)

    for i = 1, 5 do
        local radio = AceGUI:Create("CheckBox")
        radio:SetLabel("Test Check " .. i)
        radio:SetCallback("OnValueChanged",
            function(widget, event, value) print(value and "Check " .. i .. " Checked" or "Check " .. i .. " Unchecked") end)
        sf:AddChild(radio)
    end

    local heading2 = AceGUI:Create("Heading")
    heading2:SetText("Heading 2")
    heading2.width = "fill"
    sf:AddChild(heading2)

    for i = 1, 5 do
        local radio = AceGUI:Create("CheckBox")
        radio:SetLabel("Test Check " .. i + 5)
        radio:SetCallback("OnValueChanged",
            function(widget, event, value) print(value and "Check " .. i .. " Checked" or "Check " .. i .. " Unchecked") end)
        sf:AddChild(radio)
    end

    content:AddChild(sf)
end

local function GroupB(content)
    content:ReleaseChildren()
    local sf = AceGUI:Create("ScrollFrame")
    sf:SetLayout("Flow")

    local check = AceGUI:Create("CheckBox")
    check:SetLabel("Group B Checkbox")
    check:SetCallback("OnValueChanged", function(widget, event, value) print(value and "Checked" or "Unchecked") end)

    local dropdown = AceGUI:Create("Dropdown")
    dropdown:SetText("Test")
    dropdown:SetLabel("Group B Dropdown")
    dropdown.list = { "Test", "Test2" }
    dropdown:SetCallback("OnValueChanged", function(widget, event, value) print(value) end)

    sf:AddChild(check)
    sf:AddChild(dropdown)
    content:AddChild(sf)
end

local function OtherGroup(content)
    content:ReleaseChildren()

    local sf = AceGUI:Create("ScrollFrame")
    sf:SetLayout("Flow")

    local check = AceGUI:Create("CheckBox")
    check:SetLabel("Test Check")
    check:SetCallback("OnValueChanged",
        function(widget, event, value) print(value and "CheckButton Checked" or "CheckButton Unchecked") end)

    sf:AddChild(check)

    local inline = AceGUI:Create("InlineGroup")
    inline:SetLayout("Flow")
    inline:SetTitle("Inline Group")
    inline.width = "fill"

    local heading1 = AceGUI:Create("Heading")
    heading1:SetText("Heading 1")
    heading1.width = "fill"
    inline:AddChild(heading1)

    for i = 1, 10 do
        local radio = AceGUI:Create("CheckBox")
        radio:SetLabel("Test Radio " .. i)
        radio:SetCallback("OnValueChanged",
            function(widget, event, value) print(value and "Radio " .. i .. " Checked" or "Radio " .. i .. " Unchecked") end)
        radio:SetType("radio")
        inline:AddChild(radio)
    end

    local heading2 = AceGUI:Create("Heading")
    heading2:SetText("Heading 2")
    heading2.width = "fill"
    inline:AddChild(heading2)

    for i = 1, 10 do
        local radio = AceGUI:Create("CheckBox")
        radio:SetLabel("Test Radio " .. i)
        radio:SetCallback("OnValueChanged",
            function(widget, event, value) print(value and "Radio " .. i .. " Checked" or "Radio " .. i .. " Unchecked") end)
        radio:SetType("radio")
        inline:AddChild(radio)
    end


    sf:AddChild(inline)
    content:AddChild(sf)
end

local function SelectGroup(widget, event, value)
    if value == "A" then
        GroupA(widget)
    elseif value == "B" then
        GroupB(widget)
    else
        OtherGroup(widget)
    end
end


local function TreeWindow(content)
    content:ReleaseChildren()

    local tree = {
        {
            value = "A",
            text = "Alpha"
        },
        {
            value = "B",
            text = "Bravo",
            children = {
                {
                    value = "C",
                    text = "Charlie",
                },
                {
                    value = "D",
                    text = "Delta",
                    children = {
                        {
                            value = "E",
                            text = "Echo",
                        }
                    }
                },
            }
        },
        {
            value = "F",
            text = "Foxtrot",
        },
    }
    local t = AceGUI:Create("TreeGroup")
    t:SetLayout("Fill")
    t:SetTree(tree)
    t:SetCallback("OnGroupSelected", SelectGroup)
    content:AddChild(t)
    SelectGroup(t, "OnGroupSelected", "A")
end

local function TabWindow(content)
    content:ReleaseChildren()
    local tab = AceGUI:Create("TabGroup")
    tab.userdata.parent = content.userdata.parent
    tab:SetTabs({ "A", "B", "C", "D" }, { A = "Alpha", B = "Bravo", C = "Charlie", D = "Deltaaaaaaaaaaaaaa" })
    tab:SetTitle("Tab Group")
    tab:SetLayout("Fill")
    tab:SetCallback("OnGroupSelected", SelectGroup)
    tab:SelectTab(1)
    content:AddChild(tab)
end


function TestFrame()
    local f = AceGUI:Create("Frame")
    f:SetCallback("OnClose", function(widget, event)
        print("Closing")
        AceGUI:Release(widget)
    end)
    f:SetTitle("AceGUI Prototype")
    f:SetStatusText("Root Frame Status Bar")
    f:SetLayout("Fill")

    local maingroup = AceGUI:Create("DropdownGroup")
    maingroup.userdata.parent = f
    maingroup:SetLayout("Fill")
    maingroup:SetGroupList({ Tab = "Tab Frame", Tree = "Tree Frame" })
    maingroup:SetGroup("Tab")
    maingroup:SetTitle("Select Group Type")
    maingroup:SetCallback("OnGroupSelected", function(widget, event, value)
        widget:ReleaseChildren()
        if value == "Tab" then
            TabWindow(widget)
        else
            TreeWindow(widget)
        end
    end)

    TabWindow(maingroup)
    f:AddChild(maingroup)


    f:Show()
end

---comment
---@param fullName string player full name (Name-Realm)
---@return DungeonStorySinglePlayerData | nil
function DS_GetStoredData(fullName)
    if doMockData then
        return {
            {
                time = 1700000000,
                ilvl = 200,
                mPlusRating = 1500,
                comment = "Great player!",
                score = 3
            },
            {
                time = 1700100000,
                ilvl = 202,
                mPlusRating = 1520,
                comment = "Good job",
                score = 1
            },
            {
                time = 1700200000,
                ilvl = 199,
                mPlusRating = 1480,
                comment = "Could be better",
                score = -1
            }
        }
    end
    return DungeonStoryPlayers[fullName]
end

---comment
---@param timestamp number
---@return string|osdate
function FormatDateTime(timestamp)
    timestamp = timestamp
    return date("%Y-%m-%d %H:%M:%S", timestamp)
end

---comment
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

---comment
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

---comment
---@param data PlayerDataFeedback
---@return function
local function feedbackCommentCallback(data)
    return function(widget, event, text)
        data.comment = text
    end
end

---comment
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

---comment
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

---comment
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

---comment
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

---comment
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

---comment
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

---comment
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

---comment
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

    -- DevTools_Dump(data)
    for i, playerData in pairs(data) do
        -- casting PlayerData to PlayerDataFeedback to allow adding score and comment fields
        groupPlayerFeedback(sf, playerData --[[@as PlayerDataFeedback]])
    end

    f:AddChild(sf)
    f:Show()
end

---comment
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

---comment
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

    -- DevTools_Dump(data)
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

---comment
---@param tooltip any
---@param data DungeonStorySinglePlayerData
---@param unit UnitToken
local function AddTooltipInfo(tooltip, data, unit)
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

-- TestFrame()

if not classic then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
        local _, unit = tooltip:GetUnit()
        if unit then
            local isPlayer = UnitIsPlayer(unit)
            if isPlayer then
                local name, realmName = UnitFullName(unit)
                local fullName = name.."-"..(realmName or currentPlayerRealmName)
                if DungeonStoryPlayers[fullName] then
                    AddTooltipInfo(tooltip, DungeonStoryPlayers[fullName], unit)
                end
            end
        end
    end)
end

---comment
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

---comment
---@param unit UnitToken
---@return PlayerData | nil
local function collectUnitInfo(unit)
    if not UnitIsPlayer(unit) then
        print(string.format("Unit '%s' is not a player", unit))
        return nil
    end

    local name, server = UnitFullName(unit)
    local fileName = UnitClassBase(unit)
    local ratingSummary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary(unit)
    local mPlusRating = 0
    if ratingSummary and ratingSummary.currentSeasonScore then
        mPlusRating = ratingSummary.currentSeasonScore
    end

    server = server or currentPlayerRealmName
    -- very unreliable, can be 0 when not inspected
    local equippedItemLevel = C_PaperDollInfo.GetInspectItemLevel(unit)
    return {
        name = name.."-"..server,
        class = fileName,
        equippedItemLevel = equippedItemLevel or 0,
        mPlusRating = mPlusRating
    }
end

---comment
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

---comment
---@return PlayerData[]
local function retrieveRaidInfo()
    local data = {}
    -- the only way to get raid members is to iterate over raid1, raid2, ...
    -- GetNumGroupMembers() only return total number
    -- we don't know raid composition and which groups are actually filled
    for i = 1, 40 do
        local unit = "raid" .. i
        if UnitExists(unit) and not UnitIsPlayer(unit) == true then
            local unitInfo = collectUnitInfo(unit, i)
            table.insert(data, unitInfo)
        else
            print("Unit is player or does not exist: " .. unit)
            DevTools_Dump(unit)

            -- still try to collect info?
            local unitInfo = collectUnitInfo(unit, i)
            table.insert(data, unitInfo)
        end        
    end
    return data
end

---comment
---@return PlayerData[]
local function retrieveGroupInfo()
    local data = {}
    local numMembers = GetNumSubgroupMembers()
    for i = 1, numMembers do
        local unit = "party" .. i
        if UnitIsPlayer(unit) ~= true then
            local unitInfo = collectUnitInfo(unit)
            if unitInfo ~= nil then
                table.insert(data, unitInfo)
            end
        else
            print("Unit is player or does not exist: " .. unit)
            DevTools_Dump(unit)

            -- still try to collect info?
            local unitInfo = collectUnitInfo(unit, i)
            table.insert(data, unitInfo)
        end
    end
    return data
end

---comment
---@return PlayerData[]
local function collectDataForScoring()
    local data = {}
    if doMockData then
        data = {
            {
                name = "PlayerOne-Realm",
                class = "WARRIOR",
                equippedItemLevel = 200,
                mPlusRating = 1500
            },
            {
                name = "PlayerTwo-Realm",
                class = "MAGE",
                equippedItemLevel = 195,
                mPlusRating = 1400
            },
            {
                name = "PlayerThree-Realm",
                class = "DRUID",
                equippedItemLevel = 198,
                mPlusRating = 1450
            },
            {
                name = "PlayerFour-Realm",
                class = "DEATHKNIGHT",
                equippedItemLevel = 777,
                mPlusRating = 6969
            }
        }
        return data
    end

    if (IsInRaid()) then
        data = retrieveRaidInfo()
    else
        data = retrieveGroupInfo()
    end
    return data
end

---comment
---@param fullName string
---@return number | nil, number | nil
local function GatherPlayerStats(fullName)
    -- print("Collecting stats for " .. fullName)
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

---comment
---@param member Frame
---@param id number applicantID
---@param index number memberIndex
local function UpdateApplicantMember(member, id, index)
    local name = C_LFGList.GetApplicantMemberInfo(id, index)
    if name == nil then return end
    local totalPositive, totalNegative = GatherPlayerStats(name)
    if totalPositive == nil and totalNegative == nil then
        return
    end

    local negativeScore = GetFeedbackHexColors(-3)
    local positiveScore = GetFeedbackHexColors(3)
    member.Rating:SetText(string.format("%s %s%d|r%s%d|r", member.Rating:GetText(), negativeScore, totalNegative, positiveScore, totalPositive))
    PlaySound(SOUNDKIT.MAP_PING)
end

---comment
---@param searchResultRow any
---@param numMembers number
---@param realmsToProbe string[]
local function UpdateSearchResultEntry(searchResultRow, numMembers, realmsToProbe)
    local totalPositive, totalNegative = 0, 0
    for i = 1, numMembers do
        local memberInfo = C_LFGList.GetSearchResultPlayerInfo(searchResultRow.resultID, i)
        if memberInfo and memberInfo.name then
            for j = 1, #realmsToProbe do
                local realm = realmsToProbe[j]
                local nameToProbe = memberInfo.name
                if realm and realm ~= "" and not string.find(nameToProbe, "-") then
                    nameToProbe = nameToProbe .. "-" .. realm
                end

                local memberPositive, memberNegative = GatherPlayerStats(nameToProbe)
                totalPositive = totalPositive + (memberPositive or 0)
                totalNegative = totalNegative + (memberNegative or 0)
            end
        end
    end

    if (totalPositive == 0 and totalNegative == 0) then
        return
    end

    local negativeScore = GetFeedbackHexColors(-3)
    local positiveScore = GetFeedbackHexColors(3)
    local currentText = searchResultRow.Name:GetText()
    searchResultRow.Name:SetText(string.format("%s %s%d|r%s%d|r", currentText, negativeScore, totalNegative, positiveScore, totalPositive))
    searchResultRow:SetWidth(400)
    PlaySound(SOUNDKIT.MAP_PING)
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
    -- DevTools_Dump(dungeonState)
end

local function ResetChallengeMode()
    ResetCurrentDungeonState()
    print("Challenge mode reset")
end

---comment
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

---comment
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

local function TryInitLFG()
    if isLFGFrameHooked then return end

    local viewer = LFGListFrame.ApplicationViewer -- My group applicants viewer
    local searchPanel = LFGListFrame.SearchPanel -- Search results panel
    if not viewer or not searchPanel then return end

    isLFGFrameHooked = true

    -- Applicants to my group
    if LFGListApplicationViewer_UpdateApplicantMember then
        hooksecurefunc("LFGListApplicationViewer_UpdateApplicantMember", function(member, id, index)
            UpdateApplicantMember(member, id, index)
        end)
    end

    -- Search results
    if LFGListSearchEntry_Update then
        hooksecurefunc("LFGListSearchEntry_Update", function(entity)
            local resultInfo = C_LFGList.GetSearchResultInfo(entity.resultID)
            if not resultInfo then return end
            -- only party leader names have a realm suffix
            -- for all remaining party members we are supposed to best guess their realm
            -- try probing party leader realm, or current player realm
            local realmsToProbe = {}
            table.insert(realmsToProbe, currentPlayerRealmName)
            if resultInfo.leaderName and string.find(resultInfo.leaderName, "-") then
                local _, realm = strsplit("-", resultInfo.leaderName)
                if realm and realm ~= "" and realm ~= currentPlayerRealmName then
                    table.insert(realmsToProbe, realm)
                end
            end
            UpdateSearchResultEntry(entity, resultInfo.numMembers, realmsToProbe)
        end)
    end
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
        print(string.format("name: %s, class: %s, ilvl: %s, mPlusRating: %s", name, class, ilvl,
            mPlusRating))
        if action == "Save" then
            local data = {}
            table.insert(data,
                {
                    name = name,
                    class = class,
                    equippedItemLevel = tonumber(ilvl),
                    mPlusRating = tonumber(mPlusRating)
                })
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
    else
        print("Unhandled event: " .. event)
    end
end

local main = CreateFrame("Frame")
-- main:SetScript('OnUpdate', fupdate) -- too expensive to run every frame
main:RegisterEvent("ADDON_LOADED")
main:RegisterEvent("GROUP_JOINED")        -- I join a group
main:RegisterEvent("GROUP_FORMED")        -- I create a group
main:RegisterEvent("GROUP_ROSTER_UPDATE") -- Someone is invited/kicked/left/joined
main:RegisterEvent("GROUP_LEFT")          -- I leave a group
main:RegisterEvent("PLAYER_ENTERING_WORLD")
main:RegisterEvent("PLAYER_TARGET_CHANGED")
main:RegisterEvent("SAVED_VARIABLES_TOO_LARGE")
--main:RegisterEvent("INSPECT_READY") -- should handle inspect to cache players specialization and ilvl
if not classic then main:RegisterEvent("CHALLENGE_MODE_START") end
if not classic then main:RegisterEvent("CHALLENGE_MODE_RESET") end
if not classic then main:RegisterEvent("CHALLENGE_MODE_DEATH_COUNT_UPDATED") end
if not classic then main:RegisterEvent("CHALLENGE_MODE_KEYSTONE_SLOTTED") end
if not classic then main:RegisterEvent("CHALLENGE_MODE_LEAVER_TIMER_STARTED") end
if not classic then main:RegisterEvent("CHALLENGE_MODE_LEAVER_TIMER_ENDED") end
if not classic then main:RegisterEvent("CHALLENGE_MODE_COMPLETED") end
if not classic then main:RegisterEvent("INSTANCE_ABANDON_VOTE_FINISHED") end
main:RegisterEvent("BOSS_KILL")
main:SetScript("OnEvent", Main_OnEvent)

SLASH_DUNGEONSTORY1 = "/dungeonstory"
SlashCmdList["DUNGEONSTORY"] = function(msg)
    if msg == "test" then
        TestFrame()
    elseif msg == "save" then
        local data = collectDataForScoring()
        ShowFeedbackFrame(data)
    elseif msg == "debug" then
        doMockData = not doMockData
    else
        print("Available commands:")
        print("/dungeonstory test - show test frame")
        print("/dungeonstory save - show feedback frame")
    end
end

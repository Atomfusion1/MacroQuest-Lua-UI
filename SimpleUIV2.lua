--[[ Simple MQ Lua UI 




]]

local mq = require 'mq'
require 'ImGui'

-- GUI control variables
local openGUI = true
local shouldDrawGUI = true
-- Fade windows like EQ 
local isWindowHovered = false
local StartAlphaTimer = os.clock()
local AlphaTimerSeconds = 3
-- Setup ImGui Flag
local SetWindowFlags = bit32.bor(ImGuiWindowFlags.NoFocusOnAppearing, ImGuiWindowFlags.NoBringToFrontOnFocus)
-- ImGui Const Flags 
local SetWindowFlagsOff = bit32.bor(ImGuiWindowFlags.NoFocusOnAppearing, ImGuiWindowFlags.NoBringToFrontOnFocus)
local SetWindowFlagsOn = bit32.bor(ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.NoFocusOnAppearing, ImGuiWindowFlags.NoBringToFrontOnFocus)

-- Window Transparency increases if mouse is not over it after AlphaTimerSeconds
local function AlphaIfMouseOverWindow()
    -- This detects mouse over ImGui window with or without button pressed 
    if ImGui.IsWindowHovered(ImGuiFocusedFlags.RootAndChildWindows) or
            ImGui.IsAnyItemHovered() and ImGui.IsMouseDown(0) or
                ImGui.IsAnyItemHovered() and ImGui.IsMouseReleased(0)
    then
        -- Turn transparency off 
        isWindowHovered = true
        StartAlphaTimer = os.clock()
        SetWindowFlags = SetWindowFlagsOff
        
    else
        -- Turn transparency on 
        if os.clock() - StartAlphaTimer > AlphaTimerSeconds then
            isWindowHovered = false
            SetWindowFlags = SetWindowFlagsOn
        end
    end
end

-- Setup buttons in a row setcursor to x, y and offset between buttons
local function DrawButtonRow(x, y, buttonLength, buttonWidth, offset)
    ImGui.SetCursorPos(x, y)
    if ImGui.Button("Stay", buttonLength, buttonWidth) then mq.cmd('/echo Stay') end
    ImGui.SameLine()
    ImGui.SetCursorPosX(ImGui.GetCursorPosX()  + offset)
    if ImGui.Button("OTM", buttonLength, buttonWidth) then mq.cmd('/echo Follow') end
    ImGui.SameLine()
    ImGui.SetCursorPosX(ImGui.GetCursorPosX()  + offset)
    if ImGui.Button("Buff", buttonLength, buttonWidth) then mq.cmd("/echo Lets Buff") end
end

-- Setup buttons in a column setcursor to x, y and offset between buttons
local function DrawButtonColumn(x, y, buttonLength, buttonWidth, offset)
    ImGui.SetCursorPos(x, y)
    if ImGui.Button("Button4", buttonLength, buttonWidth) then mq.cmd("/echo Button 4") end
    ImGui.SetCursorPos(x, ImGui.GetCursorPosY() + offset)
    if ImGui.Button("Button5", buttonLength, buttonWidth) then mq.cmd("/echo Button 5") end
    ImGui.SetCursorPos(x, ImGui.GetCursorPosY() + offset)
    if ImGui.Button("Button6", buttonLength, buttonWidth) then print("Button 6") end
    ImGui.SetCursorPos(x, ImGui.GetCursorPosY() + offset)
    if ImGui.Button("Button7", buttonLength, buttonWidth) then print("Button 7") end
end

-- Draw progress bar 
local function DrawProgressBar(x, y, barLength, barWidth, displayName, displayPctHPs)
    local unitInterval = displayPctHPs/100
    ImGui.SetCursorPos(x, y)
    ImGui.ProgressBar(unitInterval, barLength, barWidth, displayName..': '..displayPctHPs..'%')
    ImGui.PopStyleColor(2)
end

-- Print target information to screen 
local function DisplayTargetTextInfo(x, y, fontScale)
    ImGui.SetCursorPos(x, y)
    ImGui.SetWindowFontScale(fontScale)
    ImGui.Text("LVL: "..TargetLevel.." Class: "..TargetShortNameClass.." Dist: "..TargetDistance)
    ImGui.SetWindowFontScale(1)
end

-- Layout Health and Mana Bars
local function DrawHealthManaBars(x, y, barLength, barWidth, barIteration, name, pctHPs, pctMana)
    local unitIntervalHP = pctHPs/100
    local unitIntervalMana = pctMana/100
    local pushColor = ImGui.PushStyleColor
    local fontSize = ImGui.SetWindowFontScale
    local selectGMember =  ImGui.IsItemHovered() and ImGui.IsMouseReleased(0) 
    -- Setup health bars and %
    pushColor(ImGuiCol.PlotHistogram, 1 - unitIntervalHP, unitIntervalHP-.4, .2, 1)
    pushColor(ImGuiCol.Text, 0.8, 0.8, 0.8, 1)
    DrawProgressBar(x, barIteration*30+y-barIteration*5, barLength, barWidth, name, pctHPs)
    -- Target player if clicked on 
    if ImGui.IsItemHovered() and ImGui.IsMouseReleased(0) then
        mq.cmdf('/target %s pc', name)
    end
    fontSize(.4)
    -- Setup mana bars and %
    pushColor(ImGuiCol.PlotHistogram, .2, .2, unitIntervalMana, 1)
    pushColor(ImGuiCol.Text, 1, 1, 1, 1)
    DrawProgressBar(x, barIteration*30+y+15-barIteration*5, barLength, barWidth*.33, " ", pctMana)
    -- Target player if clicked on Health or Mana bar 
    if ImGui.IsItemHovered() and ImGui.IsMouseReleased(0) then
        mq.cmdf('/target %s pc', name)
    end
    -- Set window font to 1 so that the next window is normal Text
    fontSize(1)
end

-- Setup targeting information 
local function LayoutTargetInfo(x, y)
    -- Get target information 
    local TargetTLO = mq.TLO.Target
    TargetPctHPs = TargetTLO.PctHPs() or 0
    TargetDisplayName = TargetTLO.DisplayName() or 'No Target'
    TargetLevel = TargetTLO.Level() or '00'
    TargetDistance = TargetTLO.Distance3D.Int() or '00'
    TargetShortNameClass = TargetTLO.Class.ShortName() or '     '
    if TargetShortNameClass == "UNKNOWN CLASS" then TargetShortNameClass = 'UNK' end
    -- Setup colors and style 
    ImGui.PushStyleColor(ImGuiCol.PlotHistogram, 1 - TargetPctHPs/100, TargetPctHPs/100-.5, .5, 1)
    ImGui.PushStyleColor(ImGuiCol.Text, 0, 0, 0, 1)
    -- Draw Bar 
    DrawProgressBar(x, y, 180, 20, TargetDisplayName, TargetPctHPs)
    DisplayTargetTextInfo(5, 70, 1) 
end

-- Setup and draw group health bars
local function LayoutHealthBars(x, y, barLength, barWidth)
    local GroupNumber = mq.TLO.Group() or 0
    if GroupNumber ~= 0 then
        -- Loop to display all group members 
        for i=0,GroupNumber do
            -- Get group members current condition
            local groupMember = mq.TLO.Group.Member(i)
            DrawHealthManaBars(x, 100, barLength, barWidth, i, groupMember.Name() or " ", groupMember.PctHPs() or 0, groupMember.PctMana() or 0)
        end
        -- If no group then display you 
    else
        -- Get your current condition 
        local MyCondition = mq.TLO.Me
        DrawHealthManaBars(x, 100, barLength, barWidth, 0, MyCondition.Name(), MyCondition.PctHPs(), MyCondition.PctMana())
    end
end

-- Set Icons and Connect to MQ
local function LayoutRowIcons(x, y, offset)
    local myState = mq.TLO.Me
    local setIcons = {'\xee\x9f\xbd', '\xee\x95\xa6', '\xef\x8b\x9c', '\xef\x89\xa1'}
    local myCondition = {myState.Combat(), myState.Moving(), myState.Casting(), myState.Sitting()}
    ImGui.SetCursorPos(x, y)
    for i=1, 4 do
        if myCondition[i] then ImGui.TextColored(1, 0, 0, 1, setIcons[i]) else
            ImGui.TextColored(0, 1, 1, 1, setIcons[i])
        end
        ImGui.SameLine()
        ImGui.SetCursorPos(ImGui.GetCursorPosX() + offset, y)
    end
end

-- ImGui main function for rendering the UI window
local GroupWindowLayout = function()
    if isWindowHovered then ImGui.SetNextWindowBgAlpha(1) else ImGui.SetNextWindowBgAlpha(.1) end
    openGUI, shouldDrawGUI = ImGui.Begin('Group Window', openGUI, SetWindowFlags)
    if shouldDrawGUI then
        AlphaIfMouseOverWindow()
        DrawButtonRow(5, 25, 40, 20, 6)
        DrawButtonColumn(190, 25, 60, 20, 10)
        LayoutTargetInfo(5, 50)
        LayoutHealthBars(5, 100, 180, 15)
        LayoutRowIcons(5, 250, 20)
    end
    ImGui.End()
end

mq.imgui.init('GroupWindowLayout', GroupWindowLayout)

while openGUI do
    mq.delay(100)
  end
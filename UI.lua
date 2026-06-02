local UI = {}
CrieffList.UI = UI

local PANEL_WIDTH = 260
local ROW_HEIGHT = 26
local ROW_LEFT_PAD = 12
local ROW_RIGHT_PAD = 12
local HEADER_HEIGHT = 32
local FOOTER_HEIGHT = 12
local HINT_HEIGHT = 36
local HINT_DURATION = 8

local panel
local rows = {}

local function ClassColor(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

local function PickAnchorTarget(default)
    local rio = _G.RaiderIO_ProfileTooltip
    if rio and rio.IsShown and rio:IsShown() and rio:GetRight() and default:GetRight() and rio:GetRight() > default:GetRight() then
        return rio
    end
    local pgf = _G.PremadeGroupsFilterDialog
    if pgf and pgf.IsShown and pgf:IsShown() and pgf:GetRight() and default:GetRight() and pgf:GetRight() > default:GetRight() then
        return pgf
    end
    return default
end

local function UpdateAnchor(f)
    local parent = f:GetParent() or UIParent
    local target = PickAnchorTarget(parent)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", target, "TOPRIGHT", 5, 0)
end

local function CreatePanel()
    local parent = LFGListFrame or UIParent
    local f = CreateFrame("Frame", "CrieffListSidePanel", parent, "BackdropTemplate")
    f:SetSize(PANEL_WIDTH, 200)
    f:SetFrameStrata(parent:GetFrameStrata())
    f:SetFrameLevel((parent:GetFrameLevel() or 0) + 5)
    f:Hide()

    f.UpdateAnchor = UpdateAnchor
    UpdateAnchor(f)

    local rio = _G.RaiderIO_ProfileTooltip
    if rio and rio.HookScript and not f._rioHooked then
        rio:HookScript("OnShow", function() if f:IsShown() then UpdateAnchor(f) end end)
        rio:HookScript("OnHide", function() if f:IsShown() then UpdateAnchor(f) end end)
        rio:HookScript("OnSizeChanged", function() if f:IsShown() then UpdateAnchor(f) end end)
        f._rioHooked = true
    end

    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
    end

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -12)
    title:SetText("Party Keystones")
    title:SetTextColor(1, 0.82, 0)
    f.title = title

    local refresh = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    refresh:SetSize(70, 20)
    refresh:SetPoint("TOPRIGHT", -12, -10)
    refresh:SetText("Refresh")
    refresh:SetScript("OnClick", function()
        if CrieffList.Keystones and CrieffList.Keystones.RefreshAll then
            CrieffList.Keystones.RefreshAll()
        end
        UI.Render()
    end)
    f.refresh = refresh

    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("BOTTOMLEFT", 10, 8)
    hint:SetPoint("BOTTOMRIGHT", -10, 8)
    hint:SetJustifyH("CENTER")
    hint:SetTextColor(1, 0.82, 0)
    hint:SetWordWrap(true)
    hint:Hide()
    f.hint = hint
    f.hintTimer = 0

    f:SetScript("OnUpdate", function(self, elapsed)
        if self.hint:IsShown() then
            self.hintTimer = self.hintTimer - elapsed
            if self.hintTimer <= 0 then
                self.hint:Hide()
                UI.Render()
            end
        end
    end)

    return f
end

local function GetOrCreateRow(index)
    if rows[index] then return rows[index] end
    local row = CreateFrame("Button", nil, panel)
    row:SetHeight(ROW_HEIGHT)

    local hi = row:CreateTexture(nil, "HIGHLIGHT")
    hi:SetAllPoints()
    hi:SetColorTexture(1, 1, 1, 0.10)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("LEFT", 0, 0)
    row.name:SetWidth(90)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetPoint("LEFT", row.name, "RIGHT", 4, 0)

    row.dungeon = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.dungeon:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
    row.dungeon:SetPoint("RIGHT", row, "RIGHT", -28, 0)
    row.dungeon:SetJustifyH("LEFT")
    row.dungeon:SetWordWrap(false)

    row.level = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.level:SetPoint("RIGHT", 0, 0)
    row.level:SetJustifyH("RIGHT")

    row:SetScript("OnClick", function(self)
        if self.entry and not self.entry.noKey and self.entry.mapID and self.entry.level then
            CrieffList.GroupFinder.ApplyToCurrentPanel(self.entry.mapID, self.entry.level)
        end
    end)

    rows[index] = row
    return row
end

function UI.Render()
    if not panel then panel = CreatePanel() end

    local entries = CrieffList.Keystones and CrieffList.Keystones.GetAll() or {}
    local shown = 0
    for i, entry in ipairs(entries) do
        local row = GetOrCreateRow(i)
        row.entry = entry
        row:Show()
        shown = shown + 1

        local r, g, b = ClassColor(entry.class)
        local namePrefix = entry.isSelf and "|cff999999(you)|r " or ""
        row.name:SetText(namePrefix .. (entry.name or "?"))
        row.name:SetTextColor(r, g, b)

        if entry.texture then
            row.icon:SetTexture(entry.texture)
            row.icon:Show()
        else
            row.icon:Hide()
        end

        if entry.noKey then
            row.dungeon:SetText("no key")
            row.dungeon:SetTextColor(0.6, 0.6, 0.6)
            row.level:SetText("")
            row:Disable()
            row:EnableMouse(false)
        else
            row.dungeon:SetText(entry.dungeonName or ("map " .. tostring(entry.mapID)))
            row.dungeon:SetTextColor(1, 1, 1)
            row.level:SetText("+" .. tostring(entry.level))
            row.level:SetTextColor(1, 0.82, 0)
            row:Enable()
            row:EnableMouse(true)
        end

        row:ClearAllPoints()
        row:SetPoint("LEFT", panel, "LEFT", ROW_LEFT_PAD, 0)
        row:SetPoint("RIGHT", panel, "RIGHT", -ROW_RIGHT_PAD, 0)
        row:SetPoint("TOP", panel, "TOP", 0, -(HEADER_HEIGHT + (i - 1) * ROW_HEIGHT))
    end

    for i = shown + 1, #rows do
        rows[i]:Hide()
        rows[i].entry = nil
    end

    local height = HEADER_HEIGHT + math.max(shown, 1) * ROW_HEIGHT + FOOTER_HEIGHT
    if panel.hint:IsShown() then height = height + HINT_HEIGHT end
    panel:SetHeight(height)
end

function UI.OnEntryCreationShown()
    if not panel then panel = CreatePanel() end
    if CrieffList.Keystones and CrieffList.Keystones.RefreshAll then
        CrieffList.Keystones.RefreshAll()
    end
    UpdateAnchor(panel)
    UI.Render()
    panel:Show()
end

function UI.OnEntryCreationHidden()
    if panel then panel:Hide() end
end

local testPanel
local testRows = {}

local function CreateTestPanel()
    local parent = LFGListFrame or UIParent
    local f = CreateFrame("Frame", "CrieffListTestPanel", parent, "BackdropTemplate")
    f:SetSize(320, 200)
    f:SetFrameStrata("HIGH")
    f:SetFrameLevel((parent:GetFrameLevel() or 0) + 10)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 0, -5)
    f:Hide()

    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
    end

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -12)
    title:SetText("Test: All M+ activities")
    title:SetTextColor(0.4, 0.9, 1)

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)

    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOP", 0, -28)
    hint:SetText("Click a row to call _Select with its IDs directly.")
    hint:SetTextColor(0.7, 0.7, 0.7)

    return f
end

local function GetOrCreateTestRow(index)
    if testRows[index] then return testRows[index] end
    local row = CreateFrame("Button", nil, testPanel)
    row:SetHeight(20)

    local hi = row:CreateTexture(nil, "HIGHLIGHT")
    hi:SetAllPoints()
    hi:SetColorTexture(1, 1, 1, 0.10)

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", 8, 0)
    row.text:SetPoint("RIGHT", -8, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)

    row:SetScript("OnClick", function(self)
        if self.activityID then
            CrieffList.GroupFinder.SelectActivity(self.activityID, self.groupID, 15)
        end
    end)

    testRows[index] = row
    return row
end

function UI.ShowTestPanel()
    if not testPanel then testPanel = CreateTestPanel() end
    local activities = CrieffList.GroupFinder.ListAllActivities()

    for i, a in ipairs(activities) do
        local row = GetOrCreateTestRow(i)
        row.activityID = a.activityID
        row.groupID = a.groupID
        row.text:SetText(string.format("%s  |cff999999[aID=%s gID=%s map=%s]|r",
            a.name, tostring(a.activityID), tostring(a.groupID), tostring(a.mapID)))
        row:ClearAllPoints()
        row:SetPoint("LEFT", testPanel, "LEFT", 8, 0)
        row:SetPoint("RIGHT", testPanel, "RIGHT", -8, 0)
        row:SetPoint("TOP", testPanel, "TOP", 0, -(48 + (i - 1) * 20))
        row:Show()
    end
    for i = #activities + 1, #testRows do
        testRows[i]:Hide()
    end

    if #activities == 0 then
        CrieffList:Print("Test: no M+ activities returned. Open Start-a-Group first, then run /kl test.")
    else
        CrieffList:Print(string.format("Test: %d M+ activities listed.", #activities))
    end

    testPanel:SetHeight(60 + math.max(#activities, 1) * 20 + 10)
    testPanel:Show()
end

local copyFrame
function UI.ShowCopyFrame(text)
    if not copyFrame then
        local f = CreateFrame("Frame", "CrieffListCopyFrame", UIParent, "BackdropTemplate")
        f:SetSize(620, 420)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:SetClampedToScreen(true)

        if f.SetBackdrop then
            f:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                tile = true, tileSize = 32, edgeSize = 16,
                insets = { left = 4, right = 4, top = 4, bottom = 4 },
            })
        end

        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", 0, -12)
        title:SetText("CrieffList debug dump — Ctrl+A then Ctrl+C to copy")
        title:SetTextColor(1, 0.82, 0)

        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", 0, 0)

        local scroll = CreateFrame("ScrollFrame", "CrieffListCopyScroll", f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 12, -36)
        scroll:SetPoint("BOTTOMRIGHT", -32, 12)

        local edit = CreateFrame("EditBox", "CrieffListCopyEdit", scroll)
        edit:SetMultiLine(true)
        edit:SetMaxLetters(0)
        edit:EnableMouse(true)
        edit:SetAutoFocus(false)
        edit:SetFontObject(ChatFontNormal)
        edit:SetWidth(580)
        edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        scroll:SetScrollChild(edit)

        f.edit = edit
        tinsert(UISpecialFrames, "CrieffListCopyFrame")
        copyFrame = f
    end

    copyFrame.edit:SetText(text or "")
    copyFrame.edit:HighlightText()
    copyFrame.edit:SetFocus()
    copyFrame:Show()
end

function UI.ShowHint(text)
    if not panel then panel = CreatePanel() end
    panel.hint:SetText(text or "")
    panel.hint:Show()
    panel.hintTimer = HINT_DURATION
    UI.Render()
end

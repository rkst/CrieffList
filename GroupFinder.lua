local GF = {}
CrieffList.GroupFinder = GF

local DUNGEON_CATEGORY = 2

local function RelaxedPlaystyleValue()
    return Enum and Enum.LFGEntryGeneralPlaystyle and Enum.LFGEntryGeneralPlaystyle.FunRelaxed
end

local function OpenPremade()
    if not PVEFrame or not PVEFrame:IsShown() then
        if PVEFrame_ToggleFrame then
            PVEFrame_ToggleFrame("GroupFinderFrame", LFGListPVEStub)
        elseif TogglePVEFrame then
            TogglePVEFrame()
        end
    end
    if GroupFinderFrame_ShowGroupFrame and LFGListPVEStub then
        pcall(GroupFinderFrame_ShowGroupFrame, LFGListPVEStub)
    end
end

local function ActivityFilters()
    if not Enum or not Enum.LFGListFilter then return 0 end
    local f = 0
    if Enum.LFGListFilter.CurrentSeason then f = bit.bor(f, Enum.LFGListFilter.CurrentSeason) end
    if Enum.LFGListFilter.PvE then f = bit.bor(f, Enum.LFGListFilter.PvE) end
    return f
end

local function ChallengeMapName(challengeMapID)
    if not challengeMapID or not C_ChallengeMode or not C_ChallengeMode.GetMapUIInfo then return nil end
    local name = C_ChallengeMode.GetMapUIInfo(challengeMapID)
    return name
end

local function ActivityGroupName(info)
    if not info or not info.groupFinderActivityGroupID then return nil end
    if not C_LFGList or not C_LFGList.GetActivityGroupInfo then return nil end
    local name = C_LFGList.GetActivityGroupInfo(info.groupFinderActivityGroupID)
    if name and name ~= "" then return name end
    return nil
end

local function NameCandidates(info)
    return { ActivityGroupName(info), info.fullName, info.shortName }
end

local function MatchByName(activities, name)
    if type(activities) ~= "table" or not name then return nil, nil end
    for _, id in ipairs(activities) do
        local info = C_LFGList.GetActivityInfoTable and C_LFGList.GetActivityInfoTable(id)
        if info and info.isMythicPlusActivity then
            for _, an in ipairs(NameCandidates(info)) do
                if an == name then
                    return id, info.groupFinderActivityGroupID
                end
            end
        end
    end
    for _, id in ipairs(activities) do
        local info = C_LFGList.GetActivityInfoTable and C_LFGList.GetActivityInfoTable(id)
        if info and info.isMythicPlusActivity then
            for _, an in ipairs(NameCandidates(info)) do
                if an and an ~= "" and (an:find(name, 1, true) or name:find(an, 1, true)) then
                    return id, info.groupFinderActivityGroupID
                end
            end
        end
    end
    return nil, nil
end

local function ResolveActivity(challengeMapID)
    if not C_LFGList or not C_LFGList.GetAvailableActivities then return nil, nil end

    local own = CrieffList.Keystones and CrieffList.Keystones.own
    if own and own.mapID == challengeMapID and C_LFGList.GetOwnedKeystoneActivityAndGroupAndLevel then
        local aID, gID = C_LFGList.GetOwnedKeystoneActivityAndGroupAndLevel()
        if aID then return aID, gID end
    end

    local name = ChallengeMapName(challengeMapID)
    if not name then return nil, nil end

    local filtered = C_LFGList.GetAvailableActivities(DUNGEON_CATEGORY, nil, ActivityFilters())
    local id, gid = MatchByName(filtered, name)
    if id then return id, gid end

    local unfiltered = C_LFGList.GetAvailableActivities(DUNGEON_CATEGORY)
    return MatchByName(unfiltered, name)
end

function GF.Debug(targetMapID)
    local lines = {}
    local function push(s) lines[#lines + 1] = s end

    push(string.format("CrieffList v%s debug @ %s", tostring(CrieffList.version), date("%Y-%m-%d %H:%M:%S")))
    push(string.format("locale=%s build=%s", GetLocale and GetLocale() or "?", select(1, GetBuildInfo()) or "?"))

    local challengeName = ChallengeMapName(targetMapID)
    push(string.format("target challengeMapID=%s name=%s", tostring(targetMapID), tostring(challengeName)))

    local own = CrieffList.Keystones and CrieffList.Keystones.own or {}
    push(string.format("own mapID=%s level=%s", tostring(own.mapID), tostring(own.level)))

    if not C_LFGList or not C_LFGList.GetAvailableActivities then
        push("C_LFGList missing")
    else
        local aID, gID = ResolveActivity(targetMapID)
        push(string.format("ResolveActivity(%s) -> activityID=%s groupID=%s", tostring(targetMapID), tostring(aID), tostring(gID)))
        local filtered = C_LFGList.GetAvailableActivities(DUNGEON_CATEGORY, nil, ActivityFilters())
        local unfiltered = C_LFGList.GetAvailableActivities(DUNGEON_CATEGORY)
        push(string.format("activities filtered=%d unfiltered=%d", filtered and #filtered or -1, unfiltered and #unfiltered or -1))
        local list = unfiltered or filtered or {}
        for _, id in ipairs(list) do
            local info = C_LFGList.GetActivityInfoTable(id)
            if info and info.isMythicPlusActivity then
                local gn = ActivityGroupName(info) or ""
                local marker = ""
                if challengeName then
                    for _, an in ipairs(NameCandidates(info)) do
                        if an and (an == challengeName or an:find(challengeName, 1, true) or challengeName:find(an, 1, true)) then
                            marker = " <== NAME MATCH"
                            break
                        end
                    end
                end
                push(string.format("activity=%d gID=%s mapID=%s group=%q full=%q short=%q%s",
                    id, tostring(info.groupFinderActivityGroupID), tostring(info.mapID),
                    gn, tostring(info.fullName or ""), tostring(info.shortName or ""), marker))
            end
        end
    end

    if CrieffList.Keystones then
        for _, e in pairs(CrieffList.Keystones.party) do
            push(string.format("party name=%s mapID=%s level=%s source=%s",
                tostring(e.name), tostring(e.mapID), tostring(e.level), tostring(e.source)))
        end
    end

    local text = table.concat(lines, "\n")
    CrieffList:Print(string.format("debug: %d lines written to copy window", #lines))
    if CrieffList.UI and CrieffList.UI.ShowCopyFrame then
        CrieffList.UI.ShowCopyFrame(text)
    end
    return text
end

local function SetPlaystyle(panel)
    if not panel then return end
    local target = RelaxedPlaystyleValue()
    if target == nil then return end
    if _G.LFGListEntryCreation_OnPlayStyleSelectedInternal then
        pcall(_G.LFGListEntryCreation_OnPlayStyleSelectedInternal, panel, target)
    end
    if panel.generalPlaystyle ~= target then
        panel.generalPlaystyle = target
    end
    local dd = panel.PlayStyleDropdown
    if dd and dd.GenerateMenu then
        pcall(dd.GenerateMenu, dd)
    end
end

function GF.OpenEntryCreation()
    OpenPremade()

    local panel = LFGListFrame and LFGListFrame.EntryCreation
    if not panel then
        CrieffList:Print("Group Finder UI isn't loaded yet.")
        return
    end

    local baseFilters = LFGListFrame.baseFilters or 0
    local selectedFilters = (LFGListFrame.CategorySelection and LFGListFrame.CategorySelection.selectedFilters) or 0

    if LFGListEntryCreation_Show then
        local ok = pcall(LFGListEntryCreation_Show, panel, baseFilters, DUNGEON_CATEGORY, selectedFilters)
        if not ok then
            CrieffList:Print("Couldn't open Start-a-Group. Try opening Group Finder manually once first.")
        end
    end
end

function GF.SelectActivity(activityID, groupID, level)
    local panel = LFGListFrame and LFGListFrame.EntryCreation
    if not panel or not panel:IsShown() then
        CrieffList:Print("Open Start-a-Group first.")
        return
    end
    if not activityID then
        CrieffList:Print("No activityID provided.")
        return
    end
    pcall(LFGListEntryCreation_Select, panel, nil, DUNGEON_CATEGORY, groupID, activityID)
    SetPlaystyle(panel)
    if panel.Name and panel.Name.SetFocus then panel.Name:SetFocus() end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.1, function()
            CrieffList:Print(string.format(
                "select: requested aID=%s gID=%s -> selectedActivity=%s selectedGroup=%s",
                tostring(activityID), tostring(groupID),
                tostring(panel.selectedActivity), tostring(panel.selectedGroup)))
        end)
    end
    if level and CrieffList.UI and CrieffList.UI.ShowHint then
        CrieffList.UI.ShowHint(string.format("Type +%d in the title to enable List Group.", level))
    end
end

function GF.ListAllActivities()
    local out = {}
    if not C_LFGList or not C_LFGList.GetAvailableActivities then return out end
    local filtered = C_LFGList.GetAvailableActivities(DUNGEON_CATEGORY, nil, ActivityFilters())
    local unfiltered = C_LFGList.GetAvailableActivities(DUNGEON_CATEGORY)
    local merged = {}
    for _, id in ipairs(filtered or {}) do merged[id] = true end
    for _, id in ipairs(unfiltered or {}) do merged[id] = true end
    for id in pairs(merged) do
        local info = C_LFGList.GetActivityInfoTable(id)
        if info and info.isMythicPlusActivity then
            local name = info.fullName or info.shortName or ("activity " .. id)
            out[#out + 1] = {
                activityID = id,
                groupID = info.groupFinderActivityGroupID,
                mapID = info.mapID,
                name = name,
            }
        end
    end
    table.sort(out, function(a, b) return (a.name or "") < (b.name or "") end)
    return out
end

function GF.ApplyToCurrentPanel(mapID, level)
    if not mapID or not level then return end

    local panel = LFGListFrame and LFGListFrame.EntryCreation
    if not panel or not panel:IsShown() then
        CrieffList:Print("Open Start-a-Group (Premade Groups → Dungeons → Start a Group) first.")
        return
    end

    local activityID, groupID = ResolveActivity(mapID)
    if not activityID then
        CrieffList:Print("Couldn't find an M+ activity for this dungeon.")
        return
    end

    if LFGListEntryCreation_Select then
        pcall(LFGListEntryCreation_Select, panel, nil, DUNGEON_CATEGORY, groupID, activityID)
    end

    SetPlaystyle(panel)

    if panel.Name and panel.Name.SetFocus then
        panel.Name:SetFocus()
    end

    if CrieffList.UI and CrieffList.UI.ShowHint then
        CrieffList.UI.ShowHint(string.format("Type +%d in the title to enable List Group.", level))
    end
end

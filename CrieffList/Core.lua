local addonName, ns = ...

CrieffList = CrieffList or {}
CrieffList.name = addonName
CrieffList.version = "0.2.0"
CrieffList.events = {}

local frame = CreateFrame("Frame", "CrieffListEventFrame")
CrieffList.frame = frame

frame:SetScript("OnEvent", function(_, event, ...)
    local handler = CrieffList.events[event]
    if handler then
        handler(...)
    end
end)

function CrieffList:RegisterEvent(event, handler)
    self.events[event] = handler
    frame:RegisterEvent(event)
end

function CrieffList:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff5dade2CrieffList|r: " .. tostring(msg))
end

CrieffList:RegisterEvent("ADDON_LOADED", function(loaded)
    if loaded ~= addonName then return end
    CrieffListCharDB = CrieffListCharDB or {}
    CrieffList.db = CrieffListCharDB
end)

CrieffList:RegisterEvent("PLAYER_LOGIN", function()
    if CrieffList.Keystones and CrieffList.Keystones.Init then
        CrieffList.Keystones.Init()
    end
    if CrieffList.Comm and CrieffList.Comm.Init then
        CrieffList.Comm.Init()
    end

    if LFGListFrame_SetActivePanel and not CrieffList._panelHooked then
        hooksecurefunc("LFGListFrame_SetActivePanel", function(_, activePanel)
            if not CrieffList.UI then return end
            if activePanel == (LFGListFrame and LFGListFrame.EntryCreation) then
                CrieffList.UI.OnEntryCreationShown()
            else
                CrieffList.UI.OnEntryCreationHidden()
            end
        end)
        CrieffList._panelHooked = true
    end
end)

local function HandleSlash(arg)
    arg = arg and strtrim(arg) or ""
    if arg == "debug" then
        if CrieffList.GroupFinder and CrieffList.GroupFinder.Debug then
            local own = CrieffList.Keystones and CrieffList.Keystones.own
            CrieffList.GroupFinder.Debug(own and own.mapID or 0)
        end
        return
    end
    local m, l = arg:match("^debug%s+(%d+)")
    if m then
        CrieffList.GroupFinder.Debug(tonumber(m))
        return
    end
    if arg == "test" then
        if CrieffList.UI and CrieffList.UI.ShowTestPanel then
            CrieffList.UI.ShowTestPanel()
        end
        return
    end
    if CrieffList.GroupFinder and CrieffList.GroupFinder.OpenEntryCreation then
        CrieffList.GroupFinder.OpenEntryCreation()
    else
        CrieffList:Print("Group Finder not ready.")
    end
end

SLASH_CRIEFFLIST1 = "/kl"
SLASH_CRIEFFLIST2 = "/crieff"
SlashCmdList["CRIEFFLIST"] = HandleSlash

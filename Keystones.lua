local Keystones = {}
CrieffList.Keystones = Keystones

Keystones.own = { mapID = nil, level = nil }
Keystones.party = {}

local function ResolveDungeonName(mapID)
    if not mapID then return nil, nil end
    local name, _, _, texture = C_ChallengeMode.GetMapUIInfo(mapID)
    return name, texture
end

function Keystones.GetOwn()
    local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID and C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    local level = C_MythicPlus.GetOwnedKeystoneLevel and C_MythicPlus.GetOwnedKeystoneLevel()
    if mapID == 0 then mapID = nil end
    if level == 0 then level = nil end
    return { mapID = mapID, level = level }
end

local function ScanOwn()
    local current = Keystones.GetOwn()
    local changed = current.mapID ~= Keystones.own.mapID or current.level ~= Keystones.own.level
    Keystones.own = current
    return changed
end

local function PruneParty()
    if not IsInGroup() then
        Keystones.party = {}
        return
    end
    local present = {}
    local prefix = IsInRaid() and "raid" or "party"
    local count = GetNumGroupMembers()
    for i = 1, count do
        local unit = prefix .. i
        local guid = UnitGUID(unit)
        if guid then present[guid] = true end
    end
    local selfGuid = UnitGUID("player")
    if selfGuid then present[selfGuid] = true end
    for guid in pairs(Keystones.party) do
        if not present[guid] then
            Keystones.party[guid] = nil
        end
    end
end

function Keystones.UpsertParty(guid, name, mapID, level, source)
    if not guid then return end
    local existing = Keystones.party[guid]
    if existing and existing.source == "LibOpenRaid" and source ~= "LibOpenRaid" then
        if existing.mapID == mapID and existing.level == level then
            return
        end
    end
    local dungeonName, texture = ResolveDungeonName(mapID)
    Keystones.party[guid] = {
        name = name,
        mapID = mapID,
        level = level,
        dungeonName = dungeonName,
        texture = texture,
        source = source,
    }
end

function Keystones.GetAll()
    local list = {}
    local selfGuid = UnitGUID("player")
    local selfName = UnitName("player")
    local _, selfClass = UnitClass("player")
    local dungeonName, texture = ResolveDungeonName(Keystones.own.mapID)
    list[#list + 1] = {
        guid = selfGuid,
        name = selfName,
        class = selfClass,
        mapID = Keystones.own.mapID,
        level = Keystones.own.level,
        dungeonName = dungeonName,
        texture = texture,
        noKey = Keystones.own.mapID == nil or Keystones.own.level == nil,
        isSelf = true,
    }

    if IsInGroup() then
        local prefix = IsInRaid() and "raid" or "party"
        local count = GetNumGroupMembers()
        for i = 1, count do
            local unit = prefix .. i
            local guid = UnitGUID(unit)
            if guid and guid ~= selfGuid then
                local name = UnitName(unit)
                local _, class = UnitClass(unit)
                local entry = Keystones.party[guid]
                local dName, tex
                if entry and entry.mapID then
                    dName, tex = ResolveDungeonName(entry.mapID)
                end
                list[#list + 1] = {
                    guid = guid,
                    name = name or (entry and entry.name),
                    class = class,
                    mapID = entry and entry.mapID,
                    level = entry and entry.level,
                    dungeonName = dName,
                    texture = tex,
                    noKey = not (entry and entry.mapID and entry.level),
                    isSelf = false,
                }
            end
        end
    end

    return list
end

function Keystones.RefreshAll()
    ScanOwn()
    if CrieffList.Comm and CrieffList.Comm.RequestParty then
        CrieffList.Comm.RequestParty()
    end
end

function Keystones.Init()
    ScanOwn()

    CrieffList:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE", function()
        if ScanOwn() and CrieffList.Comm and CrieffList.Comm.BroadcastOwn then
            CrieffList.Comm.BroadcastOwn()
        end
    end)
    CrieffList:RegisterEvent("BAG_UPDATE_DELAYED", function()
        if ScanOwn() and CrieffList.Comm and CrieffList.Comm.BroadcastOwn then
            CrieffList.Comm.BroadcastOwn()
        end
    end)
    CrieffList:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        ScanOwn()
        PruneParty()
        if CrieffList.Comm and CrieffList.Comm.BroadcastNow then
            CrieffList.Comm.BroadcastNow()
        end
    end)
    CrieffList:RegisterEvent("GROUP_ROSTER_UPDATE", function()
        PruneParty()
        if CrieffList.Comm and CrieffList.Comm.BroadcastNow then
            CrieffList.Comm.BroadcastNow()
        end
        if CrieffList.Comm and CrieffList.Comm.RequestParty then
            CrieffList.Comm.RequestParty()
        end
    end)

    if C_MythicPlus and C_MythicPlus.RequestMapInfo then
        pcall(C_MythicPlus.RequestMapInfo)
    end
end

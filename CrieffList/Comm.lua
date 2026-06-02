local Comm = {}
CrieffList.Comm = Comm

local PREFIX = "CrieffList"
local PROTO = "v1"
local BROADCAST_THROTTLE = 5

local lastBroadcast = 0
local keystoneLib
local openRaidLib
local keystoneToken = {}

local function GuidForName(name)
    if not name then return nil end
    local short = Ambiguate(name, "short")
    local guid = UnitGUID(short)
    if guid then return guid, short end
    if not IsInGroup() then return nil, short end
    local prefix = IsInRaid() and "raid" or "party"
    local count = GetNumGroupMembers()
    for i = 1, count do
        local unit = prefix .. i
        local uname = GetUnitName(unit, true)
        if uname == name or uname == short or Ambiguate(uname or "", "short") == short then
            return UnitGUID(unit), short
        end
    end
    return nil, short
end

local function InMyParty(sender)
    if not sender then return false end
    local short = Ambiguate(sender, "short")
    if UnitInParty(short) or UnitInRaid(short) then return true end
    if short == UnitName("player") then return true end
    return false
end

function Comm.BroadcastNow()
    if not IsInGroup() then return end
    local own = CrieffList.Keystones and CrieffList.Keystones.own
    if not own or not own.mapID or not own.level then return end
    local msg = string.format("%s|KEY|%d|%d", PROTO, own.mapID, own.level)
    pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, "PARTY")
    lastBroadcast = GetTime()
end

function Comm.BroadcastOwn()
    local now = GetTime()
    if now - lastBroadcast < BROADCAST_THROTTLE then return end
    Comm.BroadcastNow()
end

function Comm.RequestParty()
    if not IsInGroup() then return end
    local msg = PROTO .. "|REQ"
    pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, "PARTY")
    if keystoneLib and keystoneLib.Request then
        pcall(keystoneLib.Request, "PARTY")
    end
    if openRaidLib and openRaidLib.RequestKeystoneDataFromParty then
        pcall(openRaidLib.RequestKeystoneDataFromParty)
    end
end

local function HandleAddonMessage(prefix, message, _, sender)
    if prefix ~= PREFIX then return end
    if not InMyParty(sender) then return end
    if Ambiguate(sender, "short") == UnitName("player") then return end

    local proto, kind, a, b = strsplit("|", message)
    if proto ~= PROTO then return end

    if kind == "KEY" then
        local mapID = tonumber(a)
        local level = tonumber(b)
        if not mapID or not level then return end
        local guid, short = GuidForName(sender)
        if guid and CrieffList.Keystones then
            CrieffList.Keystones.UpsertParty(guid, short, mapID, level, "comm")
        end
    elseif kind == "REQ" then
        Comm.BroadcastNow()
    end
end

local function OnLibKeystone(keyLevel, keyMap, _playerRating, playerName, channel)
    if channel ~= "PARTY" then return end
    if not playerName or not keyMap or not keyLevel then return end
    if keyMap == 0 or keyLevel == 0 then return end
    if Ambiguate(playerName, "short") == UnitName("player") then return end
    local guid, short = GuidForName(playerName)
    if not guid then return end
    if CrieffList.Keystones then
        CrieffList.Keystones.UpsertParty(guid, short or playerName, keyMap, keyLevel, "LibKeystone")
    end
end

local function IngestOpenRaidInfo(unitName, info)
    if not unitName or type(info) ~= "table" then return end
    local mapID = info.mythicPlusMapID or info.challengeMapID or info.mapID
    local level = info.level
    if not mapID or not level or mapID == 0 or level == 0 then return end
    local guid, short = GuidForName(unitName)
    if not guid then return end
    local existing = CrieffList.Keystones and CrieffList.Keystones.party[guid]
    if existing and existing.source == "LibKeystone" then return end
    if CrieffList.Keystones then
        CrieffList.Keystones.UpsertParty(guid, short or unitName, mapID, level, "LibOpenRaid")
    end
end

function CrieffList.OnLibOpenRaidKeystoneUpdate(unitName, keystoneInfo)
    IngestOpenRaidInfo(unitName, keystoneInfo)
end

function CrieffList.OnLibOpenRaidKeystoneWipe()
    if not CrieffList.Keystones then return end
    for guid, entry in pairs(CrieffList.Keystones.party) do
        if entry.source == "LibOpenRaid" then
            CrieffList.Keystones.party[guid] = nil
        end
    end
end

local function SeedFromLibOpenRaid()
    if not openRaidLib or not openRaidLib.GetAllKeystonesInfo then return end
    local ok, all = pcall(openRaidLib.GetAllKeystonesInfo)
    if not ok or type(all) ~= "table" then return end
    local me = UnitName("player")
    for unitName, info in pairs(all) do
        if unitName ~= me then
            IngestOpenRaidInfo(unitName, info)
        end
    end
end

function Comm.Init()
    pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
    CrieffList:RegisterEvent("CHAT_MSG_ADDON", HandleAddonMessage)

    if LibStub then
        local kok, klib = pcall(LibStub, "LibKeystone", true)
        if kok and klib and klib.Register then
            keystoneLib = klib
            pcall(klib.Register, keystoneToken, OnLibKeystone)
            if klib.Request then
                pcall(klib.Request, "PARTY")
            end
        end

        local ook, olib = pcall(LibStub, "LibOpenRaid-1.0", true)
        if ook and olib then
            openRaidLib = olib
            pcall(olib.RegisterCallback, CrieffList, "KeystoneUpdate", "OnLibOpenRaidKeystoneUpdate")
            pcall(olib.RegisterCallback, CrieffList, "KeystoneWipe", "OnLibOpenRaidKeystoneWipe")
            SeedFromLibOpenRaid()
            if olib.RequestKeystoneDataFromParty then
                pcall(olib.RequestKeystoneDataFromParty)
            end
        end
    end
end

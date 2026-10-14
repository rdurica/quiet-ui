local _, ns = ...

-- Center-screen quest lines moved off the error frame while notices are on.

local Q = ns.QuestNotice
local S = Q.state

-- Missing means on. Only an explicit false turns notices off.
function Q.Enabled()
    return type(ns.Settings.QuestNoticeEnabled) ~= "function" or ns.Settings.QuestNoticeEnabled() ~= false
end

-- Center-screen quest lines. Rewards and failures stay on the error frame.
local CENTER_QUEST = {}

local function CenterType(name, fallback)
    local value = _G[name]
    if type(value) == "number" then return value end
    return fallback
end

for _, entry in ipairs({
    { "LE_GAME_ERR_QUEST_ACCEPTED_S", 179 },
    { "LE_GAME_ERR_QUEST_COMPLETE_S", 180 },
    { "LE_GAME_ERR_QUEST_OBJECTIVE_COMPLETE_S", 303 },
    { "LE_GAME_ERR_QUEST_UNKNOWN_COMPLETE", 304 },
    { "LE_GAME_ERR_QUEST_ADD_KILL_SII", 305 },
    { "LE_GAME_ERR_QUEST_ADD_FOUND_SII", 306 },
    { "LE_GAME_ERR_QUEST_ADD_ITEM_SII", 307 },
    { "LE_GAME_ERR_QUEST_ADD_PLAYER_KILL_SII", 308 },
}) do
    CENTER_QUEST[CenterType(entry[1], entry[2])] = true
end

local function ShowCenter(event, messageType, message)
    if not UIErrorsFrame then return end
    if type(S.centerHandler) == "function" then
        S.centerHandler(UIErrorsFrame, event, messageType, message)
        return
    end
    if type(UIErrorsFrame.AddMessage) ~= "function" then return end
    if event == "UI_ERROR_MESSAGE" then
        UIErrorsFrame:AddMessage(message, 1, 0.1, 0.1, 1)
    else
        UIErrorsFrame:AddMessage(message, 1, 1, 0, 1)
    end
end

function Q.ReleaseCenterEvents()
    if S.centerProxy then
        if type(S.centerProxy.UnregisterAllEvents) == "function" then
            pcall(S.centerProxy.UnregisterAllEvents, S.centerProxy)
        else
            pcall(S.centerProxy.UnregisterEvent, S.centerProxy, "UI_INFO_MESSAGE")
            pcall(S.centerProxy.UnregisterEvent, S.centerProxy, "UI_ERROR_MESSAGE")
        end
        if type(S.centerProxy.SetScript) == "function" then S.centerProxy:SetScript("OnEvent", nil) end
        S.centerProxy = nil
    end
    if S.centerOwned and UIErrorsFrame and type(UIErrorsFrame.RegisterEvent) == "function" then
        pcall(UIErrorsFrame.RegisterEvent, UIErrorsFrame, "UI_INFO_MESSAGE")
        pcall(UIErrorsFrame.RegisterEvent, UIErrorsFrame, "UI_ERROR_MESSAGE")
    end
    S.centerHandler, S.centerOwned = nil, false
end

function Q.InstallCenterFilter()
    if S.centerOwned or not UIErrorsFrame or type(UIErrorsFrame.UnregisterEvent) ~= "function" then return end
    if type(CreateFrame) ~= "function" then return end
    local infoOk = pcall(UIErrorsFrame.UnregisterEvent, UIErrorsFrame, "UI_INFO_MESSAGE")
    local errorOk = pcall(UIErrorsFrame.UnregisterEvent, UIErrorsFrame, "UI_ERROR_MESSAGE")
    if not infoOk and not errorOk then return end
    if type(UIErrorsFrame.GetScript) == "function" then
        local ok, handler = pcall(UIErrorsFrame.GetScript, UIErrorsFrame, "OnEvent")
        if ok and type(handler) == "function" then S.centerHandler = handler end
    end
    local createdOk, created = pcall(CreateFrame, "Frame")
    if not createdOk or not created or type(created.RegisterEvent) ~= "function" or type(created.SetScript) ~= "function" then
        if infoOk and type(UIErrorsFrame.RegisterEvent) == "function" then
            pcall(UIErrorsFrame.RegisterEvent, UIErrorsFrame, "UI_INFO_MESSAGE")
        end
        if errorOk and type(UIErrorsFrame.RegisterEvent) == "function" then
            pcall(UIErrorsFrame.RegisterEvent, UIErrorsFrame, "UI_ERROR_MESSAGE")
        end
        S.centerHandler = nil
        return
    end
    S.centerProxy = created
    S.centerProxy:SetScript("OnEvent", function(_, event, messageType, message)
        if S.active and Q.Enabled() and not Q.Secret(messageType) and CENTER_QUEST[messageType] then return end
        ShowCenter(event, messageType, message)
    end)
    local heardInfo = pcall(S.centerProxy.RegisterEvent, S.centerProxy, "UI_INFO_MESSAGE")
    local heardError = pcall(S.centerProxy.RegisterEvent, S.centerProxy, "UI_ERROR_MESSAGE")
    if not heardInfo and not heardError then
        S.centerOwned = true
        Q.ReleaseCenterEvents()
        return
    end
    S.centerOwned = true
end


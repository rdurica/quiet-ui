local _, ns = ...

-- Per-character settings store. The setup window only edits them.

ns.Settings = ns.Settings or {}

-- Per character. An older build kept this on the account; the first character
-- to load keeps that copy, then the account keys are dropped.
local accountMoved = false

function ns.Settings.CharDB()
    if type(QuietUICharDB) ~= "table" then
        QuietUICharDB = {}
    end
    if not accountMoved then
        accountMoved = true
        local account = ns.DB()
        if account.visible ~= nil or account.player ~= nil then
            if QuietUICharDB.visible == nil and QuietUICharDB.player == nil then
                QuietUICharDB.visible = account.visible
                QuietUICharDB.player = account.player
            end
            account.visible = nil
            account.player = nil
        end
    end
    ns.Settings.MigrateOnce(QuietUICharDB)
    return QuietUICharDB
end

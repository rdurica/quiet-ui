local _, ns = ...

-- Share one idle frame driver across window refreshes. Each journal owns its jobs, so Undo cancels them even
-- if styling is enabled again before the next frame. A job queued from a refresh runs on the following frame.
local Modern = ns.Modern
local Refresh = {}
Modern.Refresh = Refresh

local jobs = setmetatable({}, { __mode = "k" })
local pending = {}
local driver = CreateFrame("Frame")
driver:Hide()
driver:SetScript("OnUpdate", function(self)
    self:Hide()
    local batch = pending
    pending = {}
    for job, version in pairs(batch) do
        if job.active and job.version == version then
            local args = job.args
            job.args = nil
            ns.Profiler.Run(job.label, job.fn, unpack(args, 1, args.n))
        end
    end
end)

-- owner is a frame and key distinguishes independent work on that frame. The latest callback and arguments
-- win; they are read only when the frame runs. Jobs are reused until the skin journal is restored.
function Refresh.Queue(skin, owner, key, label, fn, ...)
    if skin.undoing or not ns.Usable(owner) then return end
    local owners = jobs[skin]
    if not owners then owners = {}; jobs[skin] = owners end
    local keys = owners[owner]
    if not keys then keys = {}; owners[owner] = keys end
    local job = keys[key]
    if not job then
        job = { active = true, version = 0 }
        keys[key] = job
        skin:Remember(owner, "modern refresh " .. key, function()
            job.active = false
            job.args = nil
            pending[job] = nil
            keys[key] = nil
            if not next(keys) then owners[owner] = nil end
        end)
    end
    job.version = job.version + 1
    job.label, job.fn = label, fn
    job.args = { n = select("#", ...), ... }
    pending[job] = job.version
    driver:Show()
end

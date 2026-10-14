local _, ns = ...

-- Hyperlinks inside bubbles: tooltips, clicks and link hit boxes.

local Chat = ns.Chat

local MAX_LINKS = 12
local function OpenLink(chat, link, text, button)
    if type(link) ~= "string" or link == "" then return end
    if type(SetItemRef) == "function" then
        if pcall(SetItemRef, link, text, button, chat) then return end
    end
    if type(ChatFrame_OnHyperlinkShow) == "function" then
        pcall(ChatFrame_OnHyperlinkShow, chat, link, text, button)
    end
end

-- Trade links can open the profession window even through GameTooltip.
local TOOLTIP_LINKS = {
    item = true, spell = true, enchant = true, quest = true,
    achievement = true, currency = true,
}

local function ShowLinkTip(button, link, display)
    link = link or button.link
    display = display or button.display
    if not GameTooltip or not GameTooltip.SetOwner then return end
    GameTooltip:SetOwner(button, "ANCHOR_CURSOR")
    local shown = false
    local kind = type(link) == "string" and link:match("^([^:]+):")
    if GameTooltip.SetHyperlink and TOOLTIP_LINKS[kind] then
        shown = pcall(GameTooltip.SetHyperlink, GameTooltip, link)
    end
    if not shown and GameTooltip.SetText then
        pcall(GameTooltip.SetText, GameTooltip, display or "", 1, 1, 1)
    end
    if GameTooltip.Show then GameTooltip:Show() end
end

local function HideTip()
    if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
end
local function MakeLink(bubble)
    local button = CreateFrame("Button", nil, bubble)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:EnableMouseWheel(true)
    button:SetScript("OnClick", function(self, buttonName)
        OpenLink(bubble.chat, self.link, self.display, buttonName)
    end)
    button:SetScript("OnEnter", function(self)
        ShowLinkTip(self)
    end)
    button:SetScript("OnLeave", HideTip)
    button:SetScript("OnMouseWheel", function(_, delta)
        Chat.Wheel(bubble.chat, delta)
    end)
    button:Hide()
    return button
end

-- The renderer knows the exact link bounds, including wrapped and indented rows.
local function BindBubbleLinks(bubble)
    if type(bubble.SetHyperlinksEnabled) ~= "function" then return end
    local ok = pcall(function()
        bubble:SetHyperlinksEnabled(true)
        bubble:SetScript("OnHyperlinkEnter", function(self, link, text)
            if self.msg and not self.msg.secret then ShowLinkTip(self, link, text) end
        end)
        bubble:SetScript("OnHyperlinkLeave", HideTip)
        bubble:SetScript("OnHyperlinkClick", function(self, link, text, button)
            if self.msg and not self.msg.secret then
                OpenLink(self.chat, link, text, button)
            end
        end)
    end)
    bubble._quietNativeLinks = ok
end
Chat.BindBubbleLinks = BindBubbleLinks

local function PlaceLinks(bubble, msg, inner)
    local links = bubble.links
    if bubble._quietNativeLinks then
        pcall(bubble.SetHyperlinksEnabled, bubble, msg ~= nil and not msg.secret)
        for i = 1, #links do links[i]:Hide() end
        return
    end
    if not msg or msg.secret then
        for i = 1, #links do
            links[i]:Hide()
        end
        return
    end
    local count = 0
    local segs = Chat.Segments(msg.text or "")
    local lineH = 14
    if bubble.text.GetLineHeight then
        local ok, h = pcall(bubble.text.GetLineHeight, bubble.text)
        if ok and type(h) == "number" and h > 0 then lineH = h end
    elseif bubble.text.GetFont then
        local _, size = bubble.text:GetFont()
        if type(size) == "number" and size > 0 then lineH = size end
    end
    if bubble.text.GetSpacing then
        local spacing = bubble.text:GetSpacing()
        if type(spacing) == "number" then lineH = lineH + spacing end
    end
    local x, y = 0, 0
    for i = 1, #segs do
        if count >= MAX_LINKS then break end
        local seg = segs[i]
        if seg.br then
            x, y = 0, y + lineH
        else
            local w = seg.width or Chat.UnboundedWidth(bubble.text, seg.text or "")
            local token = seg.text or ""
            if x > 0 and x + w > inner and token:match("%S") then
                x, y = 0, y + lineH
            end
            if x == 0 and token ~= "" and not token:match("%S") then
                w = 0
            end
            if seg.link and w > 0 then
                count = count + 1
                local button = links[count]
                if not button then
                    button = MakeLink(bubble)
                    links[count] = button
                end
                button.link = seg.link
                button.display = seg.text
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT", bubble.text, "TOPLEFT", x, -y)
                button:SetSize(math.max(4, math.min(w, inner)), lineH)
                button:Show()
            end
            x = x + w
        end
    end
    for i = count + 1, #links do
        links[i]:Hide()
    end
end
Chat.PlaceLinks = PlaceLinks

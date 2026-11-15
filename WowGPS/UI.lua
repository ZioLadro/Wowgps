-- WowGPS: the directions window.
local _, ns = ...
local L = ns.L

local UI = {}
ns.UI = UI

local WIDTH, HEIGHT = 440, 600
local ROWS = 5
local MOUNT_CYCLE = { auto = 0, [0] = 60, [60] = 100, [100] = "auto" }
local KIND_ICON = {
    walk = "Interface\\Icons\\Ability_Rogue_Sprint",
    mount = "Interface\\Icons\\Ability_Mount_RidingHorse",
    transit = "Interface\\Icons\\INV_Misc_Anchor",
    flight = "Interface\\Icons\\Ability_Mount_Gryphon_01",
    hearth = "Interface\\Icons\\INV_Misc_Rune_01",
}

local function mountLabel()
    local v = ns.db.mountSpeed
    if v == 0 then return string.format(L["Mount: %s"], L["none"]) end
    if v == 60 or v == 100 then return string.format(L["Mount: %s"], "+" .. v .. "%") end
    return string.format(L["Mount: %s"], L["auto"] .. " +" .. ns:SpeedPercent(ns:MountSpeed()) .. "%")
end

local function makeButton(parent, text, w, h)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, h or 22)
    b:SetText(text)
    return b
end

local function makeEdit(parent, w)
    local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    e:SetSize(w, 22)
    e:SetAutoFocus(false)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return e
end

function UI:HideSuggestions()
    if self.suggest then self.suggest:Hide() end
end

function UI:ShowSuggestions(edit)
    local names = ns.Places:Suggest(edit:GetText(), 6)
    local box = self.suggest
    if #names == 0 or (#names == 1 and names[1]:lower() == edit:GetText():lower()) then
        box:Hide()
        return
    end
    for i = 1, 6 do
        local b = box.buttons[i]
        if names[i] then
            b:SetText(names[i])
            b.target, b.value = edit, names[i]
            b:Show()
        else
            b:Hide()
        end
    end
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", edit, "BOTTOMLEFT", -4, 0)
    box:SetHeight(#names * 18 + 8)
    box:Show()
end

function UI:Create()
    if self.frame then return self.frame end
    local f = CreateFrame("Frame", "WowGPSFrame", UIParent, "BasicFrameTemplateWithInset")
    self.frame = f
    f:SetSize(WIDTH, HEIGHT)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetScript("OnHide", function() UI:HideSuggestions() end)
    tinsert(UISpecialFrames, "WowGPSFrame")

    local title = type(f.TitleText) == "table" and f.TitleText
    if not title then
        title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        title:SetPoint("TOP", 0, -5)
    end
    title:SetText("WowGPS")

    -- Start / destination rows.
    local function row(label, y, quickText, quickValue)
        local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", 16, y)
        fs:SetText(label)
        local e = makeEdit(f, 250)
        e:SetPoint("TOPLEFT", 110, y + 5)
        e:SetScript("OnTextChanged", function(self, user)
            if user then UI:ShowSuggestions(self) end
        end)
        e:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
            UI:HideSuggestions()
            UI:Compute()
        end)
        e:SetScript("OnEditFocusLost", function()
            -- Delay so a click on a suggestion still lands.
            C_Timer.After(0.2, function() UI:HideSuggestions() end)
        end)
        local q = makeButton(f, quickText, 54)
        q:SetPoint("LEFT", e, "RIGHT", 6, 0)
        q:SetScript("OnClick", function()
            e:SetText(quickValue)
            UI:HideSuggestions()
        end)
        return e
    end
    self.startEdit = row(L["Start"], -40, L["Here"], L["My position"])
    self.destEdit = row(L["Destination"], -68, L["Pin"], L["Map pin"])

    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", 16, -94)
    hint:SetWidth(WIDTH - 32)
    hint:SetJustifyH("LEFT")
    hint:SetText(L["Leave empty to start from where you are. Type a zone, a flight point, \"zone 42 65\" or \"pin\"."])

    local go = makeButton(f, L["Get directions"], 140)
    go:SetPoint("TOPLEFT", 16, -124)
    go:SetScript("OnClick", function() UI:Compute() end)

    local swap = makeButton(f, L["Swap"], 70)
    swap:SetPoint("LEFT", go, "RIGHT", 6, 0)
    swap:SetScript("OnClick", function()
        local a, b = UI.startEdit:GetText(), UI.destEdit:GetText()
        UI.startEdit:SetText(b)
        UI.destEdit:SetText(a)
    end)

    local mount = makeButton(f, mountLabel(), 150)
    mount:SetPoint("LEFT", swap, "RIGHT", 6, 0)
    mount:SetScript("OnClick", function(self)
        ns.db.mountSpeed = MOUNT_CYCLE[ns.db.mountSpeed] or "auto"
        self:SetText(mountLabel())
        if UI.options then UI:Compute() end
    end)
    self.mountButton = mount

    local known = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    known:SetSize(24, 24)
    known:SetPoint("TOPLEFT", 14, -148)
    known:SetChecked(ns.db.knownOnly)
    local knownText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    knownText:SetPoint("LEFT", known, "RIGHT", 2, 0)
    knownText:SetText(L["Known flight points only"])
    known:SetScript("OnClick", function(self)
        ns.db.knownOnly = self:GetChecked() and true or false
        if UI.options then UI:Compute() end
    end)

    local avoid = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    avoid:SetSize(24, 24)
    avoid:SetPoint("TOPLEFT", 224, -148)
    avoid:SetChecked(ns.db.avoidContested)
    local avoidText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    avoidText:SetPoint("LEFT", avoid, "RIGHT", 2, 0)
    avoidText:SetText(L["Avoid contested zones"])
    avoid:SetScript("OnClick", function(self)
        ns.db.avoidContested = self:GetChecked() and true or false
        if UI.options then UI:Compute() end
    end)

    -- Travel options.
    self.optionButtons = {}
    for i = 1, ROWS do
        local b = CreateFrame("Button", nil, f)
        b:SetSize(WIDTH - 32, 30)
        b:SetPoint("TOPLEFT", 16, -176 - (i - 1) * 32)
        b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        b.bg:SetColorTexture(1, 1, 1, 0.06)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(24, 24)
        b.icon:SetPoint("LEFT", 4, 0)
        b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        b.label:SetPoint("LEFT", b.icon, "RIGHT", 8, 0)
        b.info = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        b.info:SetPoint("RIGHT", -8, 0)
        b:SetScript("OnClick", function() UI:Select(i) end)
        b:Hide()
        self.optionButtons[i] = b
    end

    -- Steps.
    local scroll = CreateFrame("ScrollFrame", "WowGPSScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -342)
    scroll:SetPoint("BOTTOMRIGHT", -34, 44)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(WIDTH - 60, 10)
    scroll:SetScrollChild(content)
    local text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT")
    text:SetWidth(WIDTH - 60)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetSpacing(3)
    self.stepsText, self.stepsContent = text, content

    local nav = makeButton(f, L["Navigate"], 150)
    nav:SetPoint("BOTTOMLEFT", 16, 12)
    nav:SetScript("OnClick", function()
        local opt = UI:Selected()
        ns.Nav:Start(opt and opt.path)
    end)
    local stop = makeButton(f, L["Stop"], 80)
    stop:SetPoint("LEFT", nav, "RIGHT", 6, 0)
    stop:SetScript("OnClick", function() ns.Nav:Stop() end)
    local routes = makeButton(f, L["Send to Routes"], 150)
    routes:SetPoint("BOTTOMRIGHT", -16, 12)
    routes:SetScript("OnClick", function() UI:ExportToRoutes() end)
    self.routesButton = routes

    -- Suggestion popup.
    local box = CreateFrame("Frame", nil, f, "BackdropTemplate")
    box:SetFrameStrata("DIALOG")
    box:SetWidth(262)
    if box.SetBackdrop then
        box:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        box:SetBackdropColor(0, 0, 0, 0.95)
    end
    box.buttons = {}
    for i = 1, 6 do
        local b = CreateFrame("Button", nil, box)
        b:SetSize(254, 18)
        b:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 18)
        b:SetNormalFontObject("GameFontHighlightSmall")
        b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        b:SetText(" ")
        local fs = b:GetFontString()
        if fs then
            fs:ClearAllPoints()
            fs:SetPoint("LEFT", 4, 0)
        end
        b:SetScript("OnClick", function(self)
            self.target:SetText(self.value)
            self.target:ClearFocus()
            box:Hide()
        end)
        box.buttons[i] = b
    end
    box:Hide()
    self.suggest = box

    f:Hide()
    return f
end

function UI:Toggle()
    local f = self:Create()
    if f:IsShown() then f:Hide() else f:Show() self:Refresh() end
end

function UI:Selected()
    return self.options and self.options[self.selected or 0]
end

function UI:Select(i)
    if self.options and self.options[i] and self.options[i].path then
        self.selected = i
        self:Refresh()
    end
end

-- Resolves both fields and computes the options. Used by the slash command too.
function UI:Compute(startText, destText)
    self:Create()
    if startText then self.startEdit:SetText(startText) end
    if destText then self.destEdit:SetText(destText) end
    self.options, self.selected = nil, nil

    local destInput = self.destEdit:GetText()
    if destInput:gsub("%s", "") == "" then
        self:ShowMessage(L["Enter a destination."])
        return
    end
    local start, err = ns.Places:Resolve(self.startEdit:GetText())
    local dest
    if start then dest, err = ns.Places:Resolve(destInput) end
    if not dest then
        self:ShowMessage(err)
        return
    end
    local options, perr = ns.Router:Plan(start, dest)
    if not options then
        self:ShowMessage(perr)
        return
    end
    self.options, self.destName = options, dest.name or destInput
    for i = 1, #options do
        if options[i].fastest then self.selected = i end
    end
    self.frame:Show()
    self:Refresh()
    return options
end

function UI:ShowMessage(msg)
    for i = 1, ROWS do self.optionButtons[i]:Hide() end
    self.stepsText:SetText("|cffff6060" .. (msg or "?") .. "|r")
    self.stepsContent:SetHeight(self.stepsText:GetStringHeight() + 10)
    self.frame:Show()
end

function UI:Refresh()
    if not self.frame or not self.frame:IsShown() then return end
    self.mountButton:SetText(mountLabel())
    self.routesButton:SetEnabled(ns.RoutesBridge:Available())
    if not self.options then return end

    for i = 1, ROWS do
        local b, opt = self.optionButtons[i], self.options[i]
        if opt then
            b.icon:SetTexture(KIND_ICON[opt.key])
            b.label:SetText(opt.label .. (opt.fastest and ("  |cff40ff40" .. L["fastest"] .. "|r") or ""))
            if opt.path then
                b.info:SetText(ns.FormatTime(opt.path.time) .. "  |cffaaaaaa" .. ns.FormatDist(opt.path.dist) .. "|r")
            else
                b.info:SetText("|cff808080" .. (opt.key == "hearth" and L["not useful"] or L["no route"]) .. "|r")
            end
            if i == self.selected then
                b.bg:SetColorTexture(0.2, 0.6, 1, 0.25)
            else
                b.bg:SetColorTexture(1, 1, 1, 0.06)
            end
            b:Show()
        else
            b:Hide()
        end
    end

    local opt = self:Selected()
    local lines = {}
    if not (opt and opt.path) then
        -- Nothing selectable: still explain why (e.g. Hearthstone on cooldown).
        for _, o in ipairs(self.options) do
            for _, note in ipairs(o.notes) do
                if not o.path then lines[#lines + 1] = "|cffffd040" .. o.label .. ": " .. note .. "|r" end
            end
        end
    end
    if opt and opt.path then
        local navPath = ns.Nav.path
        for i, st in ipairs(opt.path.steps) do
            local where = string.format("%s %.1f, %.1f", ns.Maps:Name(st.to.map), st.to.x * 100, st.to.y * 100)
            local line = string.format("%d. %s  |cffaaaaaa(%s · %s)|r", i, st.text, where, ns.FormatTime(st.time))
            if navPath == opt.path and ns.Nav.index == i then
                line = "|cff40ff40> " .. line .. "|r"
            end
            lines[#lines + 1] = line
        end
        lines[#lines + 1] = ""
        lines[#lines + 1] = string.format(L["Total: %s, %s"], ns.FormatTime(opt.path.time), ns.FormatDist(opt.path.dist))
        for _, note in ipairs(opt.notes) do
            lines[#lines + 1] = "|cffffd040" .. note .. "|r"
        end
        local h = self.options[ROWS]
        if h and h ~= opt and not h.path then
            for _, note in ipairs(h.notes) do lines[#lines + 1] = "|cff909090" .. note .. "|r" end
        end
    end
    self.stepsText:SetText(table.concat(lines, "\n"))
    self.stepsContent:SetHeight(self.stepsText:GetStringHeight() + 10)
end

function UI:ExportToRoutes()
    local opt = self:Selected()
    if not opt or not opt.path then
        ns:Print(L["Nothing to navigate: compute a route first."])
        return
    end
    ns.RoutesBridge:Export(opt.path, self.destName)
end

function WowGPS_OnAddonCompartmentClick()
    UI:Toggle()
end

-- UILib Luau (Mobile-first) - otimizado para executores Android (Delta)
-- Use: local ui = UILib:CreateWindow("Meu Painel"); local f = ui:CreateFolder("Pasta 1"); ui:CreateToggle(f, "Ativar ESP", false, fn)

local UILib = {}
UILib.__index = UILib

-- Serviços
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

-- Persistência
local STATE_FILE = "uilib_mobile_state.json"
local hasWritefile = type(writefile) == "function" and type(readfile) == "function"
local function safeEncode(t)
    local ok, res = pcall(function() return HttpService:JSONEncode(t) end)
    return ok and res or "{}"
end
local function safeDecode(s)
    local ok, res = pcall(function() return HttpService:JSONDecode(s) end)
    return ok and res or nil
end
local function saveStateFile(name, data)
    local json = safeEncode(data)
    if hasWritefile then
        pcall(function() writefile(name, json) end)
    else
        _G.UILIB_PERSIST = _G.UILIB_PERSIST or {}
        _G.UILIB_PERSIST[name] = json
    end
end
local function loadStateFile(name)
    if hasWritefile then
        local ok, content = pcall(function() return readfile(name) end)
        if ok and content then return safeDecode(content) end
        return nil
    else
        if _G.UILIB_PERSIST and _G.UILIB_PERSIST[name] then
            return safeDecode(_G.UILIB_PERSIST[name])
        end
        return nil
    end
end

-- abort if disabled
if _G.UILibDisabled then return UILib end

-- util
local function new(cls, props)
    local o = Instance.new(cls)
    for k,v in pairs(props or {}) do
        if k == "Parent" then o.Parent = v else o[k] = v end
    end
    return o
end

local COLORS = {
    PANEL_BG = Color3.fromRGB(11,11,11),
    BUTTON_BLUE = Color3.fromRGB(43,140,255),
    BUTTON_BLUE_DARK = Color3.fromRGB(31,111,214),
    SLIDER_GREEN = Color3.fromRGB(45,224,106),
    INPUT_PURPLE = Color3.fromRGB(176,124,255),
    TEXT = Color3.fromRGB(230,230,230),
    MUTED = Color3.fromRGB(150,150,150),
}

-- create ScreenGui (prefer CoreGui)
local function createScreenGui(name)
    local sg = Instance.new("ScreenGui")
    sg.Name = name or "UILibMobile"
    sg.ResetOnSpawn = false
    local ok, _ = pcall(function() sg.Parent = CoreGui end)
    if not ok then
        local plr = Players.LocalPlayer
        if plr and plr:FindFirstChild("PlayerGui") then sg.Parent = plr.PlayerGui else sg.Parent = game:GetService("StarterGui") end
    end
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Global
    return sg
end

-- touch helpers: tap vs drag vs long-press
local function touchDetector(guiObject)
    -- returns table with events: OnTap(fn), OnDrag(fn(dx,dy)), OnLongPress(fn)
    local handlers = { tap = {}, drag = {}, long = {} }
    local active = {}
    local longThreshold = 0.6
    local tapMaxDuration = 0.25
    local dragThreshold = 8

    guiObject.InputBegan:Connect(function(inp)
        if not (inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1) then return end
        local id = inp.UserInputState .. tostring(inp)
        active[id] = {
            startedAt = tick(),
            startPos = inp.Position,
            moved = false,
        }
        -- long press coroutine
        spawn(function()
            local start = active[id].startedAt
            while active[id] do
                if tick() - start >= longThreshold and not active[id].moved then
                    for _,fn in ipairs(handlers.long) do pcall(fn, inp.Position) end
                    break
                end
                wait(0.05)
            end
        end)
        inp.Changed:Connect(function()
            if inp.UserInputState == Enum.UserInputState.End then
                local a = active[id]
                if a then
                    local dur = tick() - a.startedAt
                    local dist = (inp.Position - a.startPos).Magnitude
                    if dur <= tapMaxDuration and dist <= dragThreshold then
                        for _,fn in ipairs(handlers.tap) do pcall(fn) end
                    end
                    active[id] = nil
                end
            end
        end)
    end)
    guiObject.InputChanged:Connect(function(inp)
        if not (inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseMovement) then return end
        for k,v in pairs(active) do
            local dist = (inp.Position - v.startPos).Magnitude
            if dist > dragThreshold then
                v.moved = true
                for _,fn in ipairs(handlers.drag) do pcall(fn, inp.Position - v.startPos) end
            end
        end
    end)

    return {
        OnTap = function(fn) table.insert(handlers.tap, fn) end,
        OnDrag = function(fn) table.insert(handlers.drag, fn) end,
        OnLongPress = function(fn) table.insert(handlers.long, fn) end,
    }
end

-- create toggle, slider, textbox (mobile-friendly sizes)
local function createToggle(parent, labelText, default)
    local frame = new("Frame",{Parent=parent, Size=UDim2.new(1,0,0,44), BackgroundTransparency=1})
    local lbl = new("TextLabel",{Parent=frame, Text=labelText or "Toggle", TextColor3=COLORS.TEXT, BackgroundTransparency=1, Font=Enum.Font.Gotham, TextSize=16, Position=UDim2.new(0,12,0,8), Size=UDim2.new(.6,0,0,24), TextXAlignment=Enum.TextXAlignment.Left})
    local box = new("Frame",{Parent=frame, Size=UDim2.new(0,64,0,36), Position=UDim2.new(1,-76,0,4), BackgroundColor3=Color3.fromRGB(60,60,60)})
    new("UICorner",{Parent=box, CornerRadius=UDim.new(0,20)})
    local knob = new("Frame",{Parent=box, Size=UDim2.new(0,28,0,28), Position=UDim2.new(0,4,0,4), BackgroundColor3=Color3.fromRGB(18,18,18)})
    new("UICorner",{Parent=knob, CornerRadius=UDim.new(0,20)})
    local state = default and true or false
    local function apply()
        if state then
            box.BackgroundColor3 = COLORS.BUTTON_BLUE
            TweenService:Create(knob, TweenInfo.new(0.12), {Position=UDim2.new(0,32,0,4)}):Play()
            knob.BackgroundColor3 = Color3.new(1,1,1)
        else
            box.BackgroundColor3 = Color3.fromRGB(60,60,60)
            TweenService:Create(knob, TweenInfo.new(0.12), {Position=UDim2.new(0,4,0,4)}):Play()
            knob.BackgroundColor3 = Color3.fromRGB(18,18,18)
        end
    end
    apply()
    local det = touchDetector(box)
    det.OnTap(function() state = not state; apply() end)
    return {
        Frame = frame,
        Get = function() return state end,
        Set = function(v) state = not not v; apply() end,
        OnChange = function(fn)
            det.OnTap(function() state = not state; apply(); pcall(fn, state) end)
        end
    }
end

local function createSlider(parent, label, minv, maxv, default)
    minv = minv or 0; maxv = maxv or 100; default = default or math.floor((minv+maxv)/2)
    local frame = new("Frame",{Parent=parent, Size=UDim2.new(1,0,0,64), BackgroundTransparency=1})
    new("TextLabel",{Parent=frame, Text=label or "Slider", TextColor3=COLORS.TEXT, BackgroundTransparency=1, Font=Enum.Font.Gotham, TextSize=16, Position=UDim2.new(0,12,0,6), Size=UDim2.new(1,-24,0,20), TextXAlignment=Enum.TextXAlignment.Left})
    local track = new("Frame",{Parent=frame, Size=UDim2.new(1,-96,0,12), Position=UDim2.new(0,12,0,36), BackgroundColor3=Color3.fromRGB(40,40,40)})
    new("UICorner",{Parent=track, CornerRadius=UDim.new(0,8)})
    local fill = new("Frame",{Parent=track, Size=UDim2.new((default-minv)/(maxv-minv),0,1,0), BackgroundColor3=COLORS.SLIDER_GREEN})
    new("UICorner",{Parent=fill, CornerRadius=UDim.new(0,8)})
    local knob = new("Frame",{Parent=track, Size=UDim2.new(0,28,0,28), Position=UDim2.new((default-minv)/(maxv-minv),-14,0,-8), BackgroundColor3=COLORS.SLIDER_GREEN})
    new("UICorner",{Parent=knob, CornerRadius=UDim.new(0,20)})
    local valLabel = new("TextLabel",{Parent=frame, Text=tostring(default), TextColor3=COLORS.TEXT, BackgroundTransparency=1, Font=Enum.Font.Gotham, TextSize=16, Position=UDim2.new(1,-72,0,26), Size=UDim2.new(0,64,0,24)})
    local dragging = false
    local function updateFromPos(x)
        local abs = math.clamp(x - track.AbsolutePosition.X, 0, track.AbsoluteSize.X)
        local pct = abs / track.AbsoluteSize.X
        local v = math.floor(minv + pct * (maxv - minv) + 0.5)
        fill.Size = UDim2.new(pct,0,1,0)
        knob.Position = UDim2.new(pct, -14, 0, -8)
        valLabel.Text = tostring(v)
        return v
    end
    knob.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end
    end)
    UserInputService.InputEnded:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
    UserInputService.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseMovement) then updateFromPos(inp.Position.X) end
    end)
    track.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then
            local v = updateFromPos(inp.Position.X)
        end
    end)
    return {
        Frame = frame,
        Get = function() return tonumber(valLabel.Text) end,
        Set = function(v)
            v = math.clamp(tonumber(v) or default, minv, maxv)
            local pct = (v - minv) / (maxv - minv)
            fill.Size = UDim2.new(pct,0,1,0)
            knob.Position = UDim2.new(pct,-14,0,-8)
            valLabel.Text = tostring(v)
        end,
        OnChange = function(fn)
            spawn(function()
                local last = tonumber(valLabel.Text)
                while frame.Parent do
                    local cur = tonumber(valLabel.Text)
                    if cur ~= last then pcall(fn, cur); last = cur end
                    wait(0.06)
                end
            end)
        end
    }
end

local function createTextBox(parent, label, placeholder)
    local frame = new("Frame",{Parent=parent, Size=UDim2.new(1,0,0,72), BackgroundTransparency=1})
    new("TextLabel",{Parent=frame, Text=label or "Input", TextColor3=COLORS.TEXT, BackgroundTransparency=1, Font=Enum.Font.Gotham, TextSize=16, Position=UDim2.new(0,12,0,6), Size=UDim2.new(1,-24,0,20), TextXAlignment=Enum.TextXAlignment.Left})
    local box = new("TextBox",{Parent=frame, Text="", PlaceholderText=placeholder or "", Size=UDim2.new(1,-24,0,36), Position=UDim2.new(0,12,0,30), BackgroundColor3=COLORS.INPUT_PURPLE, TextColor3=COLORS.TEXT, Font=Enum.Font.Gotham, TextSize=16})
    new("UICorner",{Parent=box, CornerRadius=UDim.new(0,8)})
    return {
        Frame = frame,
        Get = function() return box.Text end,
        Set = function(v) box.Text = tostring(v or "") end,
        OnChange = function(fn) box.Changed:Connect(function(prop) if prop == "Text" then pcall(fn, box.Text) end end) end
    }
end

-- Mobile-optimized window creation
function UILib:CreateWindow(title, options)
    options = options or {}
    local saved = loadStateFile(STATE_FILE) or {
        disabled = false,
        folders = { {id="f_default", name="Pasta 1", data={}} },
        selected = "f_default",
        panelPos = {x=50,y=80},
        floatPos = nil,
    }
    if saved.disabled or _G.UILibDisabled then _G.UILibDisabled = true; return nil end

    local sg = createScreenGui("UILib_Mobile_" .. (title or "Window"))
    -- main panel
    local panel = new("Frame",{Parent=sg, Name="Panel", Size=UDim2.new(0,420,0,520), Position=UDim2.new(0, saved.panelPos.x or 50, 0, saved.panelPos.y or 80), BackgroundColor3=COLORS.PANEL_BG, BorderSizePixel=0})
    new("UICorner",{Parent=panel, CornerRadius=UDim.new(0,12)})
    panel.Active = true

    -- header
    local header = new("Frame",{Parent=panel, Size=UDim2.new(1,0,0,56), BackgroundTransparency=1})
    local titleLbl = new("TextLabel",{Parent=header, Text=title or "Painel UI", TextColor3=COLORS.TEXT, BackgroundTransparency=1, Font=Enum.Font.GothamBold, TextSize=20, Position=UDim2.new(0,16,0,10), Size=UDim2.new(.6,0,0,36), TextXAlignment=Enum.TextXAlignment.Left})
    -- controls
    local btnMin = new("TextButton",{Parent=header, Text="−", Size=UDim2.new(0,56,0,40), Position=UDim2.new(1,-124,0,8), BackgroundTransparency=0, BackgroundColor3=Color3.fromRGB(18,18,18), Font=Enum.Font.GothamBold, TextSize=28, TextColor3=COLORS.TEXT, BorderSizePixel=0})
    new("UICorner",{Parent=btnMin, CornerRadius=UDim.new(0,10)})
    local btnClose = new("TextButton",{Parent=header, Text="✕", Size=UDim2.new(0,56,0,40), Position=UDim2.new(1,-64,0,8), BackgroundTransparency=0, BackgroundColor3=Color3.fromRGB(18,18,18), Font=Enum.Font.GothamBold, TextSize=22, TextColor3=Color3.fromRGB(255,107,107), BorderSizePixel=0})
    new("UICorner",{Parent=btnClose, CornerRadius=UDim.new(0,10)})

    -- body
    local body = new("Frame",{Parent=panel, Position=UDim2.new(0,0,0,56), Size=UDim2.new(1,0,1,-56), BackgroundTransparency=1})
    local folderList = new("Frame",{Parent=body, Size=UDim2.new(0,140,1,0), BackgroundTransparency=1})
    new("UICorner",{Parent=folderList, CornerRadius=UDim.new(0,10)})
    local folderScroll = new("ScrollingFrame",{Parent=folderList, Size=UDim2.new(1,-12,1,-80), Position=UDim2.new(0,6,0,6), BackgroundTransparency=1, ScrollBarThickness=8})
    local folderLayout = new("UIListLayout",{Parent=folderScroll, Padding=UDim.new(0,8), SortOrder=Enum.SortOrder.LayoutOrder})
    local folderAdd = new("Frame",{Parent=folderList, Size=UDim2.new(1,-12,0,72), Position=UDim2.new(0,6,1,-82), BackgroundTransparency=1})
    local newFolderBox = new("TextBox",{Parent=folderAdd, PlaceholderText="Nova pasta...", Size=UDim2.new(0.65,0,1,0), Position=UDim2.new(0,0,0,0), BackgroundColor3=Color3.fromRGB(26,26,26), TextColor3=COLORS.TEXT, BorderSizePixel=0, Font=Enum.Font.Gotham, TextSize=16})
    new("UICorner",{Parent=newFolderBox, CornerRadius=UDim.new(0,8)})
    local addBtn = new("TextButton",{Parent=folderAdd, Text="+", Size=UDim2.new(0.33,0,1,0), Position=UDim2.new(0.67,6,0,0), BackgroundColor3=COLORS.BUTTON_BLUE, TextColor3=Color3.new(1,1,1), Font=Enum.Font.GothamBold, TextSize=22, BorderSizePixel=0})
    new("UICorner",{Parent=addBtn, CornerRadius=UDim.new(0,8)})

    local functionsArea = new("Frame",{Parent=body, Size=UDim2.new(1,-152,1,0), Position=UDim2.new(0,152,0,0), BackgroundTransparency=1})
    local functionContainer = new("Frame",{Parent=functionsArea, Size=UDim2.new(1,0,1,0), BackgroundTransparency=1})

    -- mini widget
    local miniWidget = new("Frame",{Parent=sg, Size=UDim2.new(0,180,0,56), Position=UDim2.new(1,-206,0,26), BackgroundColor3=COLORS.PANEL_BG, BorderSizePixel=0})
    new("UICorner",{Parent=miniWidget, CornerRadius=UDim.new(0,10)})
    local miniLabel = new("TextLabel",{Parent=miniWidget, Text="Painel minimizado", BackgroundTransparency=1, TextColor3=COLORS.TEXT, Font=Enum.Font.Gotham, TextSize=16, Position=UDim2.new(0,12,0,8)})
    local miniRestore = new("TextButton",{Parent=miniWidget, Text="+", BackgroundColor3=COLORS.BUTTON_BLUE, TextColor3=Color3.new(1,1,1), Size=UDim2.new(0,64,0,40), Position=UDim2.new(1,-76,0,8), BorderSizePixel=0})
    new("UICorner",{Parent=miniRestore, CornerRadius=UDim.new(0,8)})
    miniWidget.Visible = false

    -- floating button
    local floating = new("TextButton",{Parent=sg, Text="UI", Size=UDim2.new(0,72,0,72), Position = saved.floatPos and UDim2.new(0,saved.floatPos.x,0,saved.floatPos.y) or UDim2.new(1,-110,1,-110), BackgroundColor3=COLORS.BUTTON_BLUE, TextColor3=Color3.new(1,1,1), BorderSizePixel=0})
    new("UICorner",{Parent=floating, CornerRadius=UDim.new(1,0)})

    -- folder storage
    local folders = saved.folders or { {id="f_default", name="Pasta 1", data={}} }
    local selected = saved.selected or folders[1].id

    local function save()
        local pos = panel.Position
        saved.panelPos = { x = pos.X.Offset, y = pos.Y.Offset }
        local fpos = floating.Position
        saved.floatPos = { x = fpos.X.Offset, y = fpos.Y.Offset }
        saved.folders = folders
        saved.selected = selected
        saveStateFile(STATE_FILE, saved)
    end

    local function rebuildFolderList()
        for _,c in pairs(folderScroll:GetChildren()) do if not c:IsA("UIListLayout") then c:Destroy() end end
        for i,f in ipairs(folders) do
            local btn = new("TextButton",{Parent=folderScroll, Size=UDim2.new(1,-12,0,56), BackgroundColor3=Color3.fromRGB(26,26,26), TextColor3=COLORS.TEXT, Text=f.name, Font=Enum.Font.GothamBold, TextSize=16, AutoButtonColor=false})
            new("UICorner",{Parent=btn, CornerRadius=UDim.new(0,10)})
            if f.id == selected then btn.BackgroundColor3 = Color3.fromRGB(28,78,160) end

            -- touch detection for mobile: tap selects, long-press opens actions (rename/delete)
            local det = touchDetector(btn)
            det.OnTap(function()
                selected = f.id
                rebuildFolderList()
                renderFunctionArea()
                save()
            end)
            det.OnLongPress(function(pos)
                -- action menu
                local menu = new("Frame",{Parent=sg, Size=UDim2.new(0,220,0,120), Position=UDim2.new(0, math.clamp(pos.X - 110, 12, workspace.CurrentCamera.ViewportSize.X - 232), 0, math.clamp(pos.Y - 20, 12, workspace.CurrentCamera.ViewportSize.Y - 140)), BackgroundColor3=Color3.fromRGB(20,20,20), BorderSizePixel=0})
                new("UICorner",{Parent=menu, CornerRadius=UDim.new(0,10)})
                local rename = new("TextButton",{Parent=menu, Text="Renomear", Size=UDim2.new(1,0,0,48), Position=UDim2.new(0,0,0,8), BackgroundColor3=COLORS.BUTTON_BLUE, TextColor3=Color3.new(1,1,1), Font=Enum.Font.GothamBold, TextSize=18, BorderSizePixel=0})
                new("UICorner",{Parent=rename, CornerRadius=UDim.new(0,8)})
                local del = new("TextButton",{Parent=menu, Text="Excluir", Size=UDim2.new(1,0,0,48), Position=UDim2.new(0,0,0,64), BackgroundColor3=Color3.fromRGB(200,60,60), TextColor3=Color3.new(1,1,1), Font=Enum.Font.GothamBold, TextSize=18, BorderSizePixel=0})
                new("UICorner",{Parent=del, CornerRadius=UDim.new(0,8)})
                -- rename action
                local detR = touchDetector(rename)
                detR.OnTap(function()
                    menu:Destroy()
                    -- overlay TextBox for renaming
                    local overlay = new("Frame",{Parent=sg, Size=UDim2.new(1,0,1,0), BackgroundTransparency=0.4, BackgroundColor3=Color3.new(0,0,0)})
                    local box = new("TextBox",{Parent=overlay, Size=UDim2.new(0,320,0,56), Position=UDim2.new(0.5,-160,0.5,-28), BackgroundColor3=Color3.fromRGB(28,28,28), TextColor3=COLORS.TEXT, Text=f.name, Font=Enum.Font.Gotham, TextSize=18})
                    new("UICorner",{Parent=box, CornerRadius=UDim.new(0,10)})
                    box:CaptureFocus()
                    box.FocusLost:Connect(function(enter)
                        if box.Text:match("%S") then f.name = box.Text end
                        overlay:Destroy()
                        rebuildFolderList()
                        save()
                    end)
                end)
                local detD = touchDetector(del)
                detD.OnTap(function()
                    menu:Destroy()
                    -- confirm overlay
                    local overlay = new("Frame",{Parent=sg, Size=UDim2.new(1,0,1,0), BackgroundTransparency=0.4, BackgroundColor3=Color3.new(0,0,0)})
                    local cbox = new("Frame",{Parent=overlay, Size=UDim2.new(0,320,0,160), Position=UDim2.new(0.5,-160,0.5,-80), BackgroundColor3=Color3.fromRGB(24,24,24)})


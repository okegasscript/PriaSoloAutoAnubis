-- ============================================================
-- FarmESP.lua
-- Modul ESP untuk menampilkan jumlah mutasi di atas tanaman
-- ============================================================
local FarmESP = {}

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Daftar mutasi resmi (hardcode + dari MutationHandler)
local officialMutations = {}
local function loadMutations()
    local Modules = ReplicatedStorage:FindFirstChild("Modules")
    if Modules then
        local handler = Modules:FindFirstChild("MutationHandler")
        if handler then
            local ok, h = pcall(require, handler)
            if ok and h and h.GetMutations then
                for name, _ in pairs(h:GetMutations()) do
                    officialMutations[name] = true
                end
                return
            end
        end
    end
    -- fallback hardcode (daftar panjang disingkat, Anda bisa tambahkan sendiri)
    local fallback = {"Wet","Shiny","Gold","Shocked","Windstruck","Dawnbound","Beanbound","Twisted","Cloudtouched","Voidtouched"}
    for _, name in ipairs(fallback) do officialMutations[name] = true end
end
loadMutations()

local espFolder = nil
local espObjects = {}
local connection = nil

local function getPlantsPhysical()
    local p = Workspace:FindFirstChild("Farm")
    if p then p = p:FindFirstChild("Farm") end
    if p then p = p:FindFirstChild("Important") end
    if p then p = p:FindFirstChild("Plants_Physical") end
    return p
end

local function getTarget(folder)
    local fruits = folder:FindFirstChild("Fruits")
    if fruits then
        local t = fruits:FindFirstChild(folder.Name)
        if not t then
            local children = fruits:GetChildren()
            if #children > 0 then t = children[1] end
        end
        return t
    end
    return folder
end

local function collectMutations(obj)
    local muts = {}
    for k, v in pairs(obj:GetAttributes()) do
        if v == true and officialMutations[k] then
            muts[k] = true
        end
    end
    return muts
end

local function scanPlants()
    local plants = getPlantsPhysical()
    if not plants then return {} end

    local list = {}
    for _, folder in ipairs(plants:GetChildren()) do
        local target = getTarget(folder)
        if target then
            local muts = collectMutations(target)
            for _, d in ipairs(target:GetDescendants()) do
                for k, v in pairs(d:GetAttributes()) do
                    if v == true and officialMutations[k] then
                        muts[k] = true
                    end
                end
            end
            local count = 0
            for _ in pairs(muts) do count = count + 1 end

            local part = target:IsA("BasePart") and target or target:FindFirstChildWhichIsA("BasePart")
            if not part then
                for _, d in ipairs(target:GetDescendants()) do
                    if d:IsA("BasePart") then part = d; break end
                end
            end
            local pos = part and part.Position or target:GetPivot().Position

            table.insert(list, {
                name = folder.Name,
                mutCount = count,
                position = pos,
                uuid = target:GetAttribute("UUID") or target:GetAttribute("OBJECT_UUID") or tostring(target)
            })
        end
    end
    return list
end

local function createESP(data)
    if not espFolder then
        espFolder = Instance.new("Folder")
        espFolder.Name = "FarmESP"
        espFolder.Parent = Workspace
    end

    local part = Instance.new("Part")
    part.Size = Vector3.new(0.5, 0.5, 0.5)
    part.Position = data.position
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 1
    part.Parent = espFolder

    local bill = Instance.new("BillboardGui")
    bill.Size = UDim2.new(0, 200, 0, 50)
    bill.StudsOffset = Vector3.new(0, 4, 0)
    bill.Adornee = part
    bill.AlwaysOnTop = true
    bill.Parent = espFolder

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = string.format("%s: %d", data.name, data.mutCount)
    label.TextColor3 = Color3.fromRGB(255,255,255)
    label.TextSize = 20
    label.Font = Enum.Font.SourceSansBold
    label.TextStrokeColor3 = Color3.new(0,0,0)
    label.TextStrokeTransparency = 0
    label.Parent = bill

    return { part = part, bill = bill, label = label, uuid = data.uuid }
end

local function updateESP()
    local plants = scanPlants()
    local current = {}
    for _, p in ipairs(plants) do current[p.uuid] = p end

    -- remove stale
    for uuid, obj in pairs(espObjects) do
        if not current[uuid] then
            obj.part:Destroy()
            obj.bill:Destroy()
            espObjects[uuid] = nil
        end
    end

    -- add/update
    for uuid, data in pairs(current) do
        local obj = espObjects[uuid]
        if not obj then
            obj = createESP(data)
            espObjects[uuid] = obj
        else
            obj.part.Position = data.position
            obj.label.Text = string.format("%s: %d", data.name, data.mutCount)
        end
    end
end

-- ============================================================
-- PUBLIC METHODS
-- ============================================================

function FarmESP.start()
    if connection then return end
    updateESP()
    connection = RunService.Heartbeat:Connect(function()
        if tick() % 2 < 0.05 then
            pcall(updateESP)
        end
    end)
    print("✅ FarmESP started.")
end

function FarmESP.stop()
    if connection then
        connection:Disconnect()
        connection = nil
    end
    for _, obj in pairs(espObjects) do
        obj.part:Destroy()
        obj.bill:Destroy()
    end
    espObjects = {}
    if espFolder then
        espFolder:Destroy()
        espFolder = nil
    end
    print("✅ FarmESP stopped.")
end

return FarmESP

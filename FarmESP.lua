-- ============================================================
-- FarmESP.lua - Menampilkan jumlah mutasi untuk SETIAP buah
-- ============================================================
local FarmESP = {}

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Daftar mutasi resmi
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
    -- fallback hardcode (contoh kecil)
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

-- Fungsi mengumpulkan mutasi dari atribut true pada objek
local function collectMutations(obj)
    local muts = {}
    for k, v in pairs(obj:GetAttributes()) do
        if v == true and officialMutations[k] then
            muts[k] = true
        end
    end
    return muts
end

-- Fungsi scan: untuk setiap tanaman, jika ada Fruits, scan semua anak di Fruits
local function scanAllPlants()
    local plantsPhysical = getPlantsPhysical()
    if not plantsPhysical then return {} end

    local plantList = {}
    local index = 0

    for _, plantFolder in ipairs(plantsPhysical:GetChildren()) do
        local fruitsFolder = plantFolder:FindFirstChild("Fruits")
        if fruitsFolder then
            -- Multi-fruit: loop setiap buah di folder Fruits
            for _, fruit in ipairs(fruitsFolder:GetChildren()) do
                if fruit:IsA("BasePart") or fruit:IsA("Model") or fruit:IsA("Folder") then
                    index = index + 1
                    -- Kumpulkan mutasi dari fruit dan descendants
                    local muts = collectMutations(fruit)
                    for _, desc in ipairs(fruit:GetDescendants()) do
                        for k, v in pairs(desc:GetAttributes()) do
                            if v == true and officialMutations[k] then
                                muts[k] = true
                            end
                        end
                    end
                    local mutCount = 0
                    for _ in pairs(muts) do mutCount = mutCount + 1 end

                    -- Cari posisi
                    local part = fruit:IsA("BasePart") and fruit or fruit:FindFirstChildWhichIsA("BasePart")
                    if not part then
                        for _, desc in ipairs(fruit:GetDescendants()) do
                            if desc:IsA("BasePart") then part = desc; break end
                        end
                    end
                    local position = part and part.Position or fruit:GetPivot().Position

                    -- Buat UUID unik per buah
                    local uuid = fruit:GetAttribute("OBJECT_UUID") or fruit:GetAttribute("UUID") or plantFolder.Name .. "_fruit_" .. index

                    table.insert(plantList, {
                        name = plantFolder.Name .. " #" .. index,
                        mutCount = mutCount,
                        position = position,
                        uuid = uuid,
                    })
                end
            end
        else
            -- Single fruit: ambil tanaman itu sendiri
            local target = plantFolder
            local muts = collectMutations(target)
            for _, desc in ipairs(target:GetDescendants()) do
                for k, v in pairs(desc:GetAttributes()) do
                    if v == true and officialMutations[k] then
                        muts[k] = true
                    end
                end
            end
            local mutCount = 0
            for _ in pairs(muts) do mutCount = mutCount + 1 end

            local part = target:IsA("BasePart") and target or target:FindFirstChildWhichIsA("BasePart")
            if not part then
                for _, desc in ipairs(target:GetDescendants()) do
                    if desc:IsA("BasePart") then part = desc; break end
                end
            end
            local position = part and part.Position or target:GetPivot().Position
            local uuid = target:GetAttribute("UUID") or target:GetAttribute("OBJECT_UUID") or plantFolder.Name

            table.insert(plantList, {
                name = plantFolder.Name,
                mutCount = mutCount,
                position = position,
                uuid = uuid,
            })
        end
    end

    return plantList
end

-- ESP Management (sama seperti sebelumnya)
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
    label.TextSize = 18
    label.Font = Enum.Font.SourceSansBold
    label.TextStrokeColor3 = Color3.new(0,0,0)
    label.TextStrokeTransparency = 0
    label.Parent = bill

    return { part = part, bill = bill, label = label, uuid = data.uuid }
}

local function updateESP()
    local plants = scanAllPlants()
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

-- Public methods
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

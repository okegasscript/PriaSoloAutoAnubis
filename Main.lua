-- ============================================================
-- PRIASOLO HUB - FINAL SCRIPT v24 (FIXED)
-- (FIX: FUNGSI LENGKAP, SHOVEL BUAH MUTASI < 10)
-- (FIX v24.1: scanFruitsOnTree / findFruitOnTreeByExactMutation /
--             countFruitsOnTreeWithMutationAbove diubah dari local
--             menjadi global agar bisa dipanggil dari fungsi yang
--             dideklarasikan lebih awal di file ini, mis. shovelFruitsOnTree)
-- ============================================================

-- ============================================================
-- 1. LOAD WINDUI
-- ============================================================
local function loadWindUI()
    local urls = {
        "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua",
        "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua",
    }
    for attempt = 1, 3 do
        for _, url in ipairs(urls) do
            local ok, result = pcall(function()
                return loadstring(game:HttpGet(url))()
            end)
            if ok and result then
                return result
            end
        end
        task.wait(1)
    end
    return nil
end

local WindUI = loadWindUI()
if not WindUI then error("❌ Gagal memuat WindUI!") end

-- ============================================================
-- 2. LOAD MODULES
-- ============================================================
local FarmLib, DataPetModule

local function loadModules()
    local moduleUrls = {
        FarmLib = "https://raw.githubusercontent.com/okegasscript/PriaSoloAutoAnubis/refs/heads/main/FarmLib.lua",
        DataPetModule = "https://raw.githubusercontent.com/okegasscript/PriaSoloAutoAnubis/refs/heads/main/DataPetModule.lua",
    }

    for name, url in pairs(moduleUrls) do
        local ok, result = pcall(function()
            return loadstring(game:HttpGet(url))()
        end)
        if ok and result then
            if name == "FarmLib" then FarmLib = result end
            if name == "DataPetModule" then DataPetModule = result end
        else
            warn("❌ Gagal memuat: " .. name)
        end
    end

    if not FarmLib then error("❌ FarmLib gagal dimuat!") end
    if not DataPetModule then error("❌ DataPetModule gagal dimuat!") end
    print("✅ FarmLib & DataPetModule berhasil dimuat!")
end

loadModules()

-- ============================================================
-- 3. FARMESP (EMBEDDED) - ROBUST SCAN + UUID UNIK
-- ============================================================
local FarmESP = {}

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
    -- Hardcode fallback (sama seperti sebelumnya, disingkat)
    local hardcoded = {
        "Shocked","Windstruck","Dawnbound","Beanbound","Twisted","Cloudtouched","Voidtouched",
        "Wet","Fried","Molten","Vamp","Moonbled","Moist","Crystalized","Alienated","Brewed",
        "Ghostly","Spooky","Volcanic","Slashbound","Sliced","Severed","Alienlike","Galactic",
        "Drenched","Aurora","Chilled","Sundried","Wiltproof","Verdant","Paradisal","Glitched",
        "Gilded","Glimmering","Luminous","Cracked","Enchanted","Frozen","Disco","Choc","Plasma",
        "Heavenly","Burnt","Cooked","Sizzled","Gourmet","Moonlit","Moonbeam","Heartstruck","Luck",
        "Bloodlit","Peppermint","Zombified","Celestial","Meteoric","HoneyGlazed","Pollinated",
        "Amber","OldAmber","AncientAmber","Sandy","Clay","Ceramic","Friendbound","Tempestuous",
        "Infected","Radioactive","Chakra","FoxfireChakra","Cute","Heartbound","CorruptChakra",
        "CorruptFoxfireChakra","AscendedChakra","Static","HarmonisedChakra","HarmonisedFoxfireChakra",
        "Pasta","Sauce","Meatball","Spaghetti","Eclipsed","Enlightened","Tranquil","Corrupt",
        "Toxic","Acidic","Corrosive","Flaming","Blazing","Infernal","Goldsparkle","Oil","Boil",
        "OilBoil","Fortune","Bloom","Rot","Gloom","Blight","Pestilent","Umbral","Shadowbound",
        "Necrotic","Cyclonic","Maelstrom","Stormcharged","Cosmic","Webbed","Astral","Abyssal",
        "Graceful","Jackpot","Plagued","Biohazard","Contagion","Blitzshock","Junkshock","Touchdown",
        "Subzero","Lightcycle","Brainrot","Warped","Azure","Terran","Aromatic","Gnomed","Fall",
        "Blackout","Wilted","Withered","Desolate","Batty","Glossy","Leeched","Lush","Nocturnal",
        "Arid","Mirage","Stampede","Monsoon","Twilight","Typhoon","Wildfast","Tempered","Charcoal",
        "Geode","Supernatural","Stormbound","SunScorched","Riptide","Grim","Extraterrestrial","Mineral",
        "MindBender","Affluent","Fractured","Coin","Arctic","Ornamented","Glacial","Snowtouched",
        "Snowy","Eggnog","Blizzard","Opulent","Gale","Sleepy","Firework","Fiery","Fierywork",
        "Whalebound","Festive","Clockwork","Whimsical","Ash","Haze","Smoldering","Gummy","Floral",
        "Blossoming","Candy","Confection","Spotty","Pollinated_Poor","Pollinated_Fair","Pollinated_Good",
        "Pollinated_Godly","Honeygem","Jellygem","Resplendent","Sylvan","Ember","Shadow","Tidal",
        "Dream","Nightmare"
    }
    for _, name in ipairs(hardcoded) do
        officialMutations[name] = true
    end
end
loadMutations()

local espFolder = nil
local espObjects = {}
local espConnection = nil

local function getPlantsPhysical()
    local p = Workspace:FindFirstChild("Farm")
    if p then p = p:FindFirstChild("Farm") end
    if p then p = p:FindFirstChild("Important") end
    if p then p = p:FindFirstChild("Plants_Physical") end
    return p
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

local function scanAllPlants()
    local plantsPhysical = getPlantsPhysical()
    if not plantsPhysical then
        plantsPhysical = Workspace:FindFirstChild("Farm")
        if plantsPhysical then plantsPhysical = plantsPhysical:FindFirstChild("Farm") end
        if plantsPhysical then plantsPhysical = plantsPhysical:FindFirstChild("Important") end
        if plantsPhysical then plantsPhysical = plantsPhysical:FindFirstChild("Plants_Physical") end
        if not plantsPhysical then
            warn("❌ Plants_Physical tidak ditemukan.")
            return {}
        end
    end

    local plantList = {}
    local index = 0

    for _, plantFolder in ipairs(plantsPhysical:GetChildren()) do
        -- FIX: beberapa jenis pohon (mis. Sugar Apple) menyimpan buahnya di folder
        -- "Fruit_Spawn", bukan "Fruits". Jumlah slot buah tergantung jumlah child
        -- di folder ini (bisa 8 slot atau lebih), jadi SEMUA child harus diproses,
        -- bukan cuma satu representatif seperti fallback lama.
        local fruitsFolder = plantFolder:FindFirstChild("Fruits") or plantFolder:FindFirstChild("Fruit_Spawn")
        if fruitsFolder then
            for _, fruit in ipairs(fruitsFolder:GetChildren()) do
                if fruit:IsA("BasePart") or fruit:IsA("Model") or fruit:IsA("Folder") then
                    index = index + 1
                    local muts = collectMutations(fruit)
                    for _, desc in ipairs(fruit:GetDescendants()) do
                        if desc:IsA("BasePart") or desc:IsA("Model") then
                            for k, v in pairs(desc:GetAttributes()) do
                                if v == true and officialMutations[k] then
                                    muts[k] = true
                                end
                            end
                        end
                    end
                    local mutCount = 0
                    for _ in pairs(muts) do mutCount = mutCount + 1 end

                    local part = nil
                    if fruit:IsA("BasePart") then
                        part = fruit
                    elseif fruit:IsA("Model") and fruit.PrimaryPart then
                        part = fruit.PrimaryPart
                    else
                        for _, desc in ipairs(fruit:GetDescendants()) do
                            if desc:IsA("BasePart") then
                                part = desc
                                break
                            end
                        end
                    end
                    local position = part and part.Position or fruit:GetPivot().Position
                    local uuid = fruit:GetAttribute("OBJECT_UUID") or fruit:GetAttribute("UUID") or plantFolder.Name .. "_fruit_" .. index

                    table.insert(plantList, {
                        name = plantFolder.Name .. " #" .. index,
                        mutCount = mutCount,
                        position = position,
                        uuid = uuid,
                        instance = fruit,
                        plantName = plantFolder.Name,
                    })
                end
            end
        else
            local target = plantFolder
            if target:IsA("Folder") then
                for _, child in ipairs(target:GetChildren()) do
                    if child:IsA("BasePart") or child:IsA("Model") then
                        target = child
                        break
                    end
                end
            end

            if target:IsA("BasePart") or target:IsA("Model") then
                index = index + 1
                local muts = collectMutations(target)
                for _, desc in ipairs(target:GetDescendants()) do
                    if desc:IsA("BasePart") or desc:IsA("Model") then
                        for k, v in pairs(desc:GetAttributes()) do
                            if v == true and officialMutations[k] then
                                muts[k] = true
                            end
                        end
                    end
                end
                local mutCount = 0
                for _ in pairs(muts) do mutCount = mutCount + 1 end

                local part = nil
                if target:IsA("BasePart") then
                    part = target
                elseif target:IsA("Model") and target.PrimaryPart then
                    part = target.PrimaryPart
                else
                    for _, desc in ipairs(target:GetDescendants()) do
                        if desc:IsA("BasePart") then
                            part = desc
                            break
                        end
                    end
                end
                local position = part and part.Position or target:GetPivot().Position
                local uuid = target:GetAttribute("OBJECT_UUID") or target:GetAttribute("UUID") or plantFolder.Name .. "_" .. index

                table.insert(plantList, {
                    name = plantFolder.Name,
                    mutCount = mutCount,
                    position = position,
                    uuid = uuid,
                    instance = target,
                    plantName = plantFolder.Name,
                })
            end
        end
    end

    if #plantList == 0 then
        print("⚠️ scanAllPlants: tidak ada tanaman terdeteksi.")
    else
        print("🔍 ESP: Ditemukan " .. #plantList .. " target tanaman.")
    end
    return plantList
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
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 18
    label.Font = Enum.Font.SourceSansBold
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.TextStrokeTransparency = 0
    label.Parent = bill

    return {
        part = part,
        bill = bill,
        label = label,
        uuid = data.uuid
    }
end

local function updateESP()
    local plants = scanAllPlants()
    local current = {}
    for _, p in ipairs(plants) do
        current[p.uuid] = p
    end

    for uuid, obj in pairs(espObjects) do
        if not current[uuid] then
            obj.part:Destroy()
            obj.bill:Destroy()
            espObjects[uuid] = nil
        end
    end

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

function FarmESP.start()
    if espConnection then return end
    updateESP()
    espConnection = RunService.Heartbeat:Connect(function()
        if tick() % 2 < 0.05 then
            pcall(updateESP)
        end
    end)
    print("✅ FarmESP started.")
end

function FarmESP.stop()
    if espConnection then
        espConnection:Disconnect()
        espConnection = nil
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

print("✅ FarmESP embedded loaded.")

-- ============================================================
-- 3B. FORWARD DECLARATIONS (FIX)
-- Deklarasikan sebagai global lebih awal agar fungsi yang
-- dideklarasikan sebelum Section 8G (mis. shovelFruitsOnTree di 8C)
-- tetap bisa memanggilnya tanpa error "attempt to call a nil value".
-- ============================================================
scanFruitsOnTree = nil
findFruitOnTreeByExactMutation = nil
countFruitsOnTreeWithMutationAbove = nil

-- ============================================================
-- 4. FUNGSI BANTUAN UI
-- ============================================================
local function getPetList(isFavorite)
    local pets = DataPetModule.findPets({ isFavorite = isFavorite })
    local options = {}
    for _, pet in ipairs(pets) do
        local name = pet.name or "Unknown"
        local mutation = pet.mutation or "Normal"
        local level = pet.level or 0
        local weight = pet.weight or 0
        local display = string.format("%s %s %.0fkg lv%d", mutation, name, weight, level)
        table.insert(options, {
            Title = display,
            Value = pet.uuid
        })
    end
    return options
end

local function getTreeList()
    local plantsPhysical = getPlantsPhysical()
    if not plantsPhysical then return {} end
    local options = {}
    for _, folder in ipairs(plantsPhysical:GetChildren()) do
        table.insert(options, {
            Title = folder.Name,
            Value = folder.Name
        })
    end
    return options
end

local function getPetByUUID(uuid)
    if not uuid then return nil end
    local ok, inv = pcall(DataPetModule.getAllPets)
    if not ok or not inv then return nil end
    local pet = inv[uuid]
    if not pet then return nil end

    local petData = pet.PetData or {}
    local rawMut = petData.MutationType or "Normal"
    local mutation = DataPetModule.getAutoMutationName(rawMut)
    local level = petData.Level or petData.Lvl or 0
    local baseWeight = petData.Weight or petData.BaseWeight or 0
    local currentWeight = DataPetModule.calculateWeightAtLevel(baseWeight, level)

    return {
        uuid = uuid,
        pet = pet,
        petData = petData,
        name = pet.PetType or petData.PetType or petData.Name or "Unknown",
        mutation = mutation,
        level = level,
        baseWeight = baseWeight,
        weight = currentWeight,
        isFavorite = petData.IsFavorite or false,
        passive = petData.Passive or "",
    }
end

-- ============================================================
-- 5. BUAT WINDOW & CONFIG
-- ============================================================
local Window = WindUI:CreateWindow({
    Title = "Pria Solo HUB",
    Folder = "PriaSoloHUB",
    Size = UDim2.new(0, 420, 0, 750),
    Center = true,
    AutoShow = true,
    Draggable = true,
    OpenButton = {
        Title = "PSHB",
        Enabled = true,
        Draggable = true,
        OnlyMobile = false,
    },
})

local MyConfig = Window.ConfigManager:CreateConfig("PriaSoloConfig")

local currentAnubis = {}
local currentCornling = {}
local currentFrog = {}
local currentTargets = {}
local currentTree = ""
local currentTargetLevel = 500
local currentMutationCount = 1
local currentCollectThreshold = 10
local currentESPEnabled = false
local currentWebhookUrl = ""

-- ============================================================
-- 6. TAB AUTO LEVELING
-- ============================================================
local TabLeveling = Window:Tab({
    Title = "Auto Leveling",
    Icon = "solar:graph-up-bold",
})

local LevelingSection = TabLeveling:Section({ Title = "Auto Leveling Settings" })

local suppressToggleCallback = false
local suppressAutoBuyToggle = false

local autoToggle = LevelingSection:Toggle({
    Title = "Auto Leveling (ON = Mulai / OFF = Stop)",
    Value = false,
    Flag = "auto_leveling",
    Callback = function(state)
        if suppressToggleCallback then return end
        print("🟢 [Toggle] Auto Leveling ->", state and "ON" or "OFF")
        if state then
            startLeveling()
        else
            stopLeveling()
        end
    end
})

local espToggle = LevelingSection:Toggle({
    Title = "ESP Mutasi",
    Value = false,
    Flag = "esp_mutation",
    Callback = function(state)
        currentESPEnabled = state
        if state then
            if FarmESP and FarmESP.start then
                FarmESP.start()
            else
                warn("⚠️ FarmESP.start tidak tersedia")
            end
        else
            if FarmESP and FarmESP.stop then
                FarmESP.stop()
            else
                warn("⚠️ FarmESP.stop tidak tersedia")
            end
        end
    end
})

LevelingSection:Space()

local autoBuyToggle = LevelingSection:Toggle({
    Title = "Auto Buy Favorite Tool (10x / 5 menit)",
    Value = false,
    Flag = "auto_buy_fav_tool",
    Callback = function(state)
        if suppressAutoBuyToggle then return end
        print("🛒 Auto Buy Favorite Tool:", state and "ON" or "OFF")
        if state then
            startAutoBuyFavoriteTool()
        else
            stopAutoBuyFavoriteTool()
        end
    end
})

LevelingSection:Space()

local treeDropdown = LevelingSection:Dropdown({
    Title = "Pilih Pohon",
    Multi = false,
    Search = true,
    AllowNone = false,
    Values = getTreeList(),
    Value = "",
    Flag = "selected_tree",
    Callback = function(selected)
        local val = selected
        if type(selected) == "table" and selected.Value then
            val = selected.Value
        elseif type(selected) == "string" then
            val = selected
        end
        currentTree = val
        print("🌳 Pohon dipilih:", currentTree)
    end
})

LevelingSection:Space()

local frogDropdown = LevelingSection:Dropdown({
    Title = "Pilih Tim Frog / Echo Frog",
    Multi = true,
    Search = true,
    AllowNone = true,
    Values = getPetList(true),
    Value = {},
    Flag = "tim_frog",
    Callback = function(selected)
        local uuids = {}
        if type(selected) == "table" then
            for _, item in ipairs(selected) do
                if type(item) == "table" and item.Value then
                    table.insert(uuids, item.Value)
                elseif type(item) == "string" then
                    table.insert(uuids, item)
                end
            end
        end
        currentFrog = uuids
    end
})

LevelingSection:Button({
    Title = "Clear Tim Frog",
    Justify = "Center",
    Callback = function()
        frogDropdown:Select({})
    end
})

LevelingSection:Space()

local cornlingDropdown = LevelingSection:Dropdown({
    Title = "Pilih Tim Cornling",
    Multi = true,
    Search = true,
    AllowNone = true,
    Values = getPetList(true),
    Value = {},
    Flag = "tim_cornling",
    Callback = function(selected)
        local uuids = {}
        if type(selected) == "table" then
            for _, item in ipairs(selected) do
                if type(item) == "table" and item.Value then
                    table.insert(uuids, item.Value)
                elseif type(item) == "string" then
                    table.insert(uuids, item)
                end
            end
        end
        currentCornling = uuids
    end
})

LevelingSection:Button({
    Title = "Clear Tim Cornling",
    Justify = "Center",
    Callback = function()
        cornlingDropdown:Select({})
    end
})

LevelingSection:Space()

local anubisDropdown = LevelingSection:Dropdown({
    Title = "Pilih Tim Anubis",
    Multi = true,
    Search = true,
    AllowNone = true,
    Values = getPetList(true),
    Value = {},
    Flag = "tim_anubis",
    Callback = function(selected)
        local uuids = {}
        if type(selected) == "table" then
            for _, item in ipairs(selected) do
                if type(item) == "table" and item.Value then
                    table.insert(uuids, item.Value)
                elseif type(item) == "string" then
                    table.insert(uuids, item)
                end
            end
        end
        currentAnubis = uuids
    end
})

LevelingSection:Button({
    Title = "Clear Tim Anubis",
    Justify = "Center",
    Callback = function()
        anubisDropdown:Select({})
    end
})

LevelingSection:Space()

local targetLevelingDropdown = LevelingSection:Dropdown({
    Title = "Pilih Target Leveling",
    Multi = true,
    Search = true,
    AllowNone = true,
    Values = getPetList(false),
    Value = {},
    Flag = "target_leveling",
    Callback = function(selected)
        local uuids = {}
        if type(selected) == "table" then
            for _, item in ipairs(selected) do
                if type(item) == "table" and item.Value then
                    table.insert(uuids, item.Value)
                elseif type(item) == "string" then
                    table.insert(uuids, item)
                end
            end
        end
        currentTargets = uuids
    end
})

LevelingSection:Button({
    Title = "Clear Target Leveling",
    Justify = "Center",
    Callback = function()
        targetLevelingDropdown:Select({})
    end
})

LevelingSection:Space()

local targetLevelInput = LevelingSection:Input({
    Title = "Target Level",
    Value = "500",
    Placeholder = "1-500",
    Flag = "target_level",
    Callback = function(value)
        local num = tonumber(value) or 500
        if num < 1 then num = 1 end
        if num > 500 then num = 500 end
        currentTargetLevel = num
    end
})

LevelingSection:Space()

local mutationCountInput = LevelingSection:Input({
    Title = "Jumlah Mutasi (untuk difavoritkan)",
    Value = "110",
    Placeholder = "misal: 110",
    Flag = "mutation_count",
    Callback = function(value)
        local num = tonumber(value) or 1
        if num < 0 then num = 0 end
        currentMutationCount = num
    end
})

local collectThresholdInput = LevelingSection:Input({
    Title = "Shovel Buah Dengan Mutasi Dibawah",
    Value = "10",
    Placeholder = "misal: 10",
    Flag = "collect_threshold",
    Callback = function(value)
        local num = tonumber(value) or 10
        if num < 0 then num = 0 end
        currentCollectThreshold = num
    end
})

LevelingSection:Space()

local webhookInput = LevelingSection:Input({
    Title = "Webhook",
    Value = "",
    Placeholder = "https://discord.com/api/webhooks/...",
    Flag = "webhook_url",
    Callback = function(value)
        currentWebhookUrl = tostring(value or "")
    end
})

-- ============================================================
-- 7. STATUS LABEL
-- ============================================================
local statusLabel = TabLeveling:Paragraph({
    Title = "Status",
    Desc = "Status: Stopped",
})

-- ============================================================
-- 8. GAME EVENTS & HELPER FUNCTIONS
-- ============================================================
local GameEvents = ReplicatedStorage:FindFirstChild("GameEvents")
local PetsServiceEvent = GameEvents and GameEvents:FindFirstChild("PetsService")
local NotificationEvent = GameEvents and GameEvents:FindFirstChild("Notification")
local FavoriteToolRemote = GameEvents and GameEvents:FindFirstChild("FavoriteToolRemote")
local CropsFolder = GameEvents and GameEvents:FindFirstChild("Crops")
local CollectRemoteEvent = CropsFolder and CropsFolder:FindFirstChild("Collect")
local RemoveItemRemote = GameEvents and GameEvents:FindFirstChild("Remove_Item")
local BuyGearStock = GameEvents and GameEvents:FindFirstChild("BuyGearStock")

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local function findToolInBackpackByPrefix(namePrefix)
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not backpack then return nil end
    for _, item in ipairs(backpack:GetChildren()) do
        if item:IsA("Tool") and item.Name:sub(1, #namePrefix) == namePrefix then
            return item
        end
    end
    return nil
end

local function findToolInCharacterByPrefix(namePrefix)
    local character = LocalPlayer.Character
    if not character then return nil end
    for _, item in ipairs(character:GetChildren()) do
        if item:IsA("Tool") and item.Name:sub(1, #namePrefix) == namePrefix then
            return item
        end
    end
    return nil
end

local function getHumanoid()
    local character = LocalPlayer.Character
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function equipToolByPrefix(namePrefix)
    local alreadyEquipped = findToolInCharacterByPrefix(namePrefix)
    if alreadyEquipped then return alreadyEquipped end

    local tool = findToolInBackpackByPrefix(namePrefix)
    if not tool then
        warn("⚠️ Tool '" .. namePrefix .. "' tidak ditemukan di Backpack.")
        return nil
    end
    local humanoid = getHumanoid()
    if not humanoid then
        warn("⚠️ Humanoid tidak ditemukan di Character.")
        return nil
    end
    humanoid:EquipTool(tool)
    task.wait(0.2)
    return findToolInCharacterByPrefix(namePrefix) or tool
end

-- ============================================================
-- 8A. AUTO BUY FAVORITE TOOL
-- ============================================================
local autoBuyRunning = false
local autoBuyCoroutine = nil

function startAutoBuyFavoriteTool()
    if autoBuyRunning then return end
    if not BuyGearStock then
        warn("⚠️ BuyGearStock remote tidak ditemukan.")
        return
    end

    autoBuyRunning = true
    autoBuyCoroutine = coroutine.create(function()
        local totalBuy = 10
        local totalDuration = 300
        local interval = totalDuration / totalBuy

        print("🛒 Auto Buy Favorite Tool dimulai: 10x dalam 5 menit")
        for i = 1, totalBuy do
            if not autoBuyRunning then break end
            local ok, err = pcall(function()
                BuyGearStock:FireServer("Favorite Tool")
            end)
            if ok then
                print("🛒 Pembelian Favorite Tool ke-" .. i .. " berhasil")
            else
                warn("⚠️ Gagal membeli Favorite Tool ke-" .. i .. ": " .. tostring(err))
            end
            if i < totalBuy then
                task.wait(interval)
            end
        end
        print("✅ Auto Buy Favorite Tool selesai (10x)")
        autoBuyRunning = false
        autoBuyCoroutine = nil
        suppressAutoBuyToggle = true
        autoBuyToggle:Set(false)
        suppressAutoBuyToggle = false
    end)
    coroutine.resume(autoBuyCoroutine)
end

function stopAutoBuyFavoriteTool()
    autoBuyRunning = false
    if autoBuyCoroutine then
        autoBuyCoroutine = nil
    end
    print("⏹️ Auto Buy Favorite Tool dihentikan.")
end

-- ============================================================
-- 8B. LEPAS FAVORITE TOOL
-- ============================================================
local function equipNonFavoriteTool()
    local humanoid = getHumanoid()
    if not humanoid then return false end

    local character = LocalPlayer.Character
    if not character then return false end

    local currentTool = nil
    for _, item in ipairs(character:GetChildren()) do
        if item:IsA("Tool") then
            currentTool = item
            break
        end
    end

    if not currentTool then return true end
    if not string.find(currentTool.Name, "Favorite Tool") then return true end

    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not backpack then return false end

    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and not string.find(tool.Name, "Favorite Tool") then
            humanoid:EquipTool(tool)
            task.wait(0.3)
            debugStep("Langkah 5: lepas Favorite Tool, equip: " .. tool.Name)
            return true
        end
    end

    if currentTool then
        currentTool.Parent = backpack
        task.wait(0.3)
        debugStep("Langkah 5: Favorite Tool dilepas (dipindahkan ke Backpack)")
        return true
    end

    return false
end

-- ============================================================
-- 8C. SHOVEL BUAH DI POHON TERPILIH DENGAN MUTASI DI BAWAH THRESHOLD
--     (LANGKAH 2B / 3B)
--     - Buah dengan mutasi < threshold -> dishovel (termasuk buah tanpa mutasi/0)
--     - Buah dengan mutasi >= threshold (termasuk yang PERSIS = threshold) -> TIDAK dishovel
--     - Hanya menyentuh buah pada 'treeName' (pohon lain tidak disentuh),
--       karena scanFruitsOnTree(treeName) sudah memfilter per pohon
--     - FIX: dibuat beberapa kali pass (scan ulang -> shovel ulang) supaya
--       benar-benar tuntas untuk pohon dengan banyak buah (bisa sampai 40+
--       tergantung jumlah spawn point), karena replikasi server bisa telat
--       sehingga 1 pass saja kadang menyisakan buah yang belum ke-Destroy.
-- ============================================================
local SHOVEL_MAX_PASSES = 6

local function shovelFruitsOnTree(treeName, threshold)
    if not RemoveItemRemote then
        warn("⚠️ Remove_Item remote tidak ditemukan.")
        return
    end

    local shovel = equipToolByPrefix("Shovel [Destroy Plants]")
    if not shovel then
        warn("⚠️ Shovel [Destroy Plants] tidak ditemukan di Backpack.")
        return
    end
    debugStep("Langkah 2B: shovel di-equip")

    for pass = 1, SHOVEL_MAX_PASSES do
        local fruits = scanFruitsOnTree(treeName)
        local toShovel = {}
        for _, p in ipairs(fruits) do
            if p.mutCount < threshold then
                table.insert(toShovel, p.instance)
            end
        end

        if #toShovel == 0 then
            if pass == 1 then
                debugStep("Langkah 2B: tidak ada buah di " .. treeName .. " dengan mutasi < " .. threshold)
            else
                debugStep("Langkah 2B: sudah bersih, semua buah di " .. treeName .. " dengan mutasi < " .. threshold .. " berhasil dishovel (pass " .. pass .. ")")
            end
            break
        end

        debugStep("Langkah 2B: pass " .. pass .. "/" .. SHOVEL_MAX_PASSES .. " - menemukan " .. #toShovel .. " buah di " .. treeName .. " dengan mutasi < " .. threshold .. " (termasuk buah tanpa mutasi), mulai shovel...")
        for i, fruit in ipairs(toShovel) do
            local ok, err = pcall(function()
                RemoveItemRemote:FireServer(fruit)
            end)
            if ok then
                debugStep("Langkah 2B: shovel " .. i .. "/" .. #toShovel .. " berhasil")
            else
                warn("⚠️ Gagal shovel buah: " .. tostring(err))
            end
            task.wait(0.3)
        end
        debugStep("Langkah 2B: selesai shovel " .. #toShovel .. " buah pada pass " .. pass .. ", menyisakan buah dengan mutasi >= " .. threshold)

        -- beri waktu replikasi server sebelum verifikasi ulang pada pass berikutnya
        task.wait(0.7)
    end

    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack and shovel.Parent == LocalPlayer.Character then
        shovel.Parent = backpack
        debugStep("Langkah 2B: shovel dilepas")
    end
    task.wait(0.3)
end

-- ============================================================
-- 8D. FAV/UNFAV BUAH
-- ============================================================
local function setFruitFavorite(fruitInstance, state)
    if not fruitInstance then return false end
    if not FavoriteToolRemote then
        warn("⚠️ FavoriteToolRemote tidak ditemukan.")
        return false
    end

    local favTool = equipToolByPrefix("Favorite Tool")
    if not favTool then
        warn("⚠️ Favorite Tool gagal di-equip.")
        return false
    end

    local ok, err = pcall(function()
        FavoriteToolRemote:InvokeServer(favTool, fruitInstance, state)
    end)
    if not ok then
        warn("⚠️ Gagal " .. (state and "favorite" or "unfavorite") .. " buah: " .. tostring(err))
    end
    return ok
end

-- ============================================================
-- 8E. PET EQUIP / UNEQUIP
-- ============================================================
local PET_EQUIP_CFRAME = CFrame.new(-16.000007629395, 4, -116.50244903564, 1, 0, 0, 0, 1, 0, 0, 0, 1)

local function equipPetByUUID(uuid)
    if not uuid or not PetsServiceEvent then return end
    PetsServiceEvent:FireServer("EquipPet", uuid, PET_EQUIP_CFRAME)
end

local function unequipPetByUUID(uuid)
    if not uuid or not PetsServiceEvent then return end
    PetsServiceEvent:FireServer("UnequipPet", uuid)
end

local function equipPetListTogether(uuidList)
    for _, uuid in ipairs(uuidList) do
        equipPetByUUID(uuid)
    end
    task.wait(0.2)
end

local function unequipPetList(uuidList)
    for _, uuid in ipairs(uuidList) do
        unequipPetByUUID(uuid)
    end
    task.wait(0.2)
end

-- ============================================================
-- 8F. NOTIFICATION LISTENERS
-- ============================================================
local function waitForNotificationCount(matchFn, targetCount, timeoutSeconds)
    local count = 0
    local startTime = tick()

    if not NotificationEvent then
        warn("⚠️ Notification event tidak ditemukan, skip.")
        return 0
    end

    local connection
    connection = NotificationEvent.OnClientEvent:Connect(function(...)
        local args = { ... }
        for _, v in ipairs(args) do
            if type(v) == "string" and matchFn(v) then
                count = count + 1
                break
            end
        end
    end)

    while count < targetCount and (tick() - startTime) < timeoutSeconds and isLevelingRunning do
        task.wait(0.5)
    end

    connection:Disconnect()
    return count
end

local function waitForNotificationString(matchFn, timeoutSeconds)
    local startTime = tick()

    if not NotificationEvent then
        warn("⚠️ Notification event tidak ditemukan, skip.")
        return false
    end

    local found = false
    local connection
    connection = NotificationEvent.OnClientEvent:Connect(function(...)
        local args = { ... }
        for _, v in ipairs(args) do
            if type(v) == "string" and matchFn(v) then
                found = true
                break
            end
        end
    end)

    while not found and (tick() - startTime) < timeoutSeconds and isLevelingRunning do
        task.wait(0.5)
    end

    connection:Disconnect()
    return found
end

-- Menunggu SALAH SATU dari dua trigger: notifikasi growth (matchFn) ATAU
-- "Spider Web Wave" muncul sebanyak spiderWebTargetCount kali.
-- Mengembalikan (growthFound, spiderWebCount).
local function waitForGrowthOrSpiderWeb(matchFn, spiderWebTargetCount, timeoutSeconds)
    local growthFound = false
    local spiderWebCount = 0
    local startTime = tick()

    if not NotificationEvent then
        warn("⚠️ Notification event tidak ditemukan, skip.")
        return false, 0
    end

    local connection
    connection = NotificationEvent.OnClientEvent:Connect(function(...)
        local args = { ... }
        for _, v in ipairs(args) do
            if type(v) == "string" then
                if matchFn(v) then
                    growthFound = true
                end
                if v:find("Spider's ability: Web Weave", 1, true) then
                    spiderWebCount = spiderWebCount + 1
                end
            end
        end
    end)

    while isLevelingRunning and not growthFound and spiderWebCount < spiderWebTargetCount and (tick() - startTime) < timeoutSeconds do
        task.wait(0.5)
    end

    connection:Disconnect()
    return growthFound, spiderWebCount
end

local NOTIF_TARGET_COUNT = 6
local NOTIF_TIMEOUT_SECONDS = 60
local SPIDER_WEB_WAVE_TARGET_COUNT = 7
local SPIDER_WEB_WAVE_TIMEOUT_SECONDS = 120
local ANUBIS_TIMEOUT_SECONDS = 60 -- Langkah 6: timeout tunggu Anubis diatur 1 menit

-- ============================================================
-- 8G0. WEBHOOK - kirim data saat target level tercapai
-- Mencoba beberapa fungsi HTTP request yang umum disediakan
-- executor (syn.request / http_request / request), fallback ke
-- HttpService:PostAsync jika tidak ada satupun yang tersedia.
-- ============================================================
local HttpService = game:GetService("HttpService")

local function sendWebhookRaw(webhookUrl, jsonBody)
    if not webhookUrl or webhookUrl == "" then return false, "URL kosong" end

    local ok, err = pcall(function()
        if syn and syn.request then
            syn.request({
                Url = webhookUrl,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = jsonBody,
            })
        elseif http_request then
            http_request({
                Url = webhookUrl,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = jsonBody,
            })
        elseif request then
            request({
                Url = webhookUrl,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = jsonBody,
            })
        else
            HttpService:PostAsync(webhookUrl, jsonBody, Enum.HttpContentType.ApplicationJson)
        end
    end)

    return ok, err
end

local function formatDuration(durationSeconds)
    durationSeconds = math.floor(durationSeconds + 0.5)
    local hours = math.floor(durationSeconds / 3600)
    local minutes = math.floor((durationSeconds % 3600) / 60)
    local seconds = durationSeconds % 60
    if hours > 0 then
        return string.format("%dj %dm %ds", hours, minutes, seconds)
    else
        return string.format("%dm %ds", minutes, seconds)
    end
end

local function sendTargetReachedWebhook(webhookUrl, petData, targetUUID, targetLevel, durationSeconds)
    if not webhookUrl or webhookUrl == "" then
        return
    end

    local petName = (petData and petData.name) or "Unknown"
    local petMutation = (petData and petData.mutation) or "Normal"
    local petLevel = (petData and petData.level) or targetLevel

    local payload = {
        embeds = {
            {
                title = "🎯 Target Level Tercapai!",
                color = 3066993,
                fields = {
                    { name = "Pet", value = tostring(petMutation) .. " " .. tostring(petName), inline = true },
                    { name = "UUID", value = tostring(targetUUID), inline = true },
                    { name = "Level Tercapai", value = tostring(petLevel) .. " / " .. tostring(targetLevel), inline = true },
                    { name = "Lama Pengerjaan", value = formatDuration(durationSeconds), inline = false },
                },
            }
        }
    }

    local ok, jsonBody = pcall(function()
        return HttpService:JSONEncode(payload)
    end)
    if not ok then
        warn("⚠️ Gagal encode payload webhook: " .. tostring(jsonBody))
        return
    end

    local sent, err = sendWebhookRaw(webhookUrl, jsonBody)
    if sent then
        debugStep("Webhook terkirim: target level tercapai (" .. formatDuration(durationSeconds) .. ")")
    else
        warn("⚠️ Gagal mengirim webhook: " .. tostring(err))
    end
end

-- ============================================================
-- 8G. FUNGSI SCAN & COLLECT PER POHON
-- (FIX: dijadikan GLOBAL/tanpa 'local' supaya bisa dipanggil dari
--  shovelFruitsOnTree di Section 8C, yang dideklarasikan lebih awal)
-- ============================================================
function scanFruitsOnTree(treeName)
    local all = scanAllPlants()
    local result = {}
    for _, p in ipairs(all) do
        if p.plantName == treeName then
            table.insert(result, p)
        end
    end
    return result
end

function findFruitOnTreeByExactMutation(treeName, mutationCount)
    local fruits = scanFruitsOnTree(treeName)
    for _, p in ipairs(fruits) do
        if p.mutCount == mutationCount then
            return p
        end
    end
    return nil
end

function countFruitsOnTreeWithMutationAbove(treeName, threshold, exceptInstance)
    local count = 0
    local fruits = scanFruitsOnTree(treeName)
    for _, p in ipairs(fruits) do
        if p.instance ~= exceptInstance and p.mutCount > threshold then
            count = count + 1
        end
    end
    return count
end

-- ============================================================
-- 8H. SHOVEL BUAH MUTASI < threshold (LANGKAH 5 - SHOVEL BUKAN COLLECT)
--     FIX: multi-pass agar tuntas untuk pohon dengan banyak buah (40+)
-- ============================================================
local function shovelLowMutationFruitsOnTree(treeName, threshold)
    if not RemoveItemRemote then
        warn("⚠️ Remove_Item remote tidak ditemukan.")
        return
    end

    -- Lepas favorite tool jika sedang dipegang
    equipNonFavoriteTool()

    -- Equip shovel
    local shovel = equipToolByPrefix("Shovel [Destroy Plants]")
    if not shovel then
        warn("⚠️ Shovel [Destroy Plants] tidak ditemukan di Backpack.")
        return
    end
    debugStep("Langkah 5: shovel di-equip untuk menghapus buah mutasi < " .. threshold)

    for pass = 1, SHOVEL_MAX_PASSES do
        local fruits = scanFruitsOnTree(treeName)
        local toShovel = {}
        for _, p in ipairs(fruits) do
            if p.mutCount < threshold then
                table.insert(toShovel, p.instance)
            end
        end

        if #toShovel == 0 then
            if pass == 1 then
                debugStep("Langkah 5: tidak ada buah di " .. treeName .. " dengan mutasi < " .. threshold)
            else
                debugStep("Langkah 5: sudah bersih, semua buah di " .. treeName .. " dengan mutasi < " .. threshold .. " berhasil dishovel (pass " .. pass .. ")")
            end
            break
        end

        debugStep("Langkah 5: pass " .. pass .. "/" .. SHOVEL_MAX_PASSES .. " - menemukan " .. #toShovel .. " buah dengan mutasi < " .. threshold .. ", mulai shovel...")
        for i, fruit in ipairs(toShovel) do
            local ok, err = pcall(function()
                RemoveItemRemote:FireServer(fruit)
            end)
            if ok then
                debugStep("Langkah 5: shovel " .. i .. "/" .. #toShovel .. " berhasil")
            else
                warn("⚠️ Gagal shovel buah: " .. tostring(err))
            end
            task.wait(0.3)
        end
        debugStep("Langkah 5: selesai shovel " .. #toShovel .. " buah pada pass " .. pass)

        task.wait(0.7)
    end

    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack and shovel.Parent == LocalPlayer.Character then
        shovel.Parent = backpack
        debugStep("Langkah 5: shovel dilepas")
    end
    task.wait(0.3)
end

-- ============================================================
-- 8I. UNFAVORITE TARGET BUAH SEBELUMNYA (Langkah 1)
-- FIX: TIDAK LAGI mencari & unfavorite SEMBARANG buah favorit di garden,
-- karena itu bisa ikut meng-unfavorite buah cadangan mutasi milik user
-- yang sengaja difavoritkan secara manual. Sekarang HANYA meng-unfavorite
-- instance spesifik yang difavoritkan oleh script itu sendiri di Langkah 4
-- pada iterasi sebelumnya (jika ada).
-- ============================================================
local function unfavoritePreviousTargetFruit(previousInstance)
    if not previousInstance then
        debugStep("Langkah 1: tidak ada buah target sebelumnya, lewati (buah favorit lain/cadangan mutasi tidak disentuh)")
        return false
    end
    debugStep("Langkah 1: unfavorite buah target sebelumnya (buah favorit lain/cadangan mutasi tidak disentuh)")
    local success = setFruitFavorite(previousInstance, false)
    if success then
        debugStep("Langkah 1: berhasil unfavorite buah target sebelumnya")
    else
        debugStep("Langkah 1: GAGAL unfavorite buah target sebelumnya")
    end
    task.wait(0.3)
    return success
end

-- ============================================================
-- 9. LOGIKA START / STOP (TANPA goto)
-- ============================================================
isLevelingRunning = false

function debugStep(msg)
    print("🐾 [AutoLeveling] " .. msg)
end

function stopLeveling()
    isLevelingRunning = false
    suppressToggleCallback = true
    autoToggle:Set(false)
    suppressToggleCallback = false
    if statusLabel then
        statusLabel:SetDesc("Status: Stopped")
    end
    debugStep("⏹️ STOP")
end

function startLeveling()
    if isLevelingRunning then
        debugStep("sudah berjalan, abaikan.")
        return
    end

    debugStep("startLeveling() dipanggil...")

    local anubis = currentAnubis
    local cornling = currentCornling
    local frog = currentFrog
    local targets = currentTargets
    local targetLevel = currentTargetLevel
    local mutationCount = currentMutationCount
    local collectThreshold = currentCollectThreshold
    local tree = currentTree

    if #cornling == 0 then warn("⚠️ Pilih Tim Cornling!"); return end
    if #anubis == 0 then warn("⚠️ Pilih Tim Anubis!"); return end
    if #frog == 0 then warn("⚠️ Pilih Tim Frog/Echo Frog!"); return end
    if #targets == 0 then warn("⚠️ Pilih Target Leveling!"); return end
    if targetLevel < 1 then warn("⚠️ Target Level tidak valid!"); return end
    if mutationCount < 0 then warn("⚠️ Jumlah Mutasi tidak valid!"); return end
    if collectThreshold < 0 then warn("⚠️ Batas Collect tidak valid!"); return end
    if tree == "" then warn("⚠️ Pilih Pohon!"); return end

    isLevelingRunning = true
    if statusLabel then
        statusLabel:SetDesc("Status: Running...")
    end

    task.spawn(function()
        local ok, err = pcall(function()
            for targetIndex, targetUUID in ipairs(targets) do
                if not isLevelingRunning then break end

                debugStep("=== TARGET #" .. targetIndex .. "/" .. #targets .. " ===")

                local petData = getPetByUUID(targetUUID)
                local currentLevel = petData and petData.level or 0

                if currentLevel >= targetLevel then
                    debugStep("⚠️ Target sudah mencapai level " .. currentLevel .. ", lewati.")
                    unequipPetByUUID(targetUUID)
                    for _, uuid in ipairs(anubis) do
                        unequipPetByUUID(uuid)
                    end
                    debugStep("Selesai target #" .. targetIndex)
                else
                    debugStep(string.format("Level target: %d/%d", currentLevel, targetLevel))

                    local favoritedFruitInstance = nil
                    local targetStartTime = tick()

                    while isLevelingRunning and currentLevel < targetLevel do

                        -- ===== LANGKAH 1 =====
                        debugStep("Langkah 1: unfavorite buah target sebelumnya (jika ada)")
                        if statusLabel then statusLabel:SetDesc("Status: Bersihkan buah target sebelumnya...") end
                        unfavoritePreviousTargetFruit(favoritedFruitInstance)
                        favoritedFruitInstance = nil
                        if not isLevelingRunning then break end

                        -- ===== LANGKAH 2 =====
                        debugStep("Langkah 2A: equip Frog")
                        if statusLabel then statusLabel:SetDesc("Status: Equip Frog...") end
                        equipPetListTogether(frog)
                        if not isLevelingRunning then break end

                        debugStep("Langkah 2B: shovel buah di " .. tree .. " dengan mutasi < " .. collectThreshold)
                        if statusLabel then statusLabel:SetDesc("Status: Shovel buah mutasi rendah...") end
                        shovelFruitsOnTree(tree, collectThreshold)
                        if not isLevelingRunning then
                            unequipPetList(frog)
                            break
                        end

                        debugStep("Langkah 2C: tunggu notifikasi growth atau Spider Web Wave " .. SPIDER_WEB_WAVE_TARGET_COUNT .. "x")
                        if statusLabel then statusLabel:SetDesc("Status: Tunggu growth / Spider Web Wave...") end
                        local frogTrigger = string.format("Frog advanced the growth of your %s plant by 24 hours", tree)
                        local growthFound, spiderWebCount = waitForGrowthOrSpiderWeb(function(msg)
                            return msg:find(frogTrigger) ~= nil
                        end, SPIDER_WEB_WAVE_TARGET_COUNT, SPIDER_WEB_WAVE_TIMEOUT_SECONDS)
                        if growthFound then
                            debugStep("Langkah 2C: notifikasi growth diterima!")
                        elseif spiderWebCount >= SPIDER_WEB_WAVE_TARGET_COUNT then
                            debugStep("Langkah 2C: Spider Web Wave terpicu " .. spiderWebCount .. "x, lanjut unequip Frog")
                        else
                            debugStep("Langkah 2C: timeout, tidak ada notifikasi growth maupun Spider Web Wave " .. SPIDER_WEB_WAVE_TARGET_COUNT .. "x (Spider Web Wave: " .. spiderWebCount .. "x)")
                        end

                        unequipPetList(frog)
                        task.wait(0.5)
                        if not isLevelingRunning then break end

                        -- ===== LANGKAH 3 =====
                        debugStep("Langkah 3: equip Cornling, tunggu 6x Corn Synergy")
                        if statusLabel then statusLabel:SetDesc("Status: Equip Cornling & tunggu synergy...") end
                        equipPetListTogether(cornling)

                        local synergyProcs = waitForNotificationCount(function(msg)
                            return msg:find("Corn Synergy") ~= nil
                        end, NOTIF_TARGET_COUNT, NOTIF_TIMEOUT_SECONDS)
                        debugStep(string.format("Langkah 3: Corn Synergy proc %d/%d", synergyProcs, NOTIF_TARGET_COUNT))

                        unequipPetList(cornling)
                        task.wait(0.5)
                        if not isLevelingRunning then break end

                        -- ===== LANGKAH 3B =====
                        debugStep("Langkah 3B: shovel buah di " .. tree .. " dengan mutasi < " .. collectThreshold .. " (setelah unequip Cornling)")
                        if statusLabel then statusLabel:SetDesc("Status: Shovel buah mutasi rendah (pasca Cornling)...") end
                        shovelFruitsOnTree(tree, collectThreshold)
                        if not isLevelingRunning then break end

                        -- ===== LANGKAH 4 =====
                        debugStep(string.format("Langkah 4: cari buah di %s dengan tepat %d mutasi, favoritkan", tree, mutationCount))
                        if statusLabel then statusLabel:SetDesc("Status: Favoritkan buah target mutasi...") end
                        local matched = findFruitOnTreeByExactMutation(tree, mutationCount)
                        if matched then
                            debugStep("Langkah 4: buah ditemukan, difavoritkan")
                            setFruitFavorite(matched.instance, true)
                            favoritedFruitInstance = matched.instance
                        else
                            debugStep("Langkah 4: tidak ada buah dengan tepat " .. mutationCount .. " mutasi di " .. tree)
                        end
                        task.wait(0.5)
                        if not isLevelingRunning then break end

                        -- ===== LANGKAH 5 =====
                        debugStep("Langkah 5: shovel buah di " .. tree .. " dengan mutasi < " .. collectThreshold)
                        if statusLabel then statusLabel:SetDesc("Status: Shovel buah rendah...") end
                        shovelLowMutationFruitsOnTree(tree, collectThreshold)
                        task.wait(0.5)
                        if not isLevelingRunning then break end

                        -- ===== LANGKAH 6 =====
                        debugStep("Langkah 6: equip Anubis + Target, tunggu buah di " .. tree .. " <= 10 mutasi (kecuali favorit), timeout " .. ANUBIS_TIMEOUT_SECONDS .. " detik")
                        if statusLabel then statusLabel:SetDesc("Status: Equip Anubis + Target...") end
                        local anubisAndTarget = {}
                        for _, uuid in ipairs(anubis) do table.insert(anubisAndTarget, uuid) end
                        table.insert(anubisAndTarget, targetUUID)
                        equipPetListTogether(anubisAndTarget)

                        local anubisStartTime = tick()
                        while isLevelingRunning do
                            local remaining = countFruitsOnTreeWithMutationAbove(tree, 10, favoritedFruitInstance)
                            if remaining <= 0 then
                                debugStep("Langkah 6: semua buah di " .. tree .. " sudah <= 10 mutasi (kecuali favorit)")
                                break
                            end
                            if (tick() - anubisStartTime) >= ANUBIS_TIMEOUT_SECONDS then
                                debugStep("Langkah 6: timeout " .. ANUBIS_TIMEOUT_SECONDS .. " detik tercapai, masih ada " .. remaining .. " buah > 10 mutasi, lanjut ke Langkah 7")
                                break
                            end
                            task.wait(1)
                        end

                        unequipPetList(anubisAndTarget)
                        task.wait(0.5)

                        -- ===== LANGKAH 7 =====
                        debugStep("Langkah 7: cek level target")
                        local petDataNow = getPetByUUID(targetUUID)
                        currentLevel = petDataNow and (petDataNow.level or 0) or currentLevel
                        debugStep(string.format("Langkah 7: level sekarang %d/%d", currentLevel, targetLevel))
                        if statusLabel then
                            statusLabel:SetDesc(string.format("Status: Leveling... %d/%d", currentLevel, targetLevel))
                        end

                        if currentLevel >= targetLevel then
                            debugStep("✅ Target level tercapai! Unequip target dan lanjut.")
                            local elapsed = tick() - targetStartTime
                            sendTargetReachedWebhook(currentWebhookUrl, petDataNow, targetUUID, targetLevel, elapsed)
                            unequipPetByUUID(targetUUID)
                            for _, uuid in ipairs(anubis) do
                                unequipPetByUUID(uuid)
                            end
                            break
                        end
                    end -- while

                    unequipPetByUUID(targetUUID)
                    for _, uuid in ipairs(anubis) do
                        unequipPetByUUID(uuid)
                    end
                    debugStep("Selesai target #" .. targetIndex)
                end -- if currentLevel >= targetLevel
            end -- for targets
        end)

        if not ok then
            warn("❌ [AutoLeveling] Error: " .. tostring(err))
        end

        debugStep("Proses selesai, stop.")
        stopLeveling()
    end)
end

-- ============================================================
-- 10. TOMBOL REFRESH
-- ============================================================
LevelingSection:Button({
    Title = "🔄 Refresh Data",
    Justify = "Center",
    Callback = function()
        anubisDropdown:Refresh(getPetList(true))
        cornlingDropdown:Refresh(getPetList(true))
        frogDropdown:Refresh(getPetList(true))
        targetLevelingDropdown:Refresh(getPetList(false))
        treeDropdown:Refresh(getTreeList())
        print("✅ Data di-refresh!")
    end
})

-- ============================================================
-- 11. SAVE & LOAD CONFIG
-- ============================================================
local function applyLoadedConfig()
    local data, err = MyConfig:Load()
    if data == false then
        warn("⚠️ Gagal memuat konfigurasi: " .. tostring(err))
    end
end

local ConfigSection = TabLeveling:Section({ Title = "Config" })
ConfigSection:Button({
    Title = "Simpan Konfigurasi",
    Justify = "Center",
    Callback = function()
        MyConfig:Save()
        print("✅ Konfigurasi disimpan!")
    end
})
ConfigSection:Button({
    Title = "Muat Konfigurasi",
    Justify = "Center",
    Callback = function()
        applyLoadedConfig()
        print("✅ Konfigurasi dimuat!")
        anubisDropdown:Select(MyConfig:Get("tim_anubis") or {})
        cornlingDropdown:Select(MyConfig:Get("tim_cornling") or {})
        frogDropdown:Select(MyConfig:Get("tim_frog") or {})
        targetLevelingDropdown:Select(MyConfig:Get("target_leveling") or {})
        treeDropdown:Select(MyConfig:Get("selected_tree") or "")
        targetLevelInput:SetValue(tostring(MyConfig:Get("target_level") or 500))
        mutationCountInput:SetValue(tostring(MyConfig:Get("mutation_count") or 1))
        collectThresholdInput:SetValue(tostring(MyConfig:Get("collect_threshold") or 10))
        webhookInput:SetValue(tostring(MyConfig:Get("webhook_url") or ""))
        autoToggle:Set(MyConfig:Get("auto_leveling") or false)
        espToggle:Set(MyConfig:Get("esp_mutation") or false)
        autoBuyToggle:Set(MyConfig:Get("auto_buy_fav_tool") or false)
    end
})

-- ============================================================
-- 12. AUTO-LOAD CONFIG
-- ============================================================
applyLoadedConfig()

print("✅ Pria Solo HUB v24 (FIXED) siap digunakan!")

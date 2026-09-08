-- FarmESP.lua - ESP untuk menampilkan jumlah mutasi SETIAP BUAH
local FarmESP = {}

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ============================================================
-- MUTASI RESMI
-- ============================================================
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
    -- fallback hardcode
    local fallback = {
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
    for _, name in ipairs(fallback) do officialMutations[name] = true end
end
loadMutations()

-- ============================================================
-- ESP MANAGEMENT
-- ============================================================
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

local function collectMutations(obj)
    local muts = {}
    for k, v in pairs(obj:GetAttributes()) do
        if v == true and officialMutations[k] then
            muts[k] = true
        end
    end
    return muts
end

-- Scan SETIAP buah di setiap pohon
local function scanAllPlants()
    local plantsPhysical = getPlantsPhysical()
    if not plantsPhysical then return {} end

    local plantList = {}
    local index = 0

    for _, plantFolder in ipairs(plantsPhysical:GetChildren()) do
        local fruitsFolder = plantFolder:FindFirstChild("Fruits")
        if fruitsFolder then
            -- MULTI FRUIT: loop setiap buah
            for _, fruit in ipairs(fruitsFolder:GetChildren()) do
                if fruit:IsA("BasePart") or fruit:IsA("Model") or fruit:IsA("Folder") then
                    index = index + 1
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

                    local part = fruit:IsA("BasePart") and fruit or fruit:FindFirstChildWhichIsA("BasePart")
                    if not part then
                        for _, desc in ipairs(fruit:GetDescendants()) do
                            if desc:IsA("BasePart") then part = desc; break end
                        end
                    end
                    local position = part and part.Position or fruit:GetPivot().Position
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
            -- SINGLE FRUIT: tanaman itu sendiri
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
            local uuid = target:GetAttribute("OBJECT_UUID") or target:GetAttribute("UUID") or plantFolder.Name

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

    return { part = part, bill = bill, label = label, uuid = data.uuid }
}

local function updateESP()
    local plants = scanAllPlants()
    local current = {}
    for _, p in ipairs(plants) do current[p.uuid] = p end

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

-- ============================================================
-- FarmLib.lua
-- Modul untuk aktivitas bertani: collect, favorite, plant
-- ============================================================
local FarmLib = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ============================================================
-- BANTUAN INTERNAL
-- ============================================================
local function findTool(pattern)
    local player = Players.LocalPlayer
    if not player then return nil end

    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        for _, t in ipairs(backpack:GetChildren()) do
            if t:IsA("Tool") and string.find(t.Name, pattern) then return t, "Backpack" end
        end
    end

    local character = player.Character
    if character then
        for _, t in ipairs(character:GetChildren()) do
            if t:IsA("Tool") and string.find(t.Name, pattern) then return t, "Character" end
        end
    end

    local folder = Workspace:FindFirstChild(player.Name)
    if folder then
        for _, t in ipairs(folder:GetChildren()) do
            if t:IsA("Tool") and string.find(t.Name, pattern) then return t, "Workspace" end
        end
    end

    return nil, nil
end

local function equipTool(tool)
    local player = Players.LocalPlayer
    if not player then return false end
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChildWhichIsA("Humanoid")
    if not hum then return false end

    if tool.Parent ~= player.Backpack then
        tool.Parent = player.Backpack
        task.wait(0.1)
    end
    hum:EquipTool(tool)
    task.wait(0.5)
    return true
end

local function getPlantsPhysical()
    local p = Workspace:FindFirstChild("Farm")
    if p then p = p:FindFirstChild("Farm") end
    if p then p = p:FindFirstChild("Important") end
    if p then p = p:FindFirstChild("Plants_Physical") end
    return p
end

local function countMutations(obj)
    if not obj then return 0 end
    local count = 0
    for attr, val in pairs(obj:GetAttributes()) do
        if attr ~= "Favored" and attr ~= "Favorite" and attr ~= "OBJECT_UUID" and attr ~= "UUID" then
            if val == true then count = count + 1 end
        end
    end
    return count
end

local function getTarget(folder)
    local fruits = folder:FindFirstChild("Fruits")
    if fruits then
        local target = fruits:FindFirstChild(folder.Name)
        if not target then
            local children = fruits:GetChildren()
            if #children > 0 then target = children[1] end
        end
        return target
    end
    return folder
end

-- ============================================================
-- FUNGSI 1: COLLECT
-- ============================================================
-- config = { minMutations, maxMutations, mutationName, autoCollect, delay }
function FarmLib.collectFruits(config)
    config = config or {}
    local minM = config.minMutations or 1
    local maxM = config.maxMutations or 1
    local mutName = config.mutationName
    local auto = (config.autoCollect == nil) and true or config.autoCollect
    local delay = config.delay or 0.3

    local plants = getPlantsPhysical()
    if not plants then warn("❌ Plants_Physical not found"); return {} end

    local remote = ReplicatedStorage:FindFirstChild("GameEvents") and ReplicatedStorage.GameEvents:FindFirstChild("Collect")
    if not remote then warn("❌ Collect remote not found"); return {} end

    local targets = {}
    for _, folder in ipairs(plants:GetChildren()) do
        local target = getTarget(folder)
        if target then
            local mutCount = countMutations(target)
            for _, d in ipairs(target:GetDescendants()) do
                mutCount = mutCount + countMutations(d)
            end

            local match = (mutCount >= minM and mutCount <= maxM)
            if match and mutName then
                local found = false
                for attr, val in pairs(target:GetAttributes()) do
                    if val == true and string.lower(attr) == string.lower(mutName) then found = true break end
                end
                if not found then match = false end
            end

            if match then
                table.insert(targets, { obj = target, name = folder.Name, mutCount = mutCount })
            end
        end
    end

    print("🔍 Found " .. #targets .. " matching plants.")
    if not auto then
        for _, t in ipairs(targets) do print("  " .. t.name .. " (mut: " .. t.mutCount .. ")") end
        return targets
    end

    print("🔄 Collecting...")
    for _, t in ipairs(targets) do
        print("  " .. t.name)
        remote:FireServer({ t.obj })
        task.wait(delay)
    end
    print("✅ Done.")
    return targets
end

-- ============================================================
-- FUNGSI 2: FAV / UNFAV
-- ============================================================
function FarmLib.favoriteFruits(config)
    config = config or {}
    local threshold = config.threshold or 90
    local auto = (config.autoExecute == nil) and true or config.autoExecute
    local delay = config.delay or 0.2

    local tool, loc = findTool("Favorite Tool")
    if not tool then warn("❌ Favorite Tool not found"); return {} end
    print("✅ Favorite Tool at:", loc)
    if not equipTool(tool) then warn("❌ Equip failed"); return {} end

    local remote = ReplicatedStorage:FindFirstChild("GameEvents") and ReplicatedStorage.GameEvents:FindFirstChild("FavoriteToolRemote")
    if not remote then warn("❌ FavoriteToolRemote not found"); return {} end

    local plants = getPlantsPhysical()
    if not plants then warn("❌ Plants_Physical not found"); return {} end

    local results = {}
    for _, folder in ipairs(plants:GetChildren()) do
        local target = getTarget(folder)
        if target then
            local mutCount = countMutations(target)
            for _, d in ipairs(target:GetDescendants()) do
                mutCount = mutCount + countMutations(d)
            end
            table.insert(results, {
                obj = target,
                name = folder.Name,
                mutCount = mutCount,
                shouldFav = mutCount >= threshold
            })
        end
    end

    if not auto then
        print("🔍 Scan results:")
        for _, r in ipairs(results) do
            print(string.format("  %s: %d → %s", r.name, r.mutCount, r.shouldFav and "FAV" or "UNFAV"))
        end
        return results
    end

    print("🔄 Executing FAV/UNFAV...")
    local fav, unfav = 0, 0
    for _, r in ipairs(results) do
        print(string.format("  %s: %d → %s", r.name, r.mutCount, r.shouldFav and "FAV" or "UNFAV"))
        local ok, err = pcall(function()
            remote:InvokeServer(tool, r.obj, r.shouldFav)
        end)
        if ok then
            if r.shouldFav then fav = fav + 1 else unfav = unfav + 1 end
        else
            warn("    ❌ " .. r.name .. ": " .. tostring(err))
        end
        task.wait(delay)
    end
    print("✅ Done. FAV:", fav, "UNFAV:", unfav)
    return results
end

-- ============================================================
-- FUNGSI 3: TANAM
-- ============================================================
function FarmLib.plantSeeds(config)
    config = config or {}
    local seedName = config.seedName or "Carrot"
    local count = config.count or 6
    local basePos = config.basePos or Vector3.new(0, 0, 0)
    local spacing = config.spacing or 2.5
    local axis = config.axis or "X"

    local tool, loc = findTool(seedName .. " Seed")
    if not tool then warn("❌ " .. seedName .. " Seed not found"); return false end
    print("✅ Seed at:", loc)
    if not equipTool(tool) then warn("❌ Equip failed"); return false end

    local remote = ReplicatedStorage:FindFirstChild("GameEvents") and ReplicatedStorage.GameEvents:FindFirstChild("Plant_RE")
    if not remote then warn("❌ Plant_RE not found"); return false end

    local positions = {}
    for i = 0, count - 1 do
        if axis == "X" then
            table.insert(positions, Vector3.new(basePos.X + i * spacing, basePos.Y, basePos.Z))
        else
            table.insert(positions, Vector3.new(basePos.X, basePos.Y, basePos.Z + i * spacing))
        end
    end

    print("📍 Planting positions:")
    for i, p in ipairs(positions) do
        print(string.format("  %d. (%.2f, %.2f, %.2f)", i, p.X, p.Y, p.Z))
    end

    print("🌱 Planting " .. count .. " " .. seedName .. "...")
    local success = 0
    for i, p in ipairs(positions) do
        local ok, err = pcall(function()
            remote:FireServer(p, seedName)
        end)
        if ok then
            success = success + 1
            print(string.format("  ✅ %d success", i))
        else
            warn(string.format("  ❌ %d failed: %s", i, err))
        end
        task.wait(0.3)
    end
    print("✅ Done. Success: " .. success .. "/" .. count)
    return true
end

return FarmLib

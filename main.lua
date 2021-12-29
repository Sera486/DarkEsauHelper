local mod = RegisterMod("Dark Esau Helper", 1)
local json = require("json")

local function getDefaultConfig()
    return {enableDashHelper = true, enableAnimaSolaHelper = true}
end
local config = getDefaultConfig()

-- approximate)
local ESAU_REGULAR_DASH_DISTANCE = 370
local ESAU_REGULAR_DASH_FRAME_COUNT = 40
local ESAU_ANIMA_DASH_DISTANCE = 1600
local ESAU_ANIMA_DASH_FRAME_COUNT = 70
local ESAU_ANIMA_FRAME_WARN = 65
local ESAU_ANIMA_FRAME_DANGER = 110
local ESAU_ANIMA_FRAME_CRITICAL = 120

local isTargetSpriteInitialized = false
local targetSprite = nil

local lineColorNormal = Color(0.95, 0.35, 0.2) -- RGB(198, 232, 86)
local lineColorCritical = Color(1, 0.1, 0.1)

local DASH_ATTACKING_FRAME = "dashAttackingFrame"
local ANIMA_ATTACKING_FRAME = "animaAttackingFrame"
local TARGET_POSITION = "targetPosition"
local ANIMA_SOLA_STATE = "animaSolaState"
local ANIMA_SOLA_APPLICATION = "animaSolaApplication"

local AnimaSolaState = {NONE = 0, APPLIED = 1}
local LineState = {NORMAL = 0, CRITICAL = 1, FLICKER = 2}

function mod:postNpcRender(npc)
    if npc.Variant ~= 0 or not npc.TargetPosition then return end -- if easu's pit
    local npcData = npc:GetData()
    local currentFrameCount = Game():GetFrameCount();

    if npcData[DASH_ATTACKING_FRAME] == nil or npc.State == NpcState.STATE_SUICIDE then
        npcData[DASH_ATTACKING_FRAME] = 0
        npcData[ANIMA_ATTACKING_FRAME] = 0
    end

    -- first frame where TargetPosition is initialized with valid value
    if npc.State == NpcState.STATE_ATTACK and npc.StateFrame == 15 then
        mod:configureEsauData(npc, ESAU_REGULAR_DASH_DISTANCE, DASH_ATTACKING_FRAME)
    elseif npc.State == NpcState.STATE_ATTACK2 and npc.StateFrame == 0 then
        mod:configureEsauData(npc, ESAU_ANIMA_DASH_DISTANCE, ANIMA_ATTACKING_FRAME)
    end

    local isRegularDashInProgress = npcData[DASH_ATTACKING_FRAME] ~= 0 and
            npcData[DASH_ATTACKING_FRAME] + ESAU_REGULAR_DASH_FRAME_COUNT >= currentFrameCount
    local isAnimaSolaDashInProgress = npcData[ANIMA_ATTACKING_FRAME] ~= 0 and
            npcData[ANIMA_ATTACKING_FRAME] + ESAU_ANIMA_DASH_FRAME_COUNT >= currentFrameCount

    if config.enableDashHelper and isRegularDashInProgress then
        mod:drawLine(npc.Position, npcData[TARGET_POSITION], LineState.NORMAL, 0)
    end

    if config.enableAnimaSolaHelper then
        local newState = mod:updateAnimaSolaState(npc)
        if (newState == AnimaSolaState.APPLIED) then
            local target = npc:GetPlayerTarget()
            if target == nil then target = Isaac.GetPlayer(0) end

            local finalPosition = mod:computeEsauEndPosition(npc.Position, target.Position)

            mod:drawLine(npc.Position, finalPosition, LineState.FLICKER, currentFrameCount - npcData[ANIMA_SOLA_APPLICATION])
        elseif (isAnimaSolaDashInProgress) then
            mod:drawLine(npc.Position, npcData[TARGET_POSITION], LineState.CRITICAL, 0)
        end
    end

end

function mod:postNewRoom()
    local esauTable = Isaac.FindByType(EntityType.ENTITY_DARK_ESAU)

    for _, npc in pairs(esauTable) do
        local npcData = npc:GetData()
        npcData[DASH_ATTACKING_FRAME] = 0
        npcData[ANIMA_ATTACKING_FRAME] = 0
    end
end

function mod:postNpcInit(npc)
    if npc.Variant ~= 0 then return end

    local npcData = npc:GetData()
    npcData[ANIMA_SOLA_STATE] = AnimaSolaState.NONE
end

function mod:postGameStarted()
    if mod:HasData() then
        local data = json.decode(mod:LoadData())
        for k, v in pairs(data) do
            if config[k] ~= nil then config[k] = v end
        end
    end
end

function mod:preGameExit() mod:SaveData(json.encode(config)) end

function mod:updateAnimaSolaState(esau)
    local previousState = esau:GetData()[ANIMA_SOLA_STATE]
    local newState = previousState

    if previousState == AnimaSolaState.NONE and esau.State == NpcState.STATE_SUICIDE then
        esau:GetData()[ANIMA_SOLA_APPLICATION] = Game():GetFrameCount()
        newState = AnimaSolaState.APPLIED
    elseif previousState == AnimaSolaState.APPLIED and esau.State ~= NpcState.STATE_SUICIDE then
        newState = AnimaSolaState.NONE
    end

    esau:GetData()[ANIMA_SOLA_STATE] = newState
    return newState
end

function mod:computeEsauEndPosition(esauStart, jacobPos)
    -- Compute the vector between both
    local diff = jacobPos - esauStart -- This the vector from esauStart to jacobPos
    local norm = diff:Normalized()
    return esauStart + norm * ESAU_ANIMA_DASH_DISTANCE
end

function mod:configureEsauData(esau, dashDistance, dataName)
    local dashVector = Vector(esau.TargetPosition.X, esau.TargetPosition.Y)
    esau:GetData()[TARGET_POSITION] = esau.Position + dashVector * dashDistance
    esau:GetData()[dataName] = Game():GetFrameCount()
end

function mod:drawLine(from, to, lineState, frame)
    -- using edited fetus_target file, failed to make line visible otherwise
    if not isTargetSpriteInitialized then
        targetSprite = Sprite()
        targetSprite:Load("gfx/esau_target.anm2", true)
        targetSprite.Color = lineColorNormal
        isTargetSpriteInitialized = true
    end

    if not targetSprite:IsLoaded() then return end

    if(lineState == LineState.NORMAL) then
        targetSprite.Color = lineColorNormal
    elseif lineState == LineState.CRITICAL then
        targetSprite.Color = lineColorCritical
    elseif lineState == LineState.FLICKER then
        targetSprite.Color = mod:flickerColor(targetSprite.Color, frame)
    end

    local diffVector = to - from;
    local angle = diffVector:GetAngleDegrees();
    local sectionCount = diffVector:Length() / 16;

    targetSprite.Rotation = angle;
    targetSprite:SetFrame("Line", 0)
    for i = 1, sectionCount do
        targetSprite:Render(Isaac.WorldToScreen(from))
        from = from + Vector.One * 16 * Vector.FromAngle(angle)
    end

    targetSprite.Rotation = 0
    targetSprite:SetFrame("Idle", 0)
    targetSprite:Render(Isaac.WorldToScreen(to))
end

function mod:flickerColor(currentColor, frame)
    local newColor = currentColor
    if frame >= ESAU_ANIMA_FRAME_WARN and frame < ESAU_ANIMA_FRAME_DANGER then
        if frame % 4 == 0 then
            newColor = lineColorCritical
            if frame % 8 == 0 then
                newColor = lineColorNormal
            end
        end
    elseif frame >= ESAU_ANIMA_FRAME_DANGER and frame < ESAU_ANIMA_FRAME_CRITICAL then
        if frame % 3 == 0 then
            newColor = lineColorCritical
            if frame % 6 == 0 then
                newColor = lineColorNormal
            end
        end
    elseif frame >= ESAU_ANIMA_FRAME_CRITICAL then
        if frame % 2 == 0 then
            newColor = lineColorCritical
            if frame % 4 == 0 then
                newColor = lineColorNormal
            end
        end
    else
        newColor = lineColorNormal
    end
    return newColor
end

function mod:getNextColor(color)
    if color.R == lineColorNormal.R and color.G == lineColorNormal.G and color.B == lineColorNormal.B then
        return lineColorCritical
    else
        return lineColorNormal
    end
end

mod:AddCallback(ModCallbacks.MC_POST_NPC_RENDER, mod.postNpcRender, EntityType.ENTITY_DARK_ESAU);
mod:AddCallback(ModCallbacks.MC_POST_NPC_INIT, mod.postNpcInit, EntityType.ENTITY_DARK_ESAU);
mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.postNewRoom);
mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.postGameStarted)
mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, mod.preGameExit)

-- Mod Config Menu

local readebleBool = {[true] = "Enabled", [false] = "Disabled"}

if ModConfigMenu then
    local category = "Dark Esau Helper"
    ModConfigMenu.RemoveCategory(category);
    ModConfigMenu.UpdateCategory(category, {
        Name = category,
        Info = "Utility mod that makes Dark Esau more predictable"
    })

    ModConfigMenu.AddSetting(category, {

        Type = ModConfigMenu.OptionType.BOOLEAN,

        CurrentSetting = function() return config.enableDashHelper end,

        Display = function()
            return "Dash Helper: " .. readebleBool[config.enableDashHelper]
        end,

        OnChange = function(value) config.enableDashHelper = value; end,

        Info = {"Enables target when Esau performs regualar dash at player"}
    })

    ModConfigMenu.AddSetting(category, {

        Type = ModConfigMenu.OptionType.BOOLEAN,

        CurrentSetting = function() return config.enableAnimaSolaHelper end,

        Display = function()
            return "Anima Sola Helper: " .. readebleBool[config.enableAnimaSolaHelper]
        end,

        OnChange = function(value) config.enableAnimaSolaHelper = value; end,

        Info = {"Enables drawing of line when Esau is chained by Anima Sola"}
    })
end

--    CREDITS
--    Sera486
--        Mod Creator
--    Sylmir
--        Implementation of feature with line following the player while Esau chained using Anima Sola
--        Code refactoring

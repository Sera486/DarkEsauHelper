local mod = RegisterMod("Dark Esau Helper", 1)

--approximate)
local ESAU_REGULAR_DASH_DISTANCE = 410
local ESAU_REGULAR_DASH_FRAME_COUNT = 40
local ESAU_ANIMA_DASH_DISTANCE = 1600
local ESAU_ANIMA_DASH_FRAME_COUNT = 70

local isSpriteInitialized = false
local targetSprite = nil

function mod:postNpcRender(npc, renderOffset)
    local npcData = npc:GetData()
    local currentFrameCount = Game():GetFrameCount();
    
    if npcData["dashAttackingFrame"] == nil or npc.State == NpcState.STATE_SUICIDE then --when chained
        npcData["dashAttackingFrame"] = 0
        npcData["animaAttackingFrame"] = 0
    end
    
    --first frame where TargetPosition is initialized with valid value
    if npc.State == NpcState.STATE_ATTACK and npc.StateFrame == 15 then 
        --strange hack?, othervise target position is not recognised as vector
        local dashVector = Vector.FromAngle(npc.TargetPosition:GetAngleDegrees());
        
        npcData["targetPosition"] = npc.Position + ESAU_REGULAR_DASH_DISTANCE * dashVector;
        npcData["dashAttackingFrame"] = currentFrameCount;
    end

    if npc.State == NpcState.STATE_ATTACK2 and npc.StateFrame == 0 then 
        local dashVector = Vector.FromAngle(npc.TargetPosition:GetAngleDegrees());
        
        npcData["targetPosition"] = npc.Position + ESAU_ANIMA_DASH_DISTANCE * dashVector;
        npcData["animaAttackingFrame"] = currentFrameCount;
    end

    if npcData["dashAttackingFrame"] + ESAU_REGULAR_DASH_FRAME_COUNT >= currentFrameCount 
      or npcData["animaAttackingFrame"] + ESAU_ANIMA_DASH_FRAME_COUNT >= currentFrameCount   then
        mod:drawLine(npc.Position, npcData["targetPosition"])
    end
end

function mod:postNewRoom()
    local esauTable = Isaac.FindByType(EntityType.ENTITY_DARK_ESAU)
    
    for key, npc in pairs(esauTable)  do
        local npcData = npc:GetData()
        npcData["dashAttackingFrame"] = 0
        npcData["animaAttackingFrame"] = 0
    end
end

function mod:drawLine(from, to)
    --using edited fetus_target file, failed to make line visible otherwise
    if not isSpriteInitialized then 
        targetSprite = Sprite()
        targetSprite:Load("gfx/esau_target.anm2", true)
        targetSprite.Color = Color(0.95, 0.35,0.2)
        isSpriteInitialized = true
    end

    if targetSprite:IsLoaded() then 
        local diffVector = to - from;
        local angle = diffVector:GetAngleDegrees();
        local sectionCount = diffVector:Length()/16;
        
        targetSprite.Rotation = angle;
        targetSprite:SetFrame("Line", 0)
        for i=1, sectionCount do 
            targetSprite:Render(Isaac.WorldToScreen(from))
            from= from + Vector.One* 16 * Vector.FromAngle(angle)
        end 

        targetSprite.Rotation = 0
        targetSprite:SetFrame("Idle", 0)
        targetSprite:Render(Isaac.WorldToScreen(to))
    end
end

mod:AddCallback(ModCallbacks.MC_POST_NPC_RENDER, mod.postNpcRender, EntityType.ENTITY_DARK_ESAU);
mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.postNewRoom);
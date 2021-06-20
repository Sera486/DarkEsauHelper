local mod = RegisterMod("Dark Esau Helper", 1)
local json = require("json")

function getDefaultConfig()
    return {
        enableHealthBar = false,
    }
end
local config = getDefaultConfig()

--approximate)
local ESAU_REGULAR_DASH_DISTANCE = 410
local ESAU_REGULAR_DASH_FRAME_COUNT = 40
local ESAU_ANIMA_DASH_DISTANCE = 1600
local ESAU_ANIMA_DASH_FRAME_COUNT = 70
local ESAU_ANIMA_FRAME_WARN = 65                                                
local ESAU_ANIMA_FRAME_DANGER = 110                                             
local ESAU_ANIMA_FRAME_CRITICAL = 120   

local HEALTH_COLOR_FULL = Color(0.1,0.8,0.1)
local HEALTH_COLOR_CRITICAL = Color(1, 0.1, 0.1)
local HEALTH_BAR_LENGTH = 28

local isTargetSpriteInitialized = false
local targetSprite = nil
local isHealthSpriteInitialized = false
local healthSprite = nil

local DASH_ATTACKING_FRAME = "dashAttackingFrame"                               
local ANIMA_ATTACKING_FRAME = "animaAttackingFrame"                             
local TARGET_POSITION = "targetPosition"                                        
local ANIMA_SOLA_STATE = "animaSolaState"                                       
local ANIMA_SOLA_APPLICATION = "animaSolaApplication" 

local AnimaSolaState = {                                                        
   STATE_NONE = 0, -- No Anima Sola
   STATE_APPLIED = 1, -- Anima Sola was applied  
} 

local function computeEsauEndPosition(esauStart, jacobPos)                      
    -- Compute the vector between both                                          
    local diff = jacobPos - esauStart -- This the vector from esauStart to jacobPos
    local norm = diff:Normalized()                           
    return esauStart + norm * 2000
end

local function configureEsauData(esau, dashDistance, dataName)
    local dashVector = Vector.FromAngle(esau.TargetPosition:GetAngleDegrees())
    esau:GetData()[TARGET_POSITION] = esau.Position + dashDistance * dashVector
    esau:GetData()[dataName] = Game():GetFrameCount()
end

local function updateAnimaSolaState(esau)                                       
    local previousState = esau:GetData()[ANIMA_SOLA_STATE]                      
    local newState = nil                                                        
                                                                                
    if previousState == nil then                                                
        esau:GetData()[ANIMA_SOLA_STATE] = AnimaSolaState.STATE_NONE            
        previousState = AnimaSolaState.STATE_NONE                               
    end                                                                         
                                                                                
    if previousState == AnimaSolaState.STATE_NONE then                          
        if esau.State == NpcState.STATE_SUICIDE then                            
            esau:GetData()[ANIMA_SOLA_APPLICATION] = Game():GetFrameCount()     
            newState = AnimaSolaState.STATE_APPLIED                             
        else                                                                    
            newState = previousState                                                
    end                                                                         
    elseif previousState == AnimaSolaState.STATE_APPLIED then                   
        if esau.State == NpcState.STATE_SUICIDE then                            
            newState = previousState                                            
        else                                                                    
            newState = AnimaSolaState.STATE_NONE                             
        end                                                                
    end                                                                         
                                                                                
    esau:GetData()[ANIMA_SOLA_STATE] = newState                                 
    return previousState, newState                                              
end 

function mod:postNpcRender(npc, renderOffset)
    if npc.Variant ~= 0 then return end--if easu's pit
    local npcData = npc:GetData()
    local currentFrameCount = Game():GetFrameCount();
    
    if config.enableHealthBar then 
        mod:drawHealthBar(npc)
    end
    
    if npcData[DASH_ATTACKING_FRAME] == nil or npc.State == NpcState.STATE_SUICIDE then
        npcData[DASH_ATTACKING_FRAME] = 0
        npcData[ANIMA_ATTACKING_FRAME] = 0
    end
    
    --first frame where TargetPosition is initialized with valid value          
    if npc.State == NpcState.STATE_ATTACK and npc.StateFrame == 15 then         
        configureEsauData(npc, ESAU_REGULAR_DASH_DISTANCE, DASH_ATTACKING_FRAME)
    elseif npc.State == NpcState.STATE_ATTACK2 and npc.StateFrame == 0 then     
        configureEsauData(npc, ESAU_ANIMA_DASH_DISTANCE, ANIMA_ATTACKING_FRAME) 
    end      

    local previousState, newState = updateAnimaSolaState(npc)   
    local breakFree = npcData[ANIMA_ATTACKING_FRAME] + ESAU_ANIMA_DASH_FRAME_COUNT >= currentFrameCount

    if npcData[DASH_ATTACKING_FRAME] + ESAU_REGULAR_DASH_FRAME_COUNT >= currentFrameCount
    or breakFree                                                              
    or newState == AnimaSolaState.STATE_APPLIED then                          
      if newState == AnimaSolaState.STATE_APPLIED and not breakFree then      
          local target = npc:GetPlayerTarget()                                
          if target == nil then                                               
              target = Isaac.GetPlayer(0)                                     
          end                                                                 
                                                                              
          local finalPosition = computeEsauEndPosition(npc.Position, target.Position)
          mod:drawLine(npc.Position, finalPosition, true, currentFrameCount - npcData[ANIMA_SOLA_APPLICATION])
      else                                                                    
          mod:drawLine(npc.Position, npcData[TARGET_POSITION], false, 0, breakFree)
      end                                                                     
  end                      
end

function mod:postNewRoom()
    local esauTable = Isaac.FindByType(EntityType.ENTITY_DARK_ESAU)
    
    for key, npc in pairs(esauTable)  do
        local npcData = npc:GetData()
        npcData[DASH_ATTACKING_FRAME] = 0
        npcData[ANIMA_ATTACKING_FRAME] = 0
    end
end

function mod:postGameStarted()	
    if mod:HasData() then
        local data = json.decode(mod:LoadData())
        for k,v in pairs(data) do
            if config[k] ~= nil then
                config[k] = v
            end
        end
	end
end

function mod:preGameExit()
	mod:SaveData(json.encode(config))
end

local animaColorNormal = Color(0.95, 0.35, 0.2)-- RGB(198, 232, 86)
local animaColorWarn = Color(1, 0.8, 0.2)
local animaColorDanger = Color(0.85, 0.1, 0)
local animaColorCritical = Color(1, 0.1, 0.1)
local lastColor = animaColorNormal


function mod:drawLine(from, to, flicker, frame, breakFree)                      
    --using edited fetus_target file, failed to make line visible otherwise     
    if not isTargetSpriteInitialized then                                             
        targetSprite = Sprite()                                                 
        targetSprite:Load("gfx/esau_target.anm2", true)                         
        targetSprite.Color = animaColorNormal                                   
        isTargetSpriteInitialized = true                                              
    end                                                                         
                                                                                
    if targetSprite:IsLoaded() then                                             
        if flicker then                                                         
            flickerSprite(targetSprite, frame)                                  
            -- colorSprite(targetSprite, frame)                                 
        else                                                                    
            if breakFree then                                                   
                targetSprite.Color = lastColor                                  
            else                                                                
                targetSprite.Color = animaColorNormal                           
            end                                                                 
        end                                                                     
                                                                                
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

local function flickerSprite(sprite, frame)                                     
    if frame >= ESAU_ANIMA_FRAME_WARN and frame < ESAU_ANIMA_FRAME_DANGER then  
        if frame % 4 == 0 then                                                  
            if frame % 8 == 0 then                                              
                sprite.Color = animaColorNormal                                 
            else                                                                
                sprite.Color = animaColorCritical                                   
            end                                                                 
        end                                                                     
    elseif frame >= ESAU_ANIMA_FRAME_DANGER and frame < ESAU_ANIMA_FRAME_CRITICAL then
        if frame % 3 == 0 then                                                  
            if frame % 6 == 0 then                                              
                sprite.Color = animaColorNormal                                   
            else                                                                
                sprite.Color = animaColorCritical                                 
            end                                                                 
        end                                                                     
    elseif frame >= ESAU_ANIMA_FRAME_CRITICAL then                              
        if frame % 2 == 0 then                                                  
            if frame % 4 == 2 then                                              
                sprite.Color = animaColorNormal                                 
            else                                                                
                sprite.Color = animaColorCritical                               
            end                                                                 
        end                                                                     
    else                                                                        
        sprite.Color = animaColorNormal                                         
    end                                                                         
                                                                                
    lastColor = sprite.Color                                                    
end

function mod:drawHealthBar(npc)
    if not isHealthSpriteInitialized then                                             
        healthSprite = Sprite()                                                 
        healthSprite:Load("gfx/esau_healthbar.anm2", true)                                            
        healthSprite:SetFrame("Idle", 0)
        isHealthSpriteInitialized = true
    end     

    if healthSprite:IsLoaded() then                                             
        healthSprite:RenderLayer(0, Isaac.WorldToScreen(npc.Position+Vector(0, 16)))  
        local currentHealthPercentage = npc.HitPoints/npc.MaxHitPoints
        local currentHealthClamp = Vector(HEALTH_BAR_LENGTH-currentHealthPercentage*HEALTH_BAR_LENGTH -1, 0) 
        healthSprite.Color = Color.Lerp(HEALTH_COLOR_CRITICAL, HEALTH_COLOR_FULL, currentHealthPercentage)
        healthSprite:RenderLayer(1, Isaac.WorldToScreen(npc.Position+Vector(0, 16)), Vector.Zero, currentHealthClamp)
    end          
end

mod:AddCallback(ModCallbacks.MC_POST_NPC_RENDER, mod.postNpcRender, EntityType.ENTITY_DARK_ESAU);
mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.postNewRoom);
mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.postGameStarted)
mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, mod.preGameExit)

--Mod Config Menu

local readebleBool = {
    [true] = "Enabled",
    [false] = "Disabled"
}

if ModConfigMenu then
    local category = "Dark Esau Helper"
    ModConfigMenu.RemoveCategory(category);
    ModConfigMenu.UpdateCategory(category, {
        Name = category,
        Info = "Utility mod that makes Dark Esau more predictable",
    })

    ModConfigMenu.AddSetting(category, {

        Type = ModConfigMenu.OptionType.BOOLEAN,

        CurrentSetting = function() return config.enableHealthBar end,
    
        Display = function() return "Health Bar: " .. readebleBool[config.enableHealthBar] end,
    
        OnChange = function(value)
            config.enableHealthBar = value;
        end,
    
        Info = {"Enables health bar for Dark Esau"}
      })
end


--    CREDITS
--    Sera486
--        Mod Creator  
--    Sylmir 
--        Implementation of feature with line following the player while Esau chained using Anima Sola
--        Code refactoring
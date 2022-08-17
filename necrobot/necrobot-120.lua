--[[
    NecroBot 1.0 - Automate your necro for raid.

    You _can_ swap out the spells in dot table, but for raids, i would recommend this set for max dps.

    The main loop is: try to debuff the target, cycle through your dots, if your wounds has proc'd, apply whatever burns you have up.

    The burn phase is still being tweaked, and since each raid boss has a different burn strategy, i often just leave this out,

    and run the burns in a separate macro, so i can time when best to burn.

    IsDotReady(...) vs not IsTargetDottedWith(...) are fairly equivalent, except:

    The latter will simply check if mob has a dot on it.

    The former will take into account when a spell is wearing off and time to recast, to project if a new dot is needed.
    This will minimize gaps when dot is not on the mob. 

    If you are in a super laggy zone, and the lua script is not performant, you may need to use:
        not IsTargetDottedWith(...) 
    instead of 
        IsDotReady(...) 

    in the CastDot function, until server lag is gone.
--]]


--- @type mq
local mq = require('mq')
--- @type ImGui
require 'ImGui'

local DEBUG = false -- Just log, don't actually use burns, pass debug arg to enable

local PAUSED = true -- controls the main combat loop

local BURN_NOW = false -- toggled by /burnnow binding to burn immediately
local BURN_ALWAYS = false -- burn as burns become available
local BURN_PCT = 0 -- delay burn until mob below Pct HP, 0 ignores %.
local BURN_NAMED = false -- enable automatic burn on named mobs
local BURN_PROC = false -- enable automatic burn when wounds procs, pass noburn arg to disable

local DEBUFF = true -- enable use of debuffs
local ALLIANCE = true -- enable use of alliance spell

local SPELL_SETS = {'standard','short','undead','plant'}
local SPELL_SET = 'standard'

local CHASE = true
local CHASE_TARGET = ''
local CHASE_DISTANCE = 15

local ASSIST_AT = 99

-- Parse input arguments
local args = {...}
for _,arg in ipairs(args) do
    if arg == 'debug' then
        DEBUG = true
    elseif arg == 'noburn' then
        BURN = false
    end
end

local function GetSpellIDAndRank(spell_name)
    local spell_rank = mq.TLO.Spell(spell_name).RankName()
    return {['id']=mq.TLO.Spell(spell_rank).ID(), ['name']=spell_rank}
end

-- All spells ID + Rank name
local spells = {
    ['wounds']=GetSpellIDAndRank('Infected Wounds'),
    ['fireshadow']=GetSpellIDAndRank('Scalding Shadow'),
    ['combodis']=GetSpellIDAndRank('Danvid\'s Grip of Decay'),
    ['pyreshort']=GetSpellIDAndRank('Pyre of Va Xakra'),
    ['pyrelong']=GetSpellIDAndRank('Pyre of the Neglected'),
    ['venom']=GetSpellIDAndRank('Hemorrhagic Venom'),
    ['magic']=GetSpellIDAndRank('Extinction'),
    ['haze']=GetSpellIDAndRank('Zelnithak\'s Pallid Haze'),
    ['grasp']=GetSpellIDAndRank('The Protector\'s Grasp'),
    ['leech']=GetSpellIDAndRank('Twilight Leech'),
    ['ignite']=GetSpellIDAndRank('Ignite Cognition'),
    ['scourge']=GetSpellIDAndRank('Scourge of Destiny'),
    ['corruption']=GetSpellIDAndRank('Decomposition'),
    ['alliance']=GetSpellIDAndRank('Malevolent Coalition'),
    ['synergy']=GetSpellIDAndRank('Proclamation for Blood'),
    ['composite']=GetSpellIDAndRank('Composite Paroxysm'),
    ['decay']=GetSpellIDAndRank('Fleshrot\'s Decay'),
    ['grip']=GetSpellIDAndRank('Grip of Quietus'),
    ['proliferation']=GetSpellIDAndRank('Infected Proliferation'),
    ['scentterris']=GetSpellIDAndRank('Scent of Terris'),
    ['scentmortality']=GetSpellIDAndRank('Scent of The Grave'),
    ['swarm']=GetSpellIDAndRank('Call Skeleton Mass'),
    ['venin']=GetSpellIDAndRank('Embalming Venin'),
}

-- entries in the dots table are pairs of {spell id, spell name} in priority order
local standard = {}
table.insert(standard, spells['wounds'])
table.insert(standard, spells['composite'])
table.insert(standard, spells['pyreshort'])
table.insert(standard, spells['venom'])
table.insert(standard, spells['magic'])
table.insert(standard, spells['decay'])
table.insert(standard, spells['haze'])
table.insert(standard, spells['grasp'])
table.insert(standard, spells['fireshadow'])
table.insert(standard, spells['leech'])
table.insert(standard, spells['grip'])
table.insert(standard, spells['pyrelong'])
table.insert(standard, spells['ignite'])
table.insert(standard, spells['scourge'])
table.insert(standard, spells['corruption'])

local short = {}
table.insert(short, spells['swarm'])
table.insert(short, spells['composite'])
table.insert(short, spells['pyreshort'])
table.insert(short, spells['venom'])
table.insert(short, spells['magic'])
table.insert(short, spells['decay'])
table.insert(short, spells['haze'])
table.insert(short, spells['grasp'])
table.insert(short, spells['fireshadow'])
table.insert(short, spells['leech'])
table.insert(short, spells['grip'])
table.insert(short, spells['pyrelong'])
table.insert(short, spells['ignite'])

local dots = {
    ['standard']=standard,
    ['short']=short,
}

-- Determine swap gem based on wherever wounds, broiling shadow or pyre of the wretched is currently mem'd
local swap_gem = mq.TLO.Me.Gem(spells['wounds']['name'])() or mq.TLO.Me.Gem(spells['fireshadow']['name'])() or mq.TLO.Me.Gem(spells['pyrelong']['name'])()
local swap_gemDis = mq.TLO.Me.Gem(spells['decay']['name'])() or mq.TLO.Me.Gem(spells['grip']['name'])()

-- entries in the items table are MQ item datatypes
local items = {}
table.insert(items, mq.TLO.FindItem('Blightbringer\'s Tunic of the Grave')) -- buff
table.insert(items, mq.TLO.InvSlot('Chest').Item) -- buff, Consuming Magic
table.insert(items, mq.TLO.FindItem('Rage of Rolfron')) -- song

--table.insert(items, mq.TLO.FindItem('Bifold Focus of the Evil Eye'))
--table.insert(items, mq.TLO.FindItem('Necromantic Fingerbone'))
--table.insert(items, mq.TLO.FindItem('Amulet of the Drowned Mariner'))

local function GetAAIDAndName(aa_name)
    return {['id']=mq.TLO.Me.AltAbility(aa_name).ID(), ['name']=aa_name}
end

-- entries in the AAs table are pairs of {aa name, aa id}
local AAs = {}
table.insert(AAs, GetAAIDAndName('Silent Casting')) -- song
table.insert(AAs, GetAAIDAndName('Focus of Arcanum')) -- buff
table.insert(AAs, GetAAIDAndName('Mercurial Torment')) -- buff
table.insert(AAs, GetAAIDAndName('Heretic\'s Twincast')) -- buff
table.insert(AAs, GetAAIDAndName('Spire of Necromancy')) -- buff
table.insert(AAs, GetAAIDAndName('Hand of Death')) -- song
table.insert(AAs, GetAAIDAndName('Funeral Pyre')) -- song
table.insert(AAs, GetAAIDAndName('Gathering Dusk')) -- song, Duskfall Empowerment
table.insert(AAs, GetAAIDAndName('Companion\'s Fury'))
table.insert(AAs, GetAAIDAndName('Companion\'s Fortification'))
table.insert(AAs, GetAAIDAndName('Rise of Bones'))
table.insert(AAs, GetAAIDAndName('Wake the Dead'))
table.insert(AAs, GetAAIDAndName('Swarm of Decay'))

--table.insert(AAs, GetAAIDAndName('Life Burn'))
--table.insert(AAs, GetAAIDAndName('Dying Grasp'))
--table.insert(AAs, GetAAIDAndName('Glyph of Destruction (115+)'))
--table.insert(AAs, GetAAIDAndName('Intensity of the Resolute'))

-- Mana Recovery AAs
local deathbloom = GetAAIDAndName('Death Bloom')
local bloodmagic = GetAAIDAndName('Blood Magic')
-- Mana Recovery items
local item_feather = mq.TLO.FindItem('Unified Phoenix Feather')

--[[
    track data about our targets, for one-time or long-term affects.
    for example: we do not need to continually poll when to debuff a mob if the debuff will last 17+ minutes
    if the mob aint dead by then, you should re-roll a wizard.
]]--
local targets = {}

local neccount = 1

local function GetNecroCount()
    if mq.TLO.Raid.Members() > 0 then
        for member=1,72 do
            if mq.TLO.Raid.Member(member)() ~= mq.TLO.Me.CleanName() and mq.TLO.Raid.Member(member).Class.ShortName() == 'NEC' then
                neccount = neccount + 1
            end
        end
    elseif mq.TLO.Group.Members() then
        for member=1,5 do
            if mq.TLO.Group.Member(member).Class.ShortName() == 'NEC' then
                neccount = neccount + 1
            end
        end
    end
end

local function CanCastWeave()
    return not mq.TLO.Me.Casting()
end

local function IsTargetDottedWith(spell_id, spell_name)
    if not mq.TLO.Target.MyBuff(spell_name)() then return false end

    -- special case for septic proliferation since rankname just returns "septic proliferation"
    if spells['proliferation']['name']:find(spell_name) then return true end
    return spell_id == mq.TLO.Target.MyBuff(spell_name).ID()
end

local function IsDotReady(spellId, spellName)
    local buffDuration = 0
    local remainingCastTime = 0
    if not mq.TLO.Me.SpellReady(spellName)() then
        return false
    end

    buffDuration = mq.TLO.Target.MyBuffDuration(spellName)()
    if not IsTargetDottedWith(spellId, spellName) then
        -- target does not have the dot, we are ready
        return true
    else
        if not buffDuration then
            return true
        end
        -- Do not return wounds as ready while it still has any duration left
        if spellId == spells['wounds']['id'] then return false end
        remainingCastTime = mq.TLO.Spell(spellName).MyCastTime()
        return buffDuration < remainingCastTime + 3000
    end

    return false
end

local function IsFighting() 
    if mq.TLO.Target.CleanName() == 'Combat Dummy Beza' then return true end -- Dev hook for target dummy
    return (mq.TLO.Target.ID() ~= nil and (mq.TLO.Me.CombatState() ~= "ACTIVE" and mq.TLO.Me.CombatState() ~= "RESTING") and mq.TLO.Me.Standing() and not mq.TLO.Me.Feigning() and mq.TLO.Target.Type() == "NPC" and mq.TLO.Target.Type() ~= "Corpse")
end

local function CheckDistance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
end

local function AmIDead()

end

local function CheckChase()
    if not CHASE then return end
    if AmIDead() then return end
    if IsFighting() then return end
    local chase_spawn = mq.TLO.Spawn('pc ='..CHASE_TARGET)
    if chase_spawn() and CheckDistance(mq.TLO.Me.X(), mq.TLO.Me.Y(), chase_spawn.X(), chase_spawn.Y()) > CHASE_DISTANCE then
        if not mq.TLO.Nav.Active() then
            mq.cmdf('/nav locyxz %d %d %d dist=%d log=off', chase_spawn.Y(), chase_spawn.X(), chase_spawn.Z(), CHASE_DISTANCE)
        end
    end
end

local function CastDot(spell_name)
    print('\a-t[\ax\ayNecroBot\ax\a-t]\ax Casting \ar'..spell_name..'\ax')
    mq.cmdf('/cast "%s"', spell_name)
    mq.delay(10)
    if not mq.TLO.Me.Casting() then mq.cmdf('/cast %s', spell_name) end
    mq.delay(10)
    if not mq.TLO.Me.Casting() then mq.cmdf('/cast %s', spell_name) end
    mq.delay(10)
    while mq.TLO.Me.Casting() do
        mq.delay(10)
    end
end

-- Casts alliance if we are fighting, alliance is enabled, the spell is ready, alliance isn't already on the mob, there is > 1 necro in group or raid, and we have at least a few dots on the mob.
local function TryAlliance()
    if IsFighting() and ALLIANCE then
        if mq.TLO.Me.SpellReady(spells['alliance']['name'])() and neccount > 1 and not mq.TLO.Target.Buff(spells['alliance']['name'])() and mq.TLO.Spell(spells['alliance']['name']).StacksTarget() then
            -- pick the first 3 dots in the rotation as they will hopefully always be up given their priority
            if mq.TLO.Target.MyBuff(spells['pyreshort']['name'])() and mq.TLO.Target.MyBuff(spells['venom']['name'])() and mq.TLO.Target.MyBuff(spells['magic']['name'])() then
                CastDot(spells['alliance']['name'])
                return true
            end
        end
    end
    return false
end

local function CastSynergy()
    if IsFighting() then
        if not mq.TLO.Me.Song('Defiler\'s Synergy')() and mq.TLO.Me.SpellReady(spells['synergy']['name'])() then
            -- don't bother with proc'ing synergy until we've got most dots applied
            if mq.TLO.Target.MyBuff(spells['decay']['name'])() and mq.TLO.Target.MyBuff(spells['grip']['name'])() and mq.TLO.Target.MyBuff(spells['fireshadow']['name'])() then
                CastDot(spells['synergy']['name'])
                return true
            end
        end
    end
    return false
end

local function FindNextDotToCast()
    if TryAlliance() then return nil, nil end
    if CastSynergy() then return nil, nil end
    -- Just cast composite as part of the normal dot rotation, no special handling
    --if IsDotReady(spells['composite']['id'], spells['composite']['name']) then
    --    return spells['composite']['id'], spells['composite']['name']
    --end
    if SPELL_SET == 'short' and mq.TLO.Me.SpellReady(spells['swarm']['name'])() then
        return spells['swarm']['id'], spells['swarm']['name']
    end
    for _,dot in ipairs(dots[SPELL_SET]) do -- iterates over the dots array. ipairs(dots) returns 2 values, an index and its value in the array. we don't care about the index, we just want the dot
        local spell_id = dot['id']
        local spell_name = dot['name']
        -- ToL has no combo disease dot spell, so the 2 disease dots are just in the normal rotation now.
        -- if spell_id == spells['combodis']['id'] then
        --     if (not IsTargetDottedWith(spells['decay']['id'], spells['decay']['name']) or not IsTargetDottedWith(spells['grip']['id'], spells['grip']['name'])) and mq.TLO.Me.SpellReady(spells['combodis']['name'])() then
        --         return spell_id, spell_name
        --     end
        -- else
        if IsDotReady(spell_id, spell_name) then
            return spell_id, spell_name -- if IsDotReady returned true then return this dot as the dot we should cast
        end
    end
    return nil, nil -- we found no missing dot that was ready to cast, so return nothing
end

local function CycleDots()
    if IsFighting() then
        local spell_id, spell_name = FindNextDotToCast() -- find the first available dot to cast that is missing from the target
        if spell_id then -- if a dot was found
            CastDot(spell_name) -- then cast the dot
            return true
        end
    end
    return false
end

local function TryDebuffTarget()
    if IsFighting() and DEBUFF then
        local targetID = mq.TLO.Target.ID()
        if targetID > 0 and (not targets[targetID] or not targets[targetID][2]) then
            local isScentAAReady = mq.TLO.Me.AltAbilityReady('Scent of Thule')()

            local isDebuffedAlready = IsTargetDottedWith(spells['scentterris']['id'], spells['scentterris']['name'])
            if isDebuffedAlready then
                isDebuffedAlready = IsTargetDottedWith(spells['scentmortality']['id'], spells['scentmortality']['name'])
            end
            if not mq.TLO.Spell(spells['scentterris']['name']).StacksTarget() then
                isDebuffedAlready = true
            end
            if not mq.TLO.Spell(spells['scentmortality']['name']).StacksTarget() then
                isDebuffedAlready = true
            end

            if isScentAAReady and not isDebuffedAlready then
                print('\a-t[\ax\ayNecroBot\ax\a-t]\ax UseAA: \ax\arScent of Thule\ax')
                if not DEBUG then
                    mq.cmd('/alt activate 751')
                    mq.delay(10)
                end
            end

            if isDebuffedAlready then
                table.insert(targets, mq.TLO.Target.ID(), {"debuffed", true})
            end
            mq.delay(300+mq.TLO.Me.AltAbility(751).Spell.CastTime()) -- wait for cast time + some buffer so we don't skip over stuff
        end
    end
end

local function UseItem(item)
    if item.Timer() == '0' then
        print(string.format('\a-t[\ax\ayNecroBot\ax\a-t]\ax UseItem: \ax\ar%s\ax', item))
        if not DEBUG and CanCastWeave() then mq.cmdf('/useitem %s', item) end
        mq.delay(300+item.CastTime()) -- wait for cast time + some buffer so we don't skip over stuff
        -- alternatively maybe while loop until we see the buff or song is applied
    end
end

local function UseAA(aa, number)
    if not mq.TLO.Me.Song(aa)() and not mq.TLO.Me.Buff(aa)() and mq.TLO.Me.AltAbilityReady(aa)() and CanCastWeave() then
        print(string.format('\a-t[\ax\ayNecroBot\ax\a-t]\ax UseAA: \ax\ar%s\ax', aa))
        if not DEBUG then mq.cmdf('/alt activate %d', number) end
        mq.delay(300+mq.TLO.Me.AltAbility(aa).Spell.CastTime()) -- wait for cast time + some buffer so we don't skip over stuff
        -- alternatively maybe while loop until we see the buff or song is applied, but not all apply a buff or song, like pet stuff
    end
end

local function BurnConditionMet()
    if DEBUG or BURN_NOW or BURN_ALWAYS then
        return true
    elseif (BURN_NAMED and mq.TLO.Target.Named()) or (BURN_PROC and IsTargetDottedWith(spells['proliferation']['id'], spells['proliferation']['name'])) then
        if BURN_PCT == 0 or (BURN_PCT > 0 and mq.TLO.Target.PctHPs() < BURN_PCT) then
            return true
        end
    end
end

--[[
Base crit - 62%

Auspice - 33% crit
IOG - 13% crit
Bard Epic (12) + Fierce Eye (15) - 27% crit

Spire - 25% crit
OOW robe - 40% crit
Intensity - 50% crit
Glyph - 15% crit
]]--
local function TryBurn()
    -- Some items use Timer() and some use IsItemReady(), this seems to be mixed bag.
    -- Test them both for each item, and see which one(s) actually work.
    if BurnConditionMet() then
        local base_crit = 62
        local auspice = mq.TLO.Me.Song('Auspice of the Hunter')()
        if auspice then base_crit = base_crit + 33 end
        local iog = mq.TLO.Me.Song('Illusions of Grandeur')()
        if iog then base_crit = base_crit + 13 end
        local brd_epic = mq.TLO.Me.Song('Spirit of Vesagran')()
        if brd_epic then base_crit = base_crit + 12 end
        local fierce_eye = mq.TLO.Me.Song('Fierce Eye')()
        if fierce_eye then base_crit = base_crit + 15 end

        --[[
        |===========================================================================================
        |Item Burn
        |===========================================================================================
        ]]--

        for _,item in ipairs(items) do
            if item.Name() ~= 'Blightbringer\'s Tunic of the Grave' or base_crit < 100 then
                UseItem(item)
            end
        end

        --[[
        |===========================================================================================
        |Spell Burn
        |===========================================================================================
        ]]--

        for _,aa in ipairs(AAs) do
            -- don't go making twincast dots sad by cutting them in half
            if aa['name']:lower() == 'funeral pyre' then
                if not mq.TLO.Me.AltAbilityReady('heretic\'s twincast')() and not mq.TLO.Me.Buff('heretic\'s twincast')() then
                    UseAA(aa['name'], aa['id'])
                end
            elseif aa['name']:lower() == 'wake the dead' then
                if mq.TLO.SpawnCount('corpse radius 150')() > 0 then
                    UseAA(aa['name'], aa['id'])
                end
            else
                UseAA(aa['name'], aa['id'])
            end
        end

        BURN_NOW = false
    end
end

local function CheckMana()
    -- modrods
    local pct_mana = mq.TLO.Me.PctMana()
    if pct_mana < 75 then
        -- Find ModRods in CheckMana since they poof when out of charges, can't just find once at startup.
        local item_aa_modrod = mq.TLO.FindItem('Summoned: Radiant Modulation Shard')
        UseItem(item_aa_modrod)
        local item_wand_modrod = mq.TLO.FindItem('Wand of Restless Modulation')
        UseItem(item_wand_modrod)
        local item_wand_old = mq.TLO.FindItem('Wand of Phantasmal Transvergence')
        UseItem(item_wand_old)
    end
    if pct_mana < 65 then
        -- death bloom at some %
        UseAA(deathbloom['name'], deathbloom['id'])
    end
    if IsFighting() then
        if pct_mana < 40 then
            -- blood magic at some %
            UseAA(bloodmagic['name'], bloodmagic['id'])
        end
    end
    -- unified phoenix feather
end

local function SwapGemReady(spell_name, gem)
    return mq.TLO.Me.Gem(gem).Name() == spell_name
end

local function SwapSpell(spell_name, gem)
    mq.cmdf('/memspell %d "%s"', gem, spell_name)
    mq.delay('3s', SwapGemReady(spell_name, gem))
    mq.cmd('/invoke ${Window[SpellBookWnd].DoClose}')
end

local function ShouldSwapDots()
    -- Only swap spells in standard spell set
    if SPELL_SET ~= 'standard' then return end

    local woundsDuration = mq.TLO.Target.MyBuffDuration(spells['wounds']['name'])()
    local pyrelongDuration = mq.TLO.Target.MyBuffDuration(spells['pyrelong']['name'])()
    local fireshadowDuration = mq.TLO.Target.MyBuffDuration(spells['fireshadow']['name'])()
    if mq.TLO.Me.Gem(spells['wounds']['name'])() then
        if woundsDuration and woundsDuration > 20000 then
            if not pyrelongDuration or pyrelongDuration < 20000 then
                SwapSpell(spells['pyrelong']['name'], swap_gem)
            elseif not fireshadowDuration or fireshadowDuration < 20000 then
                SwapSpell(spells['fireshadow']['name'], swap_gem)
            end
        end
    elseif mq.TLO.Me.Gem(spells['pyrelong']['name'])() then
        if pyrelongDuration and pyrelongDuration > 20000 then
            if not woundsDuration or woundsDuration < 20000 then
                SwapSpell(spells['wounds']['name'], swap_gem)
            elseif not fireshadowDuration or fireshadowDuration < 20000 then
                SwapSpell(spells['fireshadow']['name'], swap_gem)
            end
        end
    elseif mq.TLO.Me.Gem(spells['fireshadow']['name'])() then
        if fireshadowDuration and fireshadowDuration > 20000 then
            if not woundsDuration or woundsDuration < 20000 then
                SwapSpell(spells['wounds']['name'], swap_gem)
            elseif not pyrelongDuration or pyrelongDuration < 20000 then
                SwapSpell(spells['pyrelong']['name'], swap_gem)
            end
        end
    else
        -- maybe we got interrupted or something and none of these are mem'd anymore? just memorize wounds again
        SwapSpell(spells['wounds']['name'], swap_gem)
    end

    local decayDuration = mq.TLO.Target.MyBuffDuration(spells['decay']['name'])()
    local gripDuration = mq.TLO.Target.MyBuffDuration(spells['grip']['name'])()
    if mq.TLO.Me.Gem(spells['decay']['name'])() then
        if decayDuration and decayDuration > 20000 then
            if not gripDuration or gripDuration < 20000 then
                SwapSpell(spells['grip']['name'], swap_gemDis)
            end
        end
    elseif mq.TLO.Me.Gem(spells['grip']['name'])() then
        if gripDuration and gripDuration > 20000 then
            if not decayDuration or decayDuration < 20000 then
                SwapSpell(spells['decay']['name'], swap_gemDis)
            end
        end
    else
        -- maybe we got interrupted or something and none of these are mem'd anymore? just memorize decay again
        SwapSpell(spells['decay']['name'], swap_gemDis)
    end
end

-- ADD UI STUFF

-- GUI Control variables
local openGUI = true
local shouldDrawGUI = true

local baseLeftPaneSize = 190
local leftPaneSize = 190

local function DrawSplitter(thickness, size0, min_size0)
    local x,y = ImGui.GetCursorPos()
    local delta = 0
    ImGui.SetCursorPosX(x + size0)
    
    ImGui.PushStyleColor(ImGuiCol.Button, 0, 0, 0, 0)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0, 0, 0, 0)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.6, 0.6, 0.6, 0.1)
    ImGui.Button('##splitter', thickness, -1)
    ImGui.PopStyleColor(3)

    ImGui.SetItemAllowOverlap()

    if ImGui.IsItemActive() then
        delta,_ = ImGui.GetMouseDragDelta()
        
        if delta < min_size0 - size0 then
            delta = min_size0 - size0
        end
        if delta > 275 - size0 then
            delta = 275 - size0
        end

        size0 = size0 + delta
        leftPaneSize = size0
    else
        baseLeftPaneSize = leftPaneSize
    end
    ImGui.SetCursorPosX(x)
    ImGui.SetCursorPosY(y)
end

local function HelpMarker(desc)
    ImGui.TextDisabled('(?)')
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.PushTextWrapPos(ImGui.GetFontSize() * 35.0)
        ImGui.Text(desc)
        ImGui.PopTextWrapPos()
        ImGui.EndTooltip()
    end
end

local function DrawComboBox(label, resultvar, options, bykey)
    if ImGui.BeginCombo(label, resultvar) then
        for i,j in pairs(options) do
            if bykey then
                if ImGui.Selectable(i, i == resultvar) then
                    resultvar = i
                end
            else
                if ImGui.Selectable(j, j == resultvar) then
                    resultvar = j
                end
            end
        end
        ImGui.EndCombo()
    end
    return resultvar
end

local function DrawCheckBox(labelText, idText, resultVar, helpText)
    resultVar,_ = ImGui.Checkbox(idText, resultVar)
    ImGui.SameLine()
    ImGui.Text(labelText)
    ImGui.SameLine()
    HelpMarker(helpText)
    return resultVar
end

local function DrawInputInt(labelText, idText, resultVar, helpText)
    resultVar = ImGui.InputInt(idText, resultVar)
    ImGui.SameLine()
    ImGui.Text(labelText)
    ImGui.SameLine()
    HelpMarker(helpText)
    return resultVar
end

local function DrawInputText(labelText, idText, resultVar, helpText)
    resultVar = ImGui.InputText(idText, resultVar)
    ImGui.SameLine()
    ImGui.Text(labelText)
    ImGui.SameLine()
    HelpMarker(helpText)
    return resultVar
end

local function DrawLeftPaneWindow()
    local _,y = ImGui.GetContentRegionAvail()
    if ImGui.BeginChild("left", leftPaneSize, y-1, true) then
        if PAUSED then
            if ImGui.Button('RESUME') then
                PAUSED = false
            end
        else
            if ImGui.Button('PAUSE') then
                PAUSED = true
            end
        end
        SPELL_SET = DrawComboBox('Spell Set', SPELL_SET, SPELL_SETS)
    end
    ImGui.EndChild()
end

local function DrawRightPaneWindow()
    local x,y = ImGui.GetContentRegionAvail()
    if ImGui.BeginChild("right", x, y-1, true) then
        BURN_ALWAYS = DrawCheckBox('Burn Always', '##burnalways', BURN_ALWAYS, 'Always be burning')
        BURN_NAMED = DrawCheckBox('Burn Named', '##burnnamed', BURN_NAMED, 'Burn all named')
        BURN_PROC = DrawCheckBox('Burn On Proliferation', '##burnproc', BURN_PROC, 'Burn when proliferation procs')
        BURN_PCT = DrawInputInt('Burn Percent', '##burnpct', BURN_PCT, 'Percent health to begin burns')
        DEBUFF = DrawCheckBox('Debuff', '##debuff', DEBUFF, 'Debuff targets')
        ALLIANCE = DrawCheckBox('Alliance', '##alliance', ALLIANCE, 'Use alliance spell')
        CHASE = DrawCheckBox('Chase', '##chase', CHASE, 'Chase somebody')
        CHASE_TARGET = DrawInputText('Chase Target', '##chasetarget', CHASE_TARGET, 'Chase Target')
        CHASE_DISTANCE = DrawInputInt('Chase Distance', '##chasedist', CHASE_DISTANCE, 'Distance to follow chase target')
    end
    ImGui.EndChild()
end

-- ImGui main function for rendering the UI window
local NECROBOTUI = function()
    openGUI, shouldDrawGUI = ImGui.Begin('NECROBOTUI', openGUI)
    if shouldDrawGUI then
        if ImGui.GetWindowHeight() == 500 and ImGui.GetWindowWidth() == 500 then
            ImGui.SetWindowSize(400, 200)
        end
        DrawSplitter(8, baseLeftPaneSize, 190)
        ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 6, 6)
        DrawLeftPaneWindow()
        ImGui.PopStyleVar()
        ImGui.SameLine()
        ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 6, 6)
        DrawRightPaneWindow()
        ImGui.PopStyleVar()
    end
    ImGui.End()
end

-- END UI STUFF

local function TriggerBurn()
    BURN_NOW = true
end
mq.bind('/burnnow', TriggerBurn)

mq.imgui.init('NECROBOTUI', NECROBOTUI)

mq.TLO.Lua.Turbo(500)
GetNecroCount()

-- Main Loop
while true do
    if not PAUSED then
        if mq.TLO.Cursor() then
            mq.cmd('/autoinventory')
        end
        CheckChase()
        TryDebuffTarget()
        if not CycleDots() then
            ShouldSwapDots()
        end
        TryBurn()
        CheckMana()
    else
        mq.delay(1000)
    end
end
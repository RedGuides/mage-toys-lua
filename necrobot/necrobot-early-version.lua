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

local mq = require('mq')

-- define stinky necro spells
local spell_pyre_short = mq.TLO.Spell('Pyre of Klraggek').RankName()
local spell_pyre_short_id = mq.TLO.Spell(spell_pyre_short).ID()

local spell_wounds = mq.TLO.Spell('Septic Wounds').RankName()
local spell_wounds_id = mq.TLO.Spell(spell_wounds).ID()

local spell_alliance = mq.TLO.Spell('Malevolent Coalition').RankName()
local spell_alliance_id = mq.TLO.Spell(spell_alliance).ID()

local spell_synergy = mq.TLO.Spell('Assert For Blood').RankName()
local spell_synergy_id = mq.TLO.Spell(spell_synergy).ID()

local spell_composite = mq.TLO.Spell('Composite Paroxysm').RankName()
local spell_composite_id = mq.TLO.Spell(spell_composite).ID()

-- todo: use TLO to find our current progression spell / level
local spell_composite_progression =  mq.TLO.Spell('Composite Paroxysm 6').RankName()
local spell_composite_progression_id =  mq.TLO.Spell(spell_composite_progression).ID()

local spell_oblivion = mq.TLO.Spell('Oblivion').RankName()
local spell_oblivion_id = mq.TLO.Spell(spell_oblivion).ID()

local spell_comp_dis = mq.TLO.Spell('Danvid\'s Grip of Decay').RankName()
local spell_comp_dis_id = mq.TLO.Spell(spell_comp_dis).ID()

local spell_plant = mq.TLO.Spell('Miasma').RankName()
local spell_plant_id = mq.TLO.Spell(spell_plant).ID()

local spell_venom = mq.TLO.Spell('Crystal Crawler Venom').RankName()
local spell_venom_id = mq.TLO.Spell(spell_venom).ID()

local spell_pallid = mq.TLO.Spell('Dracnia\'s Pallid Haze').RankName()
local spell_pallid_id = mq.TLO.Spell(spell_pallid).ID()

local spell_pyre_long = mq.TLO.Spell('Pyre of the Wretched').RankName()
local spell_pyre_long_id = mq.TLO.Spell(spell_pyre_long).ID()

local spell_shadow = mq.TLO.Spell('Broiling Shadow').RankName()
local spell_shadow_id = mq.TLO.Spell(spell_shadow).ID()

local spell_grasp = mq.TLO.Spell('Tserrina\'s Grasp').RankName()
local spell_grasp_id = mq.TLO.Spell(spell_grasp).ID()

local spell_undead = mq.TLO.Spell('Scourge of Destiny').RankName()
local spell_undead_id = mq.TLO.Spell(spell_undead).ID()

local spell_leech = mq.TLO.Spell('Frozen Leech').RankName()
local spell_leech_id = mq.TLO.Spell(spell_leech).ID()

local spell_ignite = mq.TLO.Spell('Ignite Intellect').RankName()
local spell_ignite_id = mq.TLO.Spell(spell_ignite).ID()

local spell_decay = mq.TLO.Spell('Danvid\'s Decay').RankName()
local spell_decay_id = mq.TLO.Spell(spell_decay).ID()

local spell_grip = mq.TLO.Spell('Grip of Zorglim').RankName()
local spell_grip_id = mq.TLO.Spell(spell_grip).ID()

local spell_wounds_proc = mq.TLO.Spell('Septic Proliferation').RankName()
local spell_wounds_proc_id = mq.TLO.Spell(spell_wounds_proc).ID()

local spell_scent_terris = mq.TLO.Spell('Scent of Terris').RankName()
local spell_scent_terris_id = mq.TLO.Spell(spell_scent_terris).ID()

local spell_scent_mortality = mq.TLO.Spell('Scent of Mortality').RankName()
local spell_scent_mortality_id = mq.TLO.Spell(spell_scent_mortality).ID()

local item_oom_robe = mq.TLO.FindItem('Blightbringer\'s Tunic of the Grave')
local item_cov_robe = mq.TLO.FindItem('Velium Endowned Soulslayer Robe')
local item_circle_of_power = mq.TLO.FindItem('Rage of Rolfron')

local song_silent_casting = mq.TLO.Me.Song('Silent Casting')
local song_focus_of_arcanum = mq.TLO.Me.Song('Focus of Arcanum')
local song_hand_of_death = mq.TLO.Me.Song('Hand of Death')

local aa_mercurial_torment = mq.TLO.Me.Buff('Mercurial Torment')
local aa_twincast = mq.TLO.Me.Buff('Heretic\'s Twincast')
local aa_spire = mq.TLO.Me.Buff('Spire of Necromancy')
local aa_funeral_pyre = mq.TLO.Me.Buff('Funeral Pyre')
local aa_funeral_dirge = mq.TLO.Me.Buff('Funeral Dirge')
local aa_gathering_dusk = mq.TLO.Me.Buff('Gathering Dusk')

local dots = {}
dots[1] = {spell_wounds_id, spell_wounds}
dots[2] = {spell_shadow_id, spell_shadow}
dots[3] = {spell_comp_dis_id, spell_comp_dis}
dots[4] = {spell_pyre_long_id, spell_pyre_long}
dots[5] = {spell_plant_id, spell_plant}
dots[6] = {spell_grasp_id, spell_grasp}
dots[7] = {spell_leech_id, spell_leech}
dots[8] = {spell_undead_id, spell_undead}
dots[9] = {spell_pallid_id, spell_pallid}
dots[10] = {spell_venom_id, spell_venom}
dots[11] = {spell_ignite_id, spell_ignite}
dots[12] = {spell_oblivion_id, spell_oblivion}
dots[13] = {spell_pyre_short_id, spell_pyre_short}

--[[
    track data about our targets, for one-time or long-term affects. 
    for example: we do not need to continually poll when to debuff a mob if the debuff will last 17+ minutes
                 if the mob aint dead by then, you should re-roll a wizard.
]]--
local targets = {}

function IsTargetDottedWith(spellId, spellName)
    if (tostring(mq.TLO.Target.MyBuff(spellName)) == 'NULL') then return false end

    local targetDotId = tostring(mq.TLO.Target.MyBuff(spellName).ID)
    local value = (targetDotId ~= 'NULL' and spellId ~= targetDotId) 
    return value
end


function CycleDots()
    for key, value in ipairs(dots)
    do
        if (IsFighting()) then
            mq.cmd.echo("spell: " ..key .. " => " ..value[2] .. " (" ..value[1] ..")")
            CastDot(value[1], value[2])
        end
    end 
end

function TryDebuffTarget()
    if (IsFighting()) then
        if (not targets[mq.TLO.Target.ID()] or not targets[mq.TLO.Target.ID()][2]) then
            local isScentAAReady = mq.TLO.Me.AltAbilityReady('Scent of Thule')
            local isDebuffedAlready = IsTargetDottedWith(spell_scent_terris_id, spell_scent_terris)
    
            if (isDebuffedAlready) then
                isDebuffedAlready = IsTargetDottedWith(spell_scent_mortality_id, spell_scent_mortality)
            end
    
            if (isScentAAReady and not isDebuffedAlready) then
                mq.cmd.alt('activate 751')
            end
    
            if (isDebuffedAlready) then
                table.insert(targets, mq.TLO.Target.ID(), {"debuffed", true})
            end
            mq.delay(5) 
        end
    end
 end

function IsFighting() 
    return (mq.TLO.Target.ID() ~= nil and (mq.TLO.Me.CombatState() ~= "ACTIVE" and mq.TLO.Me.CombatState() ~= "RESTING") and mq.TLO.Me.Standing() and not mq.TLO.Me.Feigning() and mq.TLO.Target.Type() == "NPC" and mq.TLO.Target.Type() ~= "Corpse")
end

function IsDotReady(spellId, spellName)
    local buffDuration = 0
    local remainingCastTime = 0
    if (not mq.TLO.Me.SpellReady(spellName)) then
        return false
    end

    buffDuration = mq.TLO.Target.MyBuffDuration(spellName)
    if (not IsTargetDottedWith(spellId, spellName)) then
        -- target does not have the dot, we are ready
        return true
    else
        if (tostring(buffDuration) == 'NULL') then 
            return true 
        end
        buffDuration = tonumber(tostring(buffDuration))
        remainingCastTime = tonumber(mq.TLO.Spell(spellName).MyCastTime())
        return (buffDuration < remainingCastTime)
    end 

    return false
end

function CastDot(spellId, spellName)
    if (spellId == spell_comp_dis_id) then
        if (IsDotReady(spell_decay_id, spell_decay) or IsDotReady(spell_grip_id, spell_grip)) then
            mq.cmd.casting(spell_comp_dis_id ..' -maxretries=2')
            mq.delay(5)
            while (mq.TLO.Cast.Status() == "C")
            do
                mq.delay(5)
            end
        end
        return
    end

    if (spellId == spell_composite_id) then
        if (IsDotReady(spell_composite_progression_id, spell_composite_progression)) then
            mq.cmd.casting(spell_composite_id ..'  -maxretries=2')
            mq.delay(5)
            while (mq.TLO.Cast.Status() == "C")
            do
                mq.delay(5)
            end
        end
        return
    end

    if (IsDotReady(spellId, spellName)) then
        mq.cmd.casting(spellId ..'  -maxretries=2')
        mq.delay(5)
		while (mq.TLO.Cast.Status() == "C")
        do
			mq.delay(5)
		end
    end
end

function TryBurn()
    -- Some items use Timer() and some use IsItemReady(), this seems to be mixed bag. 
    -- Test them both for each item, and see which one(s) actually work.
    if (IsTargetDottedWith(spell_wounds_proc_id, spell_wounds_proc)) then
        --[[
            |===========================================================================================
            |Item Burn
            |===========================================================================================
        ]]--

        -- Brightbringer's Tunic of the Grave 5m CD            
        if (item_oom_robe.Timer() == 0) then 
            mq.cmd.useitem(item_oom_robe)
            mq.delay(5)
        end
        
        -- Velium Endowned Soulslayer Robe 10m CD
        if (item_cov_robe.Timer() == 0) then 
            mq.cmd.useitem(item_cov_robe)
            mq.delay(5)
        end

        -- Rage of Rolfron 30m CD
        if (item_circle_of_power.Timer() == 0) then 
            mq.cmd.useitem(item_circle_of_power)
            mq.delay(5)
        end


        --[[
        |===========================================================================================
        |Spell Burn
        |===========================================================================================
        ]]--

        -- Silent Casting 12m CD
        if (tostring(song_silent_casting) == 'NULL' and mq.TLO.Me.AltAbilityTimer('Silent Casting') == 0) then
            mq.cmd.alt('activate 500')
            mq.delay(5)
        end

        -- Focus of Arcanum 10m CD
        if (tostring(song_focus_of_arcanum) == 'NULL' and mq.TLO.Me.AltAbilityTimer('Focus Arcanum') == 0) then
            mq.cmd.alt('activate 1211')
            mq.delay(5)
        end

        -- Mercurial Torment 24m CD
        if (tostring(aa_mercurial_torment) == 'NULL' and mq.TLO.Me.AltAbilityReady('Mercurial Torment')) then
            mq.cmd.alt('activate 430')
            mq.delay(5)
        end

        -- Heretic's Twincast 15m CD
        if (tostring(aa_twincast) == 'NULL' and mq.TLO.Me.AltAbilityTimer('Heretic\'s Twincast') == 0) then
            mq.cmd.alt('activate 677')
            mq.delay(5)
        end

        -- Spire of Necromancy 24m CD
        if (tostring(aa_spire) == 'NULL' and mq.TLO.Me.AltAbilityReady('Spire of Necromancy')) then
            mq.cmd.alt('activate 1390')
            mq.delay(5)
        end

        -- Hand of Death 8.5m CD
        if (tostring(song_hand_of_death) == 'NULL' and mq.TLO.Me.AltAbilityReady('Hand of Death')) then
            mq.cmd.timed('20 /alt activate 1257')
            mq.delay(5)
        end

        -- Funeral Pyre 20m CD
        if (tostring(aa_funeral_pyre) == 'NULL' and tostring(aa_funeral_dirge) == 'NULL' and mq.TLO.Me.AltAbilityTimer('Funeral Pyre') == 0) then
            mq.cmd.alt('activate 710')
            mq.delay(5)
        end

        -- Gathering Dusk 10m CD
        if (tostring(aa_gathering_dusk) == 'NULL' and mq.TLO.Me.AltAbilityTimer('Gathering Dusk') == 0) then
            mq.cmd.alt('activate 629')
            mq.delay(5)
        end


        --[[
        |===========================================================================================
        |Pet Burn
        |===========================================================================================
        --]]

        -- Companion's Fury 10m CD
        if (mq.TLO.Me.AltAbilityTimer('Companion\'s Fury') == 0) then
            mq.cmd.alt('activate 766') 
            mq.delay(5)
        end

        -- Companion's Fortification 15m CD
        if (mq.TLO.Me.AltAbilityTimer('Companion\'s Fortification') == 0) then
            mq.cmd.timed('30 /alt activate 3707') 
            mq.delay(5)
        end
            
        -- Rise of Bones 10m CD
        if (mq.TLO.Me.AltAbilityTimer('Rise of Bones') == 0) then
            mq.cmd.timed('60 /alt activate 900') 
            mq.delay(5)
        end

        -- Wake the Dead 3m CD
        if (mq.TLO.Me.AltAbilityTimer('Wake the Dead') == 0) then
            mq.cmd.timed('90 /alt activate 175') 
            mq.delay(5)
        end
        
        -- Swarm of Decay 9m CD
        if (mq.TLO.Me.AltAbilityTimer('Swarm of Decay') == 0) then
            mq.cmd.timed('120 /alt activate 320') 
            mq.delay(5)
        end
    end
end 


-- Main Loop
mq.TLO.Lua.Turbo(80)
while true do
    TryDebuffTarget()      
    CycleDots()
    TryBurn()
    mq.delay(5)
end



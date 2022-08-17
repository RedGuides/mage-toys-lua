local item_names = {
    ['mask']= 'Summoned: Visor of Shoen',
    ['armor']='Folded Pack of the Centien\'s Plate',
    ['heirlooms']='Folded Pack of the Diabo\'s Heirlooms',
    ['weapons']='Folded Pack of Shak Dathor\'s Armaments'
}

local mq = require('mq')
local version = '1.1.1'
mq.TLO.Lua.Turbo(500)

local DEBUG = false
local RUN_STATE = 'idle'

local WEAPON_SETS = {'wind','fire','ice','rage', 'low aggro'}
local RIGHT_HAND  = 'fire'
local LEFT_HAND = 'ice'
local AUTO_INVENTORY_CONTAINER = false -- auto inventory temp containers vs delete
local AUTO_INVENTORY_EXTRA_ITEMS = true -- auto inventory left over / unused items vs delete
local TARGET_SETS = {'self', 'peers'}
local TOYS_TARGET = 'self'
local NO_UI = false

local args = {...}
for _,arg in ipairs(args) do
    if arg == 'debug' then
        DEBUG = true
    end
    if arg == 'junkcontainers' then
        AUTO_INVENTORY_CONTAINER = false
    end
    if arg == 'keepcontainers' then -- wins if both args exist
        AUTO_INVENTORY_CONTAINER = true
    end
    if arg == 'keepextras' then
        AUTO_INVENTORY_EXTRA_ITEMS = true
    end
    if arg == 'junkextras' then -- wins if both args exist
        AUTO_INVENTORY_EXTRA_ITEMS = false
    end
    if arg == 'background' then
        NO_UI = true
    end
end

local function Welcome()
    mq.cmd.echo('=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=\n\agStarting Script\ax\n\ayPet Toys\ax: version \ag' .. version .. '\ax. Written by \aySnowOrc\ax\n=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=')
    if DEBUG then
        mq.cmd.echo('DEBUG: \ag' .. tostring(DEBUG) .. '\ax')
        mq.cmd.echo('RIGHT_HAND: \ag' .. tostring(RIGHT_HAND) .. '\ax')
        mq.cmd.echo('LEFT_HAND: \ag' .. tostring(LEFT_HAND) .. '\ax')
        mq.cmd.echo('AUTO_INVENTORY_CONTAINER: \ag' .. tostring(AUTO_INVENTORY_CONTAINER) .. '\ax')
        mq.cmd.echo('AUTO_INVENTORY_EXTRA_ITEMS: \ag' .. tostring(AUTO_INVENTORY_EXTRA_ITEMS) .. '\ax')
    end
end

local function Goodbye()
    mq.cmd.echo('=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=\n\agExiting Script\ax.\n=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=')
    return "done"
end

Welcome()

local function GetPetItem(item)
    return {['id']=mq.TLO.FindItem(item).ID(), ['name']=item}
end 

local function GetMainInvSlot()
    for i=1,10 do
        local current_pack = 'pack' .. tostring(i)
        if (nil == mq.TLO.InvSlot(current_pack).Item.Container()) then
            return {['slot']=i, ['pack']=current_pack}
        end
    end
    return nil
end

local function GetInvSlot(item)
    for i=1,10 do
        local current_pack = 'pack' .. tostring(i)
        local num_pack_items = mq.TLO.InvSlot(current_pack).Item.Container()
        if (nil ~= num_pack_items) then
            for j=1,num_pack_items do
                local current_pack_item = mq.TLO.InvSlot(current_pack).Item.Item(j).Name()
                if (item['name'] == current_pack_item) then
                    return {['slot']=j, ['pack']=current_pack}
                end
            end 
        end
    end
    return nil
end

local function MoveToPet() 
    if (mq.TLO.Target.ID() ~= mq.TLO.Me.Pet.ID()) then
        mq.cmd('/target pet id ' .. tostring(mq.TLO.Me.Pet.ID()))
    end
    mq.cmd('/nav target')
    while(mq.TLO.Navigation.Active())
    do 
        mq.delay(5)
    end

    return true
end

local function PlaceInInventoryOrDestroyItem(is_container, original_inventory_slot)
    local shouldKeep = false
    if is_container then 
        shouldKeep = AUTO_INVENTORY_CONTAINER 
    else 
        shouldKeep = AUTO_INVENTORY_EXTRA_ITEMS
    end
    if (shouldKeep) then
        mq.cmd('/nomodkey /itemnotify in ' .. original_inventory_slot['pack'] .. ' ' .. tostring(original_inventory_slot['slot']) .. ' leftmouseup')
    else
        mq.cmd('/destroy')
    end
end

local function AutoInventoryOrDestroyItem(is_container, item_on_cursor)
    local shouldKeep = false
    if is_container then 
        shouldKeep = AUTO_INVENTORY_CONTAINER 
    else 
        shouldKeep = AUTO_INVENTORY_EXTRA_ITEMS
    end

    if (shouldKeep) then
        mq.cmd.echo("Returning extra \ay" .. item_on_cursor .. "\ax to inventory...")
        mq.cmd('/autoinventory')
    else
        mq.cmd.echo("Destroying extra item: \ay" .. item_on_cursor .. "\ax...")
        mq.cmd('/destroy')
    end
end

local function AcceptPetTrade(original_inventory_slot)
    if (DEBUG) then
        mq.cmd.echo('AcceptPetTrade. original_inventory_slot.')
        if not original_inventory_slot == nil then
            if not original_inventory_slot['pack'] == nil then
                mq.cmd.echo('Pack: ' .. original_inventory_slot['pack'])
            end
            if not original_inventory_slot['slot'] == nil then
                mq.cmd.echo('Slot:' .. tostring(original_inventory_slot['slot]']))
            end 
        end
    end

    -- accept trade w/ pet give window
    mq.delay('1s', mq.TLO.Window('GiveWnd').Open())
    mq.cmd('/notify GiveWnd GVW_Give_Button leftmouseup')
    mq.delay('1s', not mq.TLO.Window('GiveWnd').Open())

     -- if pet already had then item,  you cannot give it again, so return it
     mq.delay('1s', mq.TLO.Cursor.ID())

     while(mq.TLO.Cursor.ID()) do
        if DEBUG then
            mq.cmd.echo("pet already has item id " .. mq.TLO.Cursor.ID())
        end

        if (original_inventory_slot == nil) then
             -- if the original item was a folded pack, then pet would be rejecting & handing back
             -- individual armor pieces
             AutoInventoryOrDestroyItem(false, mq.TLO.Cursor.Name())
         else
            -- return the original item to it's original position in your inventory
            if DEBUG then
                mq.cmd.echo("return original item to it's original position in your inventory")
            end
            PlaceInInventoryOrDestroyItem(true, original_inventory_slot)
        end
        mq.delay(20, not mq.TLO.Cursor.ID())
    end
end

local function GiveItemToPet(item, original_inventory_slot)
    if (DEBUG) then
        mq.cmd.echo('GiveItemToPet. Item: ' .. item['name'] .. ' original_inventory_slot: ' .. tostring(original_inventory_slot['slot]']))
    end
  
    if (item['id'] == nil) then
        mq.cmd.echo('You do not have the item: \ay' .. item['name'] .. '\ax.')
        return
    end

    mq.cmd.echo("Giving \ag" .. item['name'] .. " (" .. item['id'] .. ") \ax to pet...")
    if (DEBUG) then
        mq.cmd.echo('Putting Item on Cursor. Item: ' .. item['name'] .. ' , id: ' .. item['id'])
    end

    while(not mq.TLO.Cursor.ID()) do
        mq.cmd('/itemnotify "' .. item['name'] .. '" leftmouseup')
        mq.delay(20, mq.TLO.Cursor.ID())
    end

    while(mq.TLO.Cursor.ID()) do
        if (mq.TLO.Cursor.ID() == item['id']) then
            mq.cmd('/nomodkey /click left target')
        end
        mq.delay(15, not mq.TLO.Cursor.ID())
    end

    AcceptPetTrade(original_inventory_slot)
end

local function HandleEmptyContainer(current_pack, original_inventory_slot) 
    if DEBUG then
        mq.cmd.echo("HandleEmptyContainer, AUTO_INVENTORY_CONTAINER: " .. tostring(AUTO_INVENTORY_CONTAINER))
    end
    -- pick up the now empty container
    while(not mq.TLO.Cursor.ID())
    do
        mq.cmd('/nomodkey /itemnotify ' .. current_pack .. ' leftmouseup')
        mq.delay(20, mq.TLO.Cursor.ID())
    end

    -- inventory / destroy the empty container
    while(mq.TLO.Cursor.ID())
    do
        PlaceInInventoryOrDestroyItem(true, original_inventory_slot)
        mq.delay(15, not mq.TLO.Cursor.ID())
    end
end

local function SelectWeaponsByIndex()
    local windIndex = 1 
    local fireIndex = 3
    local iceIndex = 5
    local rageIndex = 7
    local peaceIndex = 9
    local leftIndex = fireIndex -- default fire, off-hand weapon
    local rightIndex = iceIndex+1 -- default ice, primary weapon

    if (LEFT_HAND == 'fire') then
        leftIndex = fireIndex
    elseif (LEFT_HAND == 'ice') then
        leftIndex = iceIndex
    elseif (LEFT_HAND == 'wind') then
        leftIndex = windIndex
    elseif (LEFT_HAND == 'rage') then
        leftIndex = rageIndex
    elseif (LEFT_HAND == 'low aggro') then
        leftIndex = peaceIndex
    end

    if (RIGHT_HAND == 'fire') then
        rightIndex = fireIndex+1
    elseif (RIGHT_HAND == 'ice') then
        rightIndex = iceIndex+1
    elseif (RIGHT_HAND == 'wind') then
        rightIndex = windIndex+1
    elseif (RIGHT_HAND == 'rage') then
        rightIndex = rageIndex+1
    elseif (RIGHT_HAND == 'low aggro') then
        rightIndex = peaceIndex+1
    end

    return leftIndex, rightIndex
end

local function GivePetWeapons(current_pack, num_pack_items, original_inventory_slot)
    -- handle weapons containers, sift through items, give 2, auto-inventory the rest  

    local leftIndex, rightIndex = SelectWeaponsByIndex()

    for i=1,num_pack_items do
        local current_pack_item = mq.TLO.InvSlot(current_pack).Item.Item(i).Name()
        local current_pack_item_id = mq.TLO.InvSlot(current_pack).Item.Item(i).ID()
        while(not mq.TLO.Cursor.ID())
        do
            mq.cmd('/nomodkey /itemnotify in "' .. current_pack .. '" ' .. tostring(i) .. ' leftmouseup')
            mq.delay(20, mq.TLO.Cursor.ID())
        end
     
        if (i==leftIndex or i==rightIndex) then
            mq.cmd.echo("Giving \ag" .. current_pack_item .. "\ax to pet...")
            while(mq.TLO.Cursor.ID()) do
                if (mq.TLO.Cursor.ID() == current_pack_item_id) then
                    mq.cmd('/nomodkey /click left target')
                else
                    mq.cmd('/autoinv') -- what is in cursor changed or is unexpected. bad user. keep whatever it is.
                end
                mq.delay(50, not mq.TLO.Cursor.ID())
            end
        else
            while(mq.TLO.Cursor.ID())
            do
                AutoInventoryOrDestroyItem(false, current_pack_item)
                mq.delay(50, not mq.TLO.Cursor.ID())
            end
        end
    end
    
    AcceptPetTrade(nil)
    
    HandleEmptyContainer(current_pack, original_inventory_slot)
end

local function GivePetArmor(current_pack, num_pack_items, original_inventory_slot)
    -- handle generic containers, give all items
    for i=1,num_pack_items do
        local current_pack_item = mq.TLO.InvSlot(current_pack).Item.Item(i).Name()
        local current_pack_item_id = mq.TLO.InvSlot(current_pack).Item.Item(i).ID()
        if (nil ~= current_pack_item and nil ~= current_pack_item_id) then
            -- give current pack item to pet
            mq.cmd.echo("Giving \ag" .. current_pack_item .. "\ax to pet...")

            while(not mq.TLO.Cursor.ID())
            do
                mq.cmd('/itemnotify "' .. current_pack_item .. '" leftmouseup')
                mq.delay(50, mq.TLO.Cursor.ID())
            end
        
            while(mq.TLO.Cursor.ID())
            do
                if (mq.TLO.Cursor.ID() == current_pack_item_id) then
                    mq.cmd('/nomodkey /click left target')
                end
                mq.delay(50, not mq.TLO.Cursor.ID())
            end
        end

        -- we can only give up to 4 items at a time, to a pet. so give n items, where n <= 4
        if (i%4==0 or nil == current_pack_item) then
            AcceptPetTrade(nil)
        end
    end

    HandleEmptyContainer(current_pack, original_inventory_slot)
end

local function GiveContainerItemsToPet(main_inventory_slot, original_inventory_slot)
    local current_pack = main_inventory_slot['pack']
    local container_name = mq.TLO.InvSlot(current_pack).Item.Name()
    if container_name == nil then
        mq.cmd.echo('Unknown container name.')
    else
        mq.cmd.echo('Giving items to pet from: ' .. container_name)
    end

    if (current_pack == nil) then
        mq.cmd.echo('Unknown main inventory slot.')
        return
    else
        mq.cmd.echo('current pack: ' .. current_pack)
    end

    -- open pet container, for visual effects1
    mq.cmd('/nomodkey /itemnotify ' .. current_pack .. ' rightmouseup')
    mq.delay('1s')

    local num_pack_items = mq.TLO.InvSlot(current_pack).Item.Container()

    if (container_name == 'Pouch of Quellious') then
        GivePetWeapons(current_pack, num_pack_items, original_inventory_slot)
    else
        GivePetArmor(current_pack, num_pack_items, original_inventory_slot)
    end
end 

local function UnpackFoldedItem(item, main_inventory_slot)
    if (item['id'] == nil) then
        mq.cmd.echo('Unable to unpack item. You do not have: \ay' .. item['name'] .. '\ax')
        return
    end
    mq.cmd('/itemnotify "' .. item['name'] .. '" leftmouseup')
    mq.delay('2s', mq.TLO.Cursor.ID())
    if (mq.TLO.Cursor.ID()) then
        mq.cmd('/nomodkey /itemnotify ' .. main_inventory_slot['pack'] .. ' leftmouseup')
        mq.delay(5)
    end
    
    mq.delay('2s', not mq.TLO.Cursor.ID())
    if (not mq.TLO.Cursor.ID()) then
        mq.cmd('/nomodkey /itemnotify ' .. main_inventory_slot['pack'] .. ' rightmouseup')
        mq.delay(5)
    end

    mq.delay('2s', mq.TLO.Cursor.ID())
    if (mq.TLO.Cursor.ID()) then
        mq.cmd('/nomodkey /itemnotify ' .. main_inventory_slot['pack'] .. ' leftmouseup')
        mq.delay(5)
    end

    mq.delay('1s')
end

local ShouldUseDanNet = function()
   return mq.Plugin('mq2dannet')
end

local GiveToysToPeers = function()
    local cli_args = ''
    -- explicitly pass args to peers, in order to override their defaults 
    if AUTO_INVENTORY_CONTAINER then
        cli_args = cli_args .. ' keepextraitems'
    else
        cli_args = cli_args .. ' junkextraitems'
    end
    if AUTO_INVENTORY_EXTRA_ITEMS then
        cli_args = cli_args .. ' keepextras'
    else
        cli_args = cli_args .. ' junkextras'
    end

    if ShouldUseDanNet then
        if TOYS_TARGET == 'peers' then
            mq.cmd('/dgexecute /lua run toys background' .. cli_args)
        end
    else
        if TOYS_TARGET == 'peers' then
            mq.cmd('/bca //lua run toys background' .. cli_args)
        end
    end
    return "running"
end


local RunGiveToysScript = function()
    -- Main 
    if DEBUG then
        mq.cmd.echo('running: \agRunGiveToysScript\ax')
    end

    local pet_items = {
        ['mask']=GetPetItem(item_names['mask']),
        ['armor']=GetPetItem(item_names['armor']),
        ['heirlooms']=GetPetItem(item_names['heirlooms']),
        ['weapons']=GetPetItem(item_names['weapons'])
    }
    
    local inv_slots = {
        ['main']=GetMainInvSlot(),
        ['mask']=GetInvSlot(pet_items['mask']),
        ['armor']=GetInvSlot(pet_items['armor']),
        ['heirlooms']=GetInvSlot(pet_items['heirlooms']),
        ['weapons']=GetInvSlot(pet_items['weapons'])
    }
    
    local pet_id = mq.TLO.Me.Pet.ID()

    if DEBUG then
        mq.cmd.echo('running: \agchecking for pet\ax')
    end
    if (0 == pet_id) then
        mq.cmd.echo("You currently have \arno pet\ax...")
        if NO_UI then 
            mq.exit()
        end
        return "idle"
    end

    if DEBUG then
        mq.cmd.echo('running: \agchecking for main inventory slot\ax')
    end
    if (inv_slots['main'] == nil) then
        mq.cmd.echo("You have \ay no main inventory slots\ax available! You first will need a \armain inventory\ax slot open in order to unpack your mage toys.")
        if NO_UI then
            mq.exit()
        end
        return "idle"
    else 
        mq.cmd.echo("Unpacking items in main inventory slot: " .. inv_slots['main']['pack'])
    end

    local at_pet = false

    if DEBUG then
        mq.cmd.echo('running: \agtry giving mask\ax')
    end
    if (inv_slots['mask']) then
        at_pet = MoveToPet()
        GiveItemToPet(pet_items['mask'], inv_slots['mask'])
    else
        mq.cmd.echo("You currently have \arno mask\ax. Missing \ay" .. item_names['mask'] .. "\ax")
    end
  
    if DEBUG then
        mq.cmd.echo('running: \agtry giving armor\ax')
    end
    if (inv_slots['armor']) then
        if (not at_pet) then
            at_pet = MoveToPet()
        end
        UnpackFoldedItem(pet_items['armor'], inv_slots['main'])
        GiveContainerItemsToPet(inv_slots['main'], inv_slots['armor'])
    else
        mq.cmd.echo("You currently have \arno armor\ax. Missing \ay" .. item_names['armor'] .. "\ax")
    end

    if DEBUG then
        mq.cmd.echo('running: \agtry giving heirlooms\ax')
    end
    if (inv_slots['heirlooms']) then
        if (not at_pet) then
            at_pet = MoveToPet()
        end
        UnpackFoldedItem(pet_items['heirlooms'], inv_slots['main'])
        GiveContainerItemsToPet(inv_slots['main'], inv_slots['heirlooms'])
    else
        mq.cmd.echo("You currently have \arno heirlooms\ax. Missing \ay" .. item_names['heirlooms'] .. "\ax")
    end

    if DEBUG then
        mq.cmd.echo('running: \agtry giving weapons\ax')
    end
    if (inv_slots['weapons']) then
        if (not at_pet) then
            at_pet = MoveToPet()
        end
        UnpackFoldedItem(pet_items['weapons'], inv_slots['main'])
        GiveContainerItemsToPet(inv_slots['main'], inv_slots['weapons'])
    else
        mq.cmd.echo("You currently have \arno weapons\ax. Missing \ay" .. item_names['weapons'] .. "\ax")
    end

    return Goodbye()
end
-- ADD UI STUFF

-- GUI Control variables
local openGUI = true
local shouldDrawGUI = true

local baseLeftPaneSize = 280
local leftPaneSize = 280

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
        RIGHT_HAND = DrawComboBox('Right Hand', RIGHT_HAND, WEAPON_SETS)
        LEFT_HAND = DrawComboBox('Left Hand', LEFT_HAND, WEAPON_SETS)
        TOYS_TARGET = DrawComboBox('Give To?', TOYS_TARGET, TARGET_SETS)
        ImGui.SameLine() 
        HelpMarker("Self to give toys to only your pet.\nPeers to have everyone in your peer network also give their toys to their pets.")
    end
    ImGui.EndChild()
end

local function DrawRightPaneWindow()
    local x,y = ImGui.GetContentRegionAvail()
    if ImGui.BeginChild("right", x, y-1, true) then
        AUTO_INVENTORY_CONTAINER = DrawCheckBox('Keep Containers', '##keepcontainer', AUTO_INVENTORY_CONTAINER, 'Keep temporary containers, instead of deleting them')
        AUTO_INVENTORY_EXTRA_ITEMS = DrawCheckBox('Keep Leftover Items', '##keepextraitems', AUTO_INVENTORY_EXTRA_ITEMS, 'Keep left over items your pet did not need')
        if (RUN_STATE == 'idle') then
            if ImGui.Button('Give Toys') then
                if TOYS_TARGET == 'peers' then
                    RUN_STATE = GiveToysToPeers()
                else
                    RUN_STATE = 'running'
                end
            end
        end
    end
    ImGui.EndChild()
end

-- ImGui main function for rendering the UI window
local petToysUI = function()
    openGUI, shouldDrawGUI = ImGui.Begin('petToysUI', openGUI)
    if shouldDrawGUI then
        ImGui.SetWindowSize(600, 150)
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
if NO_UI then
    RUN_STATE='running'
else
    mq.imgui.init('petToysUI', petToysUI)
end

-- Main Loop
local CheckGameState = function()
    if mq.TLO.MacroQuest.GameState() ~= 'INGAME' or RUN_STATE == 'done' then 
        mq.exit() 
    end
end

-- imgui work seems to be happening in it's own thread, i cannot call a function that can mq.delay() from ui. 
-- so, i use a RUN_STATE to track what to do in the main loop, which fires needed functions
-- RUN_STATE is either idle, running, or done. 
-- Pet Toys is expected to be ephemeral, once pet has his stuff, we terminate.
local Loop = function()
    while true do
        if false == openGUI and RUN_STATE ~= 'done' then
            RUN_STATE = Goodbye()
        end
        if RUN_STATE == 'running' then
            RUN_STATE = RunGiveToysScript()
            mq.delay(10)
        else            
            CheckGameState() 
            mq.delay(1000)
        end
    end
end

Loop()

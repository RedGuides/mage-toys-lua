
# Pet Toys

A lua script that will give your pet toys.

You already have one or more of the following pet items in your inventory:

-   a mask
-   a weapons pack
-   an armor pack
-   an heirlooms pack

You want to unpack everything and give it to your pet.

Then, when done, either delete, or keep, the empty summoned phantom containers, as well as any left over items your pet may have already had equipped.

If no main inventory slot exists, you will not be able to unpack the items; the script will not continue.

If no pet exists, the script will not continue.

For future support, with new spells / expansions, the only thing that needs to change is the item_names list at the top of the script. 

If your mage has newer (or older) pet spells, feel free to modify this.

## Contents

-   [1. Commands](https://www.redguides.com/wiki/Draft:Pet_Toys#Commands)
-   [2. Basic Usage](https://www.redguides.com/wiki/Draft:Pet_Toys#Basic_Usage)
-   [3. Settings](https://www.redguides.com/wiki/Draft:Pet_Toys#Settings)
-   [4. See also](https://www.redguides.com/wiki/Draft:Pet_Toys#See_also)

## Commands

[/lua run toys](https://www.redguides.com/wiki/Command:/lua_run_toys "Command:/lua run toys")

Runs the Pet Toys LUA script, starting the Pet Toys UI in game.

[/lua run toys background](https://www.redguides.com/wiki/Command:/lua_run_toys_background "Command:/lua run toys background")

Runs the script with default ui options, without presenting a ui.

[/lua run toys debug](https://www.redguides.com/wiki/Command:/lua_run_toys_debug "Command:/lua run toys debug")

Verbose debug info available in standard output.

[/lua stop toys](https://www.redguides.com/wiki/Command:/lua_stop_toys "Command:/lua stop toys")

Stops the Pet Toys LUA script; closing the Pet Toys UI in game.

## Basic Usage

1. Free up at least one main inventory slot.

2. Create a pet.

3. Summon level appropriate Pet Toys; Mask, Armor, Heirlooms and Weapons (right-hand + left-hand)

4. Then run the script:  `/lua run toys`, this will display the following Pet Toys UI;  
[![PetToysUI.png](https://www.redguides.com/mediawiki/w/images/thumb/9/99/PetToysUI.png/300px-PetToysUI.png)](https://www.redguides.com/wiki/File:PetToysUI.png)

5. Resize the window from its initial state to your liking.

6. Use the Pet Toys UI to select what weapons you would prefer for Right-hand and Left-hand, then Click the 'Give Toys' button.

You will see messages for script starting up, units of work it is doing, and then exiting in your MQ window.

If something strange happens to where the script won't finish, simply stop the script:  `/lua stop toys`

Note: If you do not have any appropriate pet toys available in your inventory, you will see the following;  
[![PetToysNoToys.png](https://www.redguides.com/mediawiki/w/images/thumb/d/df/PetToysNoToys.png/300px-PetToysNoToys.png)](https://www.redguides.com/wiki/File:PetToysNoToys.png)

## Settings

At the current release, as stated by the Dev, the LUA is hard-coded to use the following Pet Toys;

-   mask= 'Summoned: Visor of Shoen'
-   armor='Folded Pack of the Centien's Plate'
-   heirlooms='Folded Pack of the Diabo's Heirlooms'
-   weapons'='Folded Pack of Shak Dathor's Armaments'

The user is required to edit the LUA script itself to make changes to the above, explaining how to do this is beyond the level of this wiki entry.

## Author

snoworc

### Software type

Lua

### Plugins used

* MQ2Nav
* MQ2DanNet

### Maintained

I will review Pull Requests and Issues.

### Links

🏠  [Resource](https://www.redguides.com/community/resources/pet-toys.2316/)  ([download](https://www.redguides.com/community/resources/pet-toys.2316//download)) ([review](https://www.redguides.com/community/resources/pet-toys.2316//rate))  

🤝  [Support](https://www.redguides.com/community/threads/pet-toys.80144/)  

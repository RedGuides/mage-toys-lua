
# mq2macs

Common [macros](http://macroquest.sourceforge.net/includes/manual.php), [lua](https://gitlab.com/macroquest/next/mqnext/-/wikis/MQ2Lua) scripts, and c++ plugins to do awesome things. Often based off RedGuide or used with other RedGuide [plugins](https://gitlab.com/redguides/plugins).

## BuffBot5
BuffBoff5: This version works for not just a single buffer, but an entire buff bot team.

This uses a combination of [DanNet](https://github.com/dannuic/MQ2Dan), [event](http://macroquest.sourceforge.net/includes/manual.php#mq2custom) processing, and [sqlite3](https://www.sqlite.org/doclist.html) to allow an entire bot team to interact and coordinate buffs for buff requestors.

**DanNet:** Uses [Zyre](https://github.com/zeromq/zyre/blob/master/README.md) to register all bot clients on your peer server via [multicasting](https://en.wikipedia.org/wiki/Multicast).

**Custom Event Processing:** Handles tells and hails (says) requests.

**SqlLite3:** Uses a database to track state of buffs. Even though buff bots could be run on different computers in the same network (thanks to DanNet), we need a way to coordinate and track what each bot is doing. 

The assumption here is all bots are running on the same computer, using a central database to track buff activity. 

`/hail <any-buff-bot>`: This is equivalent to "/say "buff", which each member in the NetBot team will evaluate.

In the .INI file, you will see "buff" is the generic request for all common buffs. Where as asking for a teleport or a corpse summon is a very specific request.

`/say <alt-ability>`: Each member in the NetBot team will evaluate. If they have this ability in the .Ini config file, they will use this AA.

    examples: 
    		/say invis  == enchanter bot will invis and invis to undead you.
    		/say summon == necro bot will summon your corpse

`/say <item>`: Each member in the NetBot team will evaluate. Items and Alt Abilities are processed the same way.

    examples:
    	/say wep 	== mage bot will give you pet weapons
    	/say mask	== mage bot will give you pet mask
    	/say armor	== mage bot will give you pet armor
    	/say heirloom	== mage bot will give you pet heirlooms
    	/say toys	== mage bot will give you all pet toys

 `/say item <count>`: If you put an integer after the item name, the bot will give you multiple items. This is capped at 4.
	
    example:
    		/say toys 2 == mage bot will give you two sets of pet toys

 `/say vs /tell` -- both should work equivalently, if you want to be less obvious about getting a buff, use `/tell`.
 
 ### list
 You can send a special tell to a bot, in the guild hall, within line of sight, to get a list of all available buffs.
 
 example: `/tell <buff bot> list`
 
  
## necro.lua
This lua script automates necro for raid damage. 

Under development.

### References

[color codes](https://docs.macroquest.org/macroquest/commands/slash-commands/echo)

[Lua Programming Language](https://www.lua.org/manual/5.1/)

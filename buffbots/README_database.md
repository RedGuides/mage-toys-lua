# SQLite

## install chocolatey

## choco install sqlite3

## create the database with ./buffbots.ps1

### maintainence 

the database is used while the macros are running. While buffs are processing a buff cycle, items fill up. However, at the end of a buff cycle, the database should be empty.

if the macro dies, it is possible the database should be manually emptied.

```bash
sqlite3 buffbots.db

>>> SELECT * FROM bots;
>>> 
```

This should be empty. if it is not, simply delete the items yourself

```bash
>>> DELETE FROM bots;

>>> SELECT * FROM bots;
>>>
```

Now this will be empty.


### DB location?

We are using a relative path, which is based off of the ROOT of the MQ2 process.

i.e. Wherever MacroQuest.Exe lives, so shall this database. Copy it there.

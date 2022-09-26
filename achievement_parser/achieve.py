import argparse

"""
example usages: 
$ python3 achieve.py --help
$ python3 achieve -c hisRoyalUberness
$ python3 achieve --character hisRoyalUberness --server zek --expansion "Terror of Luclin" --eqPath $EVERQUEST_ROOT 

defaults:
------------
server: povar (sorry)
expansion: Terror of Luclin
eq file path: default eq path in windows linux subsystem (sorry)

You can set and pass in an environment variable for eq root path, like in example above
"""
eqFilePathDefault = "/mnt/c/Users/Public/Daybreak Game Company/Installed Games/Everquest/"

def readFile(fileName):
    eqFile = open(fileName, 'r')
    return eqFile.readlines()

def printResults(missingAchievements):
    numResults = len(missingAchievements)
    if numResults > 0:
        print("=-=-=-=-=-=-=-=-=-=-=-=")
        for missingAchievement in missingAchievements:
            print(missingAchievement, end="")
        print("=-=-=-=-=-=-=-=-=-=-=-=\nTotal incomplete: " + str(numResults))

def main(character, server, eqFilePath, expac):
    print(f"Character: {character}")
    print(f"Server: {server}")
    print(f"EQ Root Directory: {eqFilePath}")
    print(f"Expansion: {expac}")

    # input file(s)
    matchFileSuffix = f"_{server}-Achievements.txt"
    matchFile = eqFilePath + character + matchFileSuffix

    # parse patterns
    matchStartSuffix = ": Raids"
    matchEndSuffix = ": Hunts"

    startSearch = expac + matchStartSuffix
    endSearch = expac + matchEndSuffix

    lines = readFile(matchFile)
    
    missingAchievements = []
    matchFound = False

    print(f"Search block: [{startSearch}]...[{endSearch}]")

    # parse achievements output file
    for line in lines:
        if line.startswith(startSearch):
            matchFound = True

        if line.startswith(endSearch):
            break

        if matchFound:
            if line.startswith("I\t\t") and ":" in line:
                cleanLine = line.replace("I\t\t", "")
                missingAchievements.append(cleanLine)

    printResults(missingAchievements)

if __name__ == "__main__":
    argparse = argparse.ArgumentParser(description="Parse EQ Raid achievements output file")
    argparse.add_argument("-c", "--character", help="Character name", dest="character", required=True)
    argparse.add_argument("-s", "--server", help="Server name of character", dest="server", default="povar", required=False)
    argparse.add_argument("-e", "--expansion", help="Name of expansion", dest="expac", default="Terror of Luclin", required=False)
    argparse.add_argument("-p", "--eqFilePath", help="Root path of everquest", dest="eqFilePath", default=f"{eqFilePathDefault}")
    parsed = argparse.parse_args()

    main(parsed.character.title(), parsed.server.lower(), parsed.eqFilePath, parsed.expac)

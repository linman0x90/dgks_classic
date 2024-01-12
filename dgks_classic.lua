--TODO List
--Duel win detection
--Pet kills on Hunters
--Battleground start msg closer to start of bg
--Nemesis notifications
--Log classes on prey/predators
--Feature parity with Killshot
	-- Random Text
	-- X Random Pet - No longer possible 
	-- X Execute
	-- X Screenshot
	-- Random Emote
--Reduce externals/libs
--NPC Emote Targeting
--Just making a change so twitch triggers an update
--Cross Character Killer Klvl Kclass KGuild Victim Vlvl VClass VGuild Timestamp Location Killshot_Log
--Cross server ranking system (bnet channels)

local version = "@project-version@"
local databaseversion = "1"
local addonName, ns = ...
local streak = 0
local deathstreak = 0
local multikill = 0
local lastrxkiller = ""
local lastrxvictim = ""
local lastrxtimestamp = 0
local lastkill = 0
local timestamp = 0
local lastToHurtMe = ""
local newestconfigversion = 1
local frame, events = CreateFrame("Frame"), {};
local damageDealers = {}
local targetList = {} -- Used for Execute
local playerName = UnitName("player")
local inArena = false
local inBG = false
local lastMessage, lastSender, lastTimestamp --Versionchecking duplicate detection
local soundPath = "Interface\\AddOns\\dgks\\sounds\\"


dgks = LibStub("AceAddon-3.0"):NewAddon("dgks", "AceEvent-3.0", "AceConsole-3.0", "LibSink-2.0","AceComm-3.0","AceSerializer-3.0")

function sortListByLength(t,a,b)
	local acount, bcount = 0,0
	for _ in pairs(t[a]) do acount = acount + 1 end
	for _ in pairs(t[b]) do bcount = bcount + 1 end
	return acount > bcount
end

function spairs(t, order)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys 
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

function getSortedList(mytable, count)
	local tempString = ""
	for i,v in spairs(mytable, function (t,a,b) return sortListByLength(t,a,b) end) do
		tempString = tempString .. table.maxn(v) .. " " .. i .. " " .. v[table.maxn(v)] .. "\n"
		if count ~= nil then
			count = count - 1
		end
		if count == 0 then return tempString end
	end
	return tempString
end

local function giveOptions() 
	local options = { 
		type = "group",
		name = "dG KillShot",
		--handler = dgks,/dgk
		get = function(k) return db[k.arg] end,
		set = function(k, v) db[k.arg] = v end,
		args = {
			version = {
				type = "description",
				name = "Version " .. version,
				order = 2
			},
			prey = {
				type = "description",
				name = "Top Prey:\n" .. getSortedList(dgks.db.profile.killList, 5),
				order = 5
			},
			predators = {
				type = "description",
				name = "Top Predators:\n" .. getSortedList(dgks.db.profile.deathList, 5),
				order = 10
			},
			killstreak = {
				type = "description",
				name = "Current killing streak: " .. streak .. "\nLongest killing streak: " .. dgks.db.profile.maxstreak .. "\n",
				order = 12,
				width = 1
			},
			deathstreak = {
				type = "description",
				name = "Current death streak: " .. deathstreak .. "\nLongest death streak: " .. dgks.db.profile.maxdeathstreak .. "\n",
				order = 14,
				width = 2
			},
			maxks = {
				type = "description",
				name = "Last 20 Kills\n" .. dgks.getKillLog(),
				order = 15
			},
			resetmaxks = {
				type = 'execute',
				name = 'Reset Stats',
				func = function()
					streak = 0
					deathstreak = 0
					multikill = 0
					dgks.db.profile.maxstreak = dgks.db.defaults.profile.maxstreak
					dgks.db.profile.maxdeathstreak = dgks.db.defaults.profile.maxdeathstreak
					dgks.db.profile.killlog = dgks.db.defaults.profile.killlog
					dgks.db.profile.killList = dgks.db.defaults.profile.killList
					dgks.db.profile.deathList = dgks.db.defaults.profile.deathList
				end,
				width = "full",
				order = 20
			},
			resetdgks = {
				type = 'execute',
				name = 'Reset All dG Killshot Settings',
				func = function()
					streak = 0
					deathstreak = 0
					multikill = 0
					dgks.db:ResetProfile()
				end,
				width = "full",
				order = 30
			},
			--@debug@
			-- Dev Debugging functions
			testdgkskill = {
				type = 'execute',
				name = 'Simulate Killshot',
				func = function()
					dgks:Test()
				end
			},
			testdgdeath = {
				type = 'execute',
				name = 'Simulate Death',
				func = function()
					dgks:TestPlayerDeath()
				end
			}
			--@end-debug@
		}
	}
	return options
end

local function giveGeneral()
	local general = {
		type = "group",
		name = "General",
		handler = dgks,
		args = {
			style = {
				type = 'select',
				name = 'Select how often to trigger killshots notifications:',
				desc = 'DoTA plays sound on every kill, UT plays on new ranks',
				get = function()
					return dgks.db.profile.style
				end,
				set = function(info,b)
					dgks.db.profile.style = b
					
				end,
				values = {
					dota = "Every Killshot (DoTA/LoL Style)",
					ut = "Every " .. dgks.db.profile.utrank .. " Killshots (Unreal Tournament Style)"
				},
				order = 10,
				width = 2
			},
			dopreparesound = {
				type = 'toggle',
				name = 'Play prepare sound when entering battlegrounds',
				get = function()
					return dgks.db.profile.dopreparesound
				end,
				set = function(info, b)
					dgks.db.profile.dopreparesound = b
				end,
				width = "full",
				order = 11
			},
			doexecutesound = {
				type = 'toggle',
				name = 'Play execute sound when Player target hits threshold',
				get = function()
					return dgks.db.profile.doexecutesound
				end,
				set = function(info, b)
					dgks.db.profile.doexecutesound = b
				end,
				width = "full",
				order = 12
			},
			doexecutesoundpve = {
				type = 'toggle',
				name = 'Play execute sound when NPC target hits threshold',
				get = function()
					return dgks.db.profile.doexecutesoundpve
				end,
				set = function(info, b)
					dgks.db.profile.doexecutesoundpve = b
				end,
				width = "full",
				order = 13
			},
			doexecutepercent = {
				type = 'range',
				name = 'Execute Percent',
				desc = 'The percent health that triggers the execute sound',
				width = "full",
				get = function() return dgks.db.profile.doexecutepercent end,
				set = function(info, v) dgks.db.profile.doexecutepercent = v end,
				disabled = function() if dgks.db.profile.doexecutesound or dgks.db.profile.doexecutesoundpve then return false else return true end end,
				min = 1,
				max = 40,
				step = 1,
				order = 14
			},
			dochatbox = {
				type = 'toggle',
				name = 'Print killshots and deaths in chatbox in addition to logging in /dgks',
				get = function()
					return dgks.db.profile.dochatbox
				end,
				set = function(info, b)
					dgks.db.profile.dochatbox = b
				end,
				width = "full",
				order = 15
			},
			dozonechange = {
				type = 'toggle',
				name = 'Clear Streaks on Zone Change',
				get = function()
					return dgks.db.profile.dozonechange
				end,
				set = function(info, b)
					dgks.db.profile.dozonechange = b
				end,
				width = "full",
				order = 20
			},
			doemote = {
				type = 'select',
				name = 'Do built in Emote',
				desc = 'Choose an Emote',
				get = function()
					return dgks.db.profile.doemote
				end,
				set = function(info, b)
					dgks.db.profile.doemote = b
				end,
				values = {
					none = "None",
					BELCH = "Belch",
					BOGGLE = "Boggle",
					BONK = "Bonk",
					BORED = "Bored",
					BOUNCE = "Bounce",
					BOW = "Bow",
					APPLAUD = "Bravo",
					BRB = "BRB",
					BURP = "Burp",
					BYE = "Bye",
					CACKLE = "Cackle",
					CALM = "Calm",
					SCRATCH = "Cat",
					CHEER = "Cheer",
					EAT = "Chew",
					CHICKEN = "Chicken",
					CHUCKLE = "Chuckle",
					CLAP = "Clap",
					COMFORT = "Comfort",
					COMMEND = "Commend",
					CONFUSED = "Confused",
					CONGRATULATE = "Congrats",
					COUGH = "Cough",
					COWER = "Cower",
					CRACK = "Crack Knuckles",
					CRINGE = "Cringe",
					CRY = "Cry",
					CUDDLE = "Cuddle",
					CURIOUS = "Curious",
					CURTSEY = "Curtsey",
					DANCE = "Dance",
					DOOM = "Doom",
					DRINK = "Drink",
					DROOL = "Drool",
					EYE = "Eye",
					FART = "Fart",
					FROWN = "Frown",
					GASP = "Gasp",
					GLARE = "Glare",
					GLOAT = "Gloat",
					GOLFCLAP = "Golf Clap",
					GREET = "Greet",
					GRIN = "Grin",
					GROAN = "Groan",
					GROWL = "Growl",
					GUFFAW = "Guffaw",
					HAIL = "Hail",
					HAPPY = "Happy",
					HISS = "Hiss",
					HUG = "Hug",
					FIDGET = "Impatient",
					INSULT = "Insult",
					INTRODUCE = "Introduce",
					JK = "JK",
					KISS = "Kiss",
					KNEEL = "Kneel",
					KNUCKLES = "Knuckles",
					LAUGH = "Laugh",
					LICK = "Lick",
					LISTEN = "Listen",
					LOST = "Lost",
					LOVE = "Love",
					ANGRY = "Mad",
					MASSAGE = "Massage",
					MOAN = "Moan",
					MOCK = "Mock",
					MOO = "Moo",
					MOON = "Moon",
					MOURN = "Mourn",
					NO = "No",
					NOD = "Nod",
					NOSEPICK = "Nosepick",
					PAT = "Pat",
					PEER = "Peer",
					SHOO = "Shoo",
					PITY = "Pity",
					PLEAD = "Plead",
					POINT = "Point",
					POKE = "Poke",
					PONDER = "Ponder",
					POUNCE = "Pounce",
					PRAISE = "Praise",
					PRAY = "Pray",
					PURR = "Purr",
					PUZZLE = "Puzzled",
					TALKQ = "Question",
					RAISE = "Raise",
					RASP = "Rasp (Rude Gesture)",
					READY = "Ready",
					SHAKE = "Shake Rear",
					ROAR = "Roar",
					ROFL = "ROFL",
					RUDE = "Rude",
					SALUTE = "Salute",
					SEXY = "Sexy",
					SHIMMY = "Shimmy",
					SHY = "Shy",
					SIGH = "Sigh",
					JOKE = "Silly",
					SLAP = "Slap",
					SMELL = "Smell",
					SMILE = "Smile",
					SMIRK = "Smirk",
					SNARL = "Snarl",
					SNICKER = "Snicker",
					SNIFF = "Sniff",
					SNUB = "Snub",
					SOOTHE = "Soothe",
					APOLOGIZE = "Sorry",
					SPIT = "Spit",
					STARE = "Stare",
					SURPRISED = "Surprised",
					TAP = "Tap",
					TAUNT = "Taunt",
					TEASE = "Tease",
					THANK = "Thank",
					THREATEN = "Threaten",
					TICKLE = "Tickle",
					TIRED = "Tired",
					VETO = "Veto",
					VICTORY = "Victory",
					VIOLIN = "Violin",
					WAVE = "Wave",
					WELCOME = "Welcome",
					WHINE = "Whine",
					WHISTLE = "Whistle",
					WINK = "Wink",
					WORK = "Work",
					YAWN = "Yawn"
				},
				order = 25
				},
			dotxtemote = {
				type = 'toggle',
				name = 'Show Custom Emote',
				desc = 'Toggle Emote Spam',
				get = function()
					return dgks.db.profile.dotxtemote
				end,
				set = function(info, b)
					dgks.db.profile.dotxtemote = b
				end,
				width = "full",
				order = 30
			},
			ksemote = {
				type = 'input',
				name = 'Custom Emote Message',
				desc = "Use this to customize the emote message. $v = victim $s = streak",
				usage = "<message>",
				get = function()
					return dgks.db.profile.ksemote
				end,
				set = function(info, b)
					dgks.db.profile.ksemote = b
				end,
				width = "full",
				order = 40
			},
			docombattext = {
				type = 'toggle',
				name = "Show Combat Text (Game setting Combat->Scrolling Combat Text for Self must also be enabled.)",
				desc = 'Toggle Combat Text Spam',
				get = function()
					return dgks.db.profile.docombattext
				end,
				set = function(info, b)
					dgks.db.profile.docombattext = b
				end,
				width = "full",
				order = 50
			},
			kstext = {
				type = 'input',
				name = 'Scrolling Text Message',
				desc = 'Use this to customize the Scrolling Text Message. $k = killer, $v = victim',
				usage = "<message>",
				get = function()
					return dgks.db.profile.kstext
				end,
				set = function(info, b)
					dgks.db.profile.kstext = b
				end,
				width = "full",
				order = 60
			},
			--[[ dopet = {
				type = 'toggle',
				name = 'Summon Random Pet',
				desc = 'Summon Random Pet on Killshot',
				get = function()
					return dgks.db.profile.dopet
				end,
				set = function(info, b)
					dgks.db.profile.dopet = b
				end,
				width = "full",
				order = 30
			}, ]]--
			soundpack = {
				type = 'select',
				name = 'Sound Pack',
				desc = 'Choose a sound pack',
				get = "getSoundPack",
				set = "setSoundPack",
				values = {
					male = "male",
					female = "female",
					sexy = "sexy",
					baby = "baby"
				},
				order = 85
			},
			dosound = {
				type = 'toggle',
				name = "Play Sounds",
				desc = 'Toggle Sound Spam',
				get = function()
					return dgks.db.profile.dosound
				end,
				set = function(info, b)
					dgks.db.profile.dosound = b
				end,
				order = 70
			},
			soundchannel = {
				type = 'select',
				name = "Sound Channel",
				desc = 'Select the sound channel used for audio notifications. Default: Master',
				get = function()
					return dgks.db.profile.soundchannel
				end,
				set = function(info, b)
					dgks.db.profile.soundchannel = b
				end,
				values = {
					Master = "Master",
					SFX = "SFX",
					Ambience = "Ambience",
					Music = "Music"
				},
				order = 80
			},
			dopve = {
				type = 'toggle',
				name = "Trigger off NPC/PVE Killshots - VERY SPAMMY, use for testing.",
				desc = "Please don't use this",
				get = function()
					return dgks.db.profile.dopve
				end,
				set = function(info, b)
					dgks.db.profile.dopve = b
				end,
				width = "full",
				order = 90
			}
		}
	}
	return general
end

local function giveBroadcasts()
	local broadcasts = {
		type = "group",
		name = "Broadcasts",
		handler = dgks,
		args = {
			dobroadcasts = {
				type = 'toggle',
				name = 'Enable Broadcasts',
				desc = 'Enable/Disable all broadcasts',
				get = function()
					return dgks.db.profile.dobroadcasts
				end,
				set = function(info, b)
					dgks.db.profile.dobroadcasts = b
				end,
				width = "full",
				order = 80
			},
			doguild = {
				type = 'toggle',
				name = 'Broadcasts to/from Guild',
				desc = 'Broadcast killshot to dgks users in guild.',
				get = function()
					return dgks.db.profile.doguild
				end,
				set = function(info, c)
					dgks.db.profile.doguild = c
				end,
				disabled = function()
					return not dgks.db.profile.dobroadcasts
				end,
				width = "full",
				order = 90
			},
			doraid = {
				type = 'toggle',
				name = 'Broadcasts to/from Party/Raid/Instance',
				desc = 'Broadcast killshot to dgks users in your paty or raid.',
				get = function()
					return dgks.db.profile.doraid
				end,
				set = function(info, d)
					dgks.db.profile.doraid = d
				end,
				disabled = function()
					return not dgks.db.profile.dobroadcasts
				end,
				width = "full",
				order = 110
			},
			dobg = {
				type = 'toggle',
				name = 'Broadcast to/from Battleground',
				desc = 'Broadcast killshot to battleground.',
				get = function()
					return dgks.db.profile.dobg
				end,
				set = function(info, e)
					dgks.db.profile.dobg = e
				end,
				disabled = function()
					return not dgks.db.profile.dobroadcasts
				end,
				width = "full",
				order = 120
			},
			dofriends = {
				type = 'toggle',
				name = 'Broadcast to Friends',
				desc = 'Broadcast killshot to friends.',
				get = function()
					return dgks.db.profile.dofriends
				end,
				set = function(info, e)
					dgks.db.profile.dofriends = e
				end,
				disabled = function()
					return not dgks.db.profile.dobroadcasts
				end,
				width = "full",
				order = 125
			},
			versioncheck = {
				type = 'execute',
				width = "full",
				name = 'Check other players versions',
				desc = 'Check Versions',
				func = "VersionCheck",
				order = 130
			}
		}
	}
	return broadcasts 
end

local function giveScreenshots()
	local screenshots = {
		type = "group",
		name = "Screenshots",
		handler = dgks,
		args = {
			doscreenshotonkill = {
				type = 'toggle',
				name = 'Enable Screenshot on Killshot',
				desc = 'Enable Screenshot on Killshot',
				get = function()
					return dgks.db.profile.doscreenshotonkill
				end,
				set = function(info, b)
					dgks.db.profile.doscreenshotonkill = b
				end,
				width = "full",
				order = 80
			},
			doscreenshotonstreak = {
				type = 'toggle',
				name = 'Enable Screenshot on new max killing streak',
				desc = 'Enable Screenshot on new max killing streak',
				get = function()
					return dgks.db.profile.doscreenshotonstreak
				end,
				set = function(info, b)
					dgks.db.profile.doscreenshotonstreak = b
				end,
				width = "full",
				order = 90
			},
			doscreenshotonmultikill = {
				type = 'toggle',
				name = 'Enable Screenshot on multikill',
				desc = 'Enable Screenshot on multikill',
				get = function()
					return dgks.db.profile.doscreenshotonmultikill
				end,
				set = function(info, b)
					dgks.db.profile.doscreenshotonmultikill = b
				end,
				width = "full",
				order = 100
			},
			doscreenshotonduelwin = {
				type = 'toggle',
				name = 'Enable Screenshot on duel win',
				desc = '',
				get = function()
					return dgks.db.profile.doscreenshotonduelwin
				end,
				set = function(info, b)
					dgks.db.profile.doscreenshotonduelwin = b
				end,
				width = "full",
				order = 105
			},
			doscreenshotonduelloss = {
				type = 'toggle',
				name = 'Enable Screenshot on duel loss',
				desc = '',
				get = function()
					return dgks.db.profile.doscreenshotonduelloss
				end,
				set = function(info, b)
					dgks.db.profile.doscreenshotonduelloss = b
				end,
				width = "full",
				order = 106
			},
			doscreenshotondeath = {
				type = 'toggle',
				name = 'Enable Screenshot on death',
				desc = 'Enable Screenshot on death',
				get = function()
					return dgks.db.profile.doscreenshotondeath
				end,
				set = function(info, b)
					dgks.db.profile.doscreenshotondeath = b
				end,
				width = "full",
				order = 110
			},	
			versioncheck = {
				type = 'execute',
				width = "full",
				name = 'Test Screenshot Lag',
				desc = 'Enable screenshots will cause a short lag, please test first.',
				func = function() Screenshot() end,
				order = 130
			}
		}
	}
	return screenshots 
end

local function giveDuels()
	local duels = {
		type = "group",
		name = "Duels",
		handler = dgks,
		args = {
			duelhumiliation = {
				type = 'toggle',
				name = 'Play humiliation when player flees a duel',
				desc = '',
				get = function()
					return dgks.db.profile.duelhumiliation
				end,
				set = function(info, b)
					dgks.db.profile.duelhumiliation = b
				end,
				width = "full",
				order = 10
			},
			duelemotewin = {
				type = 'select',
				name = 'Emote for Duel Win',
				desc = 'Choose an Emote',
				get = function()
					return dgks.db.profile.duelemotewin
				end,
				set = function(info, b)
					dgks.db.profile.duelemotewin = b
				end,
				values = {
					none = "None",
					BELCH = "Belch",
					BOGGLE = "Boggle",
					BONK = "Bonk",
					BORED = "Bored",
					BOUNCE = "Bounce",
					BOW = "Bow",
					APPLAUD = "Bravo",
					BRB = "BRB",
					BURP = "Burp",
					BYE = "Bye",
					CACKLE = "Cackle",
					CALM = "Calm",
					SCRATCH = "Cat",
					CHEER = "Cheer",
					EAT = "Chew",
					CHICKEN = "Chicken",
					CHUCKLE = "Chuckle",
					CLAP = "Clap",
					COMFORT = "Comfort",
					COMMEND = "Commend",
					CONFUSED = "Confused",
					CONGRATULATE = "Congrats",
					COUGH = "Cough",
					COWER = "Cower",
					CRACK = "Crack Knuckles",
					CRINGE = "Cringe",
					CRY = "Cry",
					CUDDLE = "Cuddle",
					CURIOUS = "Curious",
					CURTSEY = "Curtsey",
					DANCE = "Dance",
					DOOM = "Doom",
					DRINK = "Drink",
					DROOL = "Drool",
					EYE = "Eye",
					FART = "Fart",
					FROWN = "Frown",
					GASP = "Gasp",
					GLARE = "Glare",
					GLOAT = "Gloat",
					GOLFCLAP = "Golf Clap",
					GREET = "Greet",
					GRIN = "Grin",
					GROAN = "Groan",
					GROWL = "Growl",
					GUFFAW = "Guffaw",
					HAIL = "Hail",
					HAPPY = "Happy",
					HUG = "Hug",
					FIDGET = "Impatient",
					INSULT = "Insult",
					INTRODUCE = "Introduce",
					JK = "JK",
					KISS = "Kiss",
					KNEEL = "Kneel",
					KNUCKLES = "Knuckles",
					LAUGH = "Laugh",
					LICK = "Lick",
					LISTEN = "Listen",
					LOST = "Lost",
					LOVE = "Love",
					ANGRY = "Mad",
					MASSAGE = "Massage",
					MOAN = "Moan",
					MOCK = "Mock",
					MOO = "Moo",
					MOON = "Moon",
					MOURN = "Mourn",
					NO = "No",
					NOD = "Nod",
					NOSEPICK = "Nosepick",
					PAT = "Pat",
					PEER = "Peer",
					SHOO = "Shoo",
					PITY = "Pity",
					PLEAD = "Plead",
					POINT = "Point",
					POKE = "Poke",
					PONDER = "Ponder",
					POUNCE = "Pounce",
					PRAISE = "Praise",
					PRAY = "Pray",
					PURR = "Purr",
					PUZZLE = "Puzzled",
					TALKQ = "Question",
					RAISE = "Raise",
					RASP = "Rasp (Rude Gesture)",
					READY = "Ready",
					SHAKE = "Shake Rear",
					ROAR = "Roar",
					ROFL = "ROFL",
					RUDE = "Rude",
					SALUTE = "Salute",
					SEXY = "Sexy",
					SHIMMY = "Shimmy",
					SHY = "Shy",
					SIGH = "Sigh",
					JOKE = "Silly",
					SLAP = "Slap",
					SMELL = "Smell",
					SMILE = "Smile",
					SMIRK = "Smirk",
					SNARL = "Snarl",
					SNICKER = "Snicker",
					SNIFF = "Sniff",
					SNUB = "Snub",
					SOOTHE = "Soothe",
					APOLOGIZE = "Sorry",
					SPIT = "Spit",
					STARE = "Stare",
					SURPRISED = "Surprised",
					TAP = "Tap",
					TAUNT = "Taunt",
					TEASE = "Tease",
					THANK = "Thank",
					THREATEN = "Threaten",
					TICKLE = "Tickle",
					TIRED = "Tired",
					VETO = "Veto",
					VICTORY = "Victory",
					VIOLIN = "Violin",
					WAVE = "Wave",
					WELCOME = "Welcome",
					WHINE = "Whine",
					WHISTLE = "Whistle",
					WINK = "Wink",
					WORK = "Work",
					YAWN = "Yawn"
				},
				order = 25
				},
				duelemoteloss = {
				type = 'select',
				name = 'Emote for Duel Loss',
				desc = 'Choose an Emote',
				get = function()
					return dgks.db.profile.duelemoteloss
				end,
				set = function(info, b)
					dgks.db.profile.duelemoteloss = b
				end,
				values = {
					none = "None",
					BELCH = "Belch",
					BLOWKISS = "Blow Kiss",
					BOGGLE = "Boggle",
					BONK = "Bonk",
					BORED = "Bored",
					BOUNCE = "Bounce",
					BOW = "Bow",
					APPLAUD = "Bravo",
					BRB = "BRB",
					BURP = "Burp",
					BYE = "Bye",
					CACKLE = "Cackle",
					CALM = "Calm",
					SCRATCH = "Cat",
					CHEER = "Cheer",
					EAT = "Chew",
					CHICKEN = "Chicken",
					CHUCKLE = "Chuckle",
					CLAP = "Clap",
					COMFORT = "Comfort",
					COMMEND = "Commend",
					CONFUSED = "Confused",
					CONGRATULATE = "Congrats",
					COUGH = "Cough",
					COWER = "Cower",
					CRACK = "Crack Knuckles",
					CRINGE = "Cringe",
					CRY = "Cry",
					CUDDLE = "Cuddle",
					CURIOUS = "Curious",
					CURTSEY = "Curtsey",
					DANCE = "Dance",
					DOOM = "Doom",
					DRINK = "Drink",
					DROOL = "Drool",
					EYE = "Eye",
					FART = "Fart",
					FROWN = "Frown",
					GASP = "Gasp",
					GLARE = "Glare",
					GLOAT = "Gloat",
					GOLFCLAP = "Golf Clap",
					GREET = "Greet",
					GRIN = "Grin",
					GROAN = "Groan",
					GROWL = "Growl",
					GUFFAW = "Guffaw",
					HAIL = "Hail",
					HAPPY = "Happy",
					HUG = "Hug",
					FIDGET = "Impatient",
					INSULT = "Insult",
					INTRODUCE = "Introduce",
					JK = "JK",
					KISS = "Kiss",
					KNEEL = "Kneel",
					KNUCKLES = "Knuckles",
					LAUGH = "Laugh",
					LICK = "Lick",
					LISTEN = "Listen",
					LOST = "Lost",
					LOVE = "Love",
					ANGRY = "Mad",
					MASSAGE = "Massage",
					MOAN = "Moan",
					MOCK = "Mock",
					MOO = "Moo",
					MOON = "Moon",
					MOURN = "Mourn",
					NO = "No",
					NOSEPICK = "Nosepick",
					PAT = "Pat",
					PEER = "Peer",
					SHOO = "Shoo",
					PITY = "Pity",
					PLEAD = "Plead",
					POINT = "Point",
					POKE = "Poke",
					PONDER = "Ponder",
					POUNCE = "Pounce",
					PRAISE = "Praise",
					PRAY = "Pray",
					PURR = "Purr",
					PUZZLE = "Puzzled",
					TALKQ = "Question",
					RAISE = "Raise",
					RASP = "Rasp (Rude Gesture)",
					READY = "Ready",
					SHAKE = "Shake Rear",
					ROAR = "Roar",
					ROFL = "ROFL",
					RUDE = "Rude",
					SALUTE = "Salute",
					SEXY = "Sexy",
					SHIMMY = "Shimmy",
					SHY = "Shy",
					SIGH = "Sigh",
					JOKE = "Silly",
					SLAP = "Slap",
					SMELL = "Smell",
					SMILE = "Smile",
					SMIRK = "Smirk",
					SNARL = "Snarl",
					SNICKER = "Snicker",
					SNIFF = "Sniff",
					SNUB = "Snub",
					SOOTHE = "Soothe",
					APOLOGIZE = "Sorry",
					SPIT = "Spit",
					STARE = "Stare",
					SURPRISED = "Surprised",
					TAP = "Tap",
					TAUNT = "Taunt",
					TEASE = "Tease",
					THANK = "Thank",
					THREATEN = "Threaten",
					TICKLE = "Tickle",
					TIRED = "Tired",
					VETO = "Veto",
					VICTORY = "Victory",
					VIOLIN = "Violin",
					WAVE = "Wave",
					WELCOME = "Welcome",
					WHINE = "Whine",
					WHISTLE = "Whistle",
					WINK = "Wink",
					WORK = "Work",
					YAWN = "Yawn",
					NOD = "Yes"
				},
				order = 26
				},
			dueltxtemote = {
				type = 'toggle',
				name = 'Show Custom Emote',
				desc = 'Toggle Emote Spam',
				get = function()
					return dgks.db.profile.dueltxtemote
				end,
				set = function(info, b)
					dgks.db.profile.dueltxtemote = b
				end,
				width = "full",
				order = 30
			},
			duelcustomemote = {
				type = 'input',
				name = 'Custom Emote Message',
				desc = "Use this to customize the emote message. $v = victim $s = streak",
				usage = "<message>",
				get = function()
					return dgks.db.profile.duelcustomemote
				end,
				set = function(info, b)
					dgks.db.profile.duelcustomemoteemote = b
				end,
				width = "full",
				order = 40
			},		
			dueltext = {
				type = 'input',
				name = 'Scrolling Text Message',
				desc = 'Use this to customize the Scrolling Text Message. $k = killer, $v = victim',
				usage = "<message>",
				get = function()
					return dgks.db.profile.dueltext
				end,
				set = function(info, b)
					dgks.db.profile.dueltext = b
				end,
				width = "full",
				order = 60
			},
		}
	}
	return duels 
end

local function giveRanks()
	local ranks = {
		type = "group",
		name = "Rank Tuning",
		desc = "0 is disabled",
		args = {
			ksrank1 = {
				type = 'range',
				name = 'KS Rank 1',
				desc = 'Number of kills to reach Rank 1',
				width = "full",
				get = function() return dgks.db.profile.ksrank[1] end,
				set = function(info, v) dgks.db.profile.ksrank[1] = v end,
				disabled = function() if (dgks.db.profile.style == "dota") then return false else return true end end,
				min = 1,
				max = 50,
				step = 1
			},
			ksrank2 = {
				type = 'range',
				name = 'KS Rank 2',
				desc = 'Number of kills to reach Rank 2',
				width = "full",
				get = function() return dgks.db.profile.ksrank[2] end,
				set = function(info, v) dgks.db.profile.ksrank[2] = v end,
				disabled = function() if (dgks.db.profile.style == "dota") then return false else return true end end,
				min = 0,
				max = 50,
				step = 1
			},
			ksrank3 = {
				type = 'range',
				name = 'KS Rank 3',
				desc = 'Number of kills to reach Rank 3',
				width = "full",
				get = function()
					return dgks.db.profile.ksrank[3]
				end,
				set = function(info, v)
					dgks.db.profile.ksrank[3] = v
				end,
				disabled = function() if (dgks.db.profile.style == "dota") then return false else return true end end,
				min = 0,
				max = 50,
				step = 1
			},
			ksrank4 = {
				type = 'range',
				name = 'KS Rank 4',
				desc = 'Number of kills to reach Rank 4',
				width = "full",
				get = function()
					return dgks.db.profile.ksrank[4]
				end,
				set = function(info, v)
					dgks.db.profile.ksrank[4] = v
				end,
				disabled = function() if (dgks.db.profile.style == "dota") then return false else return true end end,
				min = 0,
				max = 50,
				step = 1
			},
			ksrank5 = {
				type = 'range',
				name = 'KS Rank 5',
				desc = 'Number of kills to reach Rank 5',
				width = "full",
				get = function()
					return dgks.db.profile.ksrank[5]
				end,
				set = function(info, v)
					dgks.db.profile.ksrank[5] = v
				end,
				disabled = function() if (dgks.db.profile.style == "dota") then return false else return true end end,
				min = 0,
				max = 50,
				step = 1
			},
			ksrank6 = {
				type = 'range',
				name = 'KS Rank 6',
				desc = 'Number of kills to reach Rank 6',
				width = "full",
				get = function() return dgks.db.profile.ksrank[6] end,
				set = function(info, v)	dgks.db.profile.ksrank[6] = v end,
				disabled = function() if (dgks.db.profile.style == "dota") then return false else return true end end,
				min = 0,
				max = 50,
				step = 1
			},
			ksrank7 = {
				type = 'range',
				name = 'KS Rank 7',
				desc = 'Number of kills to reach Rank 7',
				width = "full",
				get = function() return dgks.db.profile.ksrank[7] end,
				set = function(info, v)	dgks.db.profile.ksrank[7] = v end,
				disabled = function() if (dgks.db.profile.style == "dota") then return false else return true end end,
				min = 0,
				max = 50,
				step = 1
			},
			utrank = {
				type = 'range',
				name = 'Unreal Tournament Multiplier',
				width = "double",
				desc = 'Number of kills between notifies, ex: 3 would play sounds at 3,9,12,...',
				get = function() return dgks.db.profile.utrank end,
				set = function(info, v) dgks.db.profile.utrank = v end,
				disabled = function() if (dgks.db.profile.style == "ut") then return false else return true end end,
				min = 1,
				max = 10,
				step = 1
			}
	
		}
	}
	return ranks
end

local function giveSoundFileSetup()
	local soundfilesetup = {
		type = "group",
		name = "Sound File Setup",
		desc = "For setting up custom sounds only",
		args = {
			resetkssound = {
				type = 'execute',
				width = "full",
				name = 'Reset to default files',
				func = function() dgks.db.profile.kssound = dgks.db.defaults.profile.kssound end,
			},
			kssound1 = {
				type = 'input',
				name = 'KS Sound 1',
				desc = 'Choose a sound file',
				usage = "End the name of a sound file",
				get = function()
					return dgks.db.profile.kssound[1]
				end,
				set = function(info, v)
					dgks.db.profile.kssound[1] = v
				end
			},
			kssound2 = {
				type = 'input',
				name = 'KS Sound 2',
			desc = 'Choose a sound file',
				usage = "End the name of a sound file",
				get = function()
				return dgks.db.profile.kssound[2]
					end,
				set = function(info, v)
					dgks.db.profile.kssound[2] = v
				end
				},
			kssound3 = {
				type = 'input',
				name = 'KS Sound 3',
				desc = 'Choose a sound file',
				usage = "End the name of a sound file",
				get = function()
					return dgks.db.profile.kssound[3]
				end,
				set = function(info, v)
					dgks.db.profile.kssound[3] = v
				end
			},
			kssound4 = {
				type = 'input',
				name = 'KS Sound 4',
				desc = 'Choose a sound file',
				usage = "End the name of a sound file",
				get = function()
					return dgks.db.profile.kssound[4]
				end,
				set = function(info, v)
					dgks.db.profile.kssound[4] = v
				end
			},
			kssound5 = {
				type = 'input',
				name = 'KS Sound 5',
				desc = 'Choose a sound file',
				usage = "End the name of a sound file",
				get = function()
					return dgks.db.profile.kssound[5]
				end,
				set = function(info, v)
					dgks.db.profile.kssound[5] = v
				end
			},
			kssound6 = {
				type = 'input',
				name = 'KS Sound 6',
				desc = 'Choose a sound file',
				usage = "End the name of a sound file",
				get = function()
					return dgks.db.profile.kssound[6]
				end,
				set = function(info, v)
					dgks.db.profile.kssound[6] = v
				end
			},
			kssound7 = {
				type = 'input',
				name = 'KS Sound 7',
				desc = 'Choose a sound file',
				usage = "End the name of a sound file",
				get = function()
					return dgks.db.profile.kssound[7]
				end,
				set = function(info, v)
					dgks.db.profile.kssound[7] = v
				end
			},
			prepare = {
				type = 'input',
				name = 'Prepare Sound',
				desc = 'Choose a sound file',
				usage = "Enter the name of the sound file",
				get = function()
					return dgks.db.profile.kssoundP
				end,
				set = function(info, v)
					dgks.db.profile.kssoundP = v
				end
			},
			executesound = {
				type = 'input',
				name = 'Execute Sound',
				desc = 'Choose a sound file',
				usage = "Enter the name of the sound file",
				get = function()
					return dgks.db.profile.kssoundE
				end,
				set = function(info, v)
					dgks.db.profile.kssoundE = v
				end
			}
		}
	}
	return soundfilesetup
end

local function giveOutput()
	local output = {
		name = "Combat Message Output",
		type = "group",
		args = {
			desc = {
				type = "description",
				name = "You can select where you want dG Killshot Combat messages displayed from this screen.",
				order = 0
			},
			sink = dgks:GetSinkAce3OptionsDataTable(),
		}
	}
	-- hacks borrowed from Witch Hunt
	output.args.sink.order = 1
	output.args.sink.inline = true
	--output.args.sink.name = ""
	return output
end

local defaults = {
	profile = {
		configversion = newestconfigversion,
		maxstreak = 0,
		maxdeathstreak = 0,
		ksemote = "has killed $v! Streak of $s!",
		dueltxtemote = false,
		duelcustomemote = "has defended his honor against $v! Streak of $s!",
		kstext = "$k killed $v!",
		dueltext = "$k has defeated $v!",
		soundpack = "male",
		soundpath = soundPath,
		dotxtemote = false,
		doemote = "none",
		duelemotewin = "BOW",
		duelemoteloss = "BOW",
		duelhumiliation = true,
		doscreenshotonkill = false,
		doscreenshotonstreak = false,
		doscreenshotonmultikill = false,
		doscreenshotonduelwin = false,
		doscreenshotonduelloss = false,
		doscreenshotondeath = false,
		--dopet = false,
		style = "dota",
		docombattext = true,
		dobroadcasts = true,
		doguild = true,
		dobg = true,
		doraid = true,
		dofriends = true,
		dosound = true,
		soundchannel = "Master",
		dopve = false,
		dozonechange = true,
		dopreparesound = false,
		doexecutesound = false,
		doexecutesoundpve = false,
		doexecutepercent = 25,
		dochatbox = true,
		utrank = 3,
		ksrank = {1, 2, 4, 6, 8, 10, 12},
		kssound = {"ownage.ogg", "killingspree.ogg", "rampage.ogg", "dominating.ogg", "unstoppable.ogg", "godlike.ogg", "whickedsick.ogg"},
		kssoundM = {"doublekill.ogg", "multikill.ogg", "megakill.ogg", "ultrakill.ogg", "monsterkill.ogg", "ludicrouskill.ogg", "holyshit.ogg"},
		kssoundP = "prepare.ogg",
		kssoundE = "finishhim.ogg",
		kstextM = {"DOUBLEKILL!", "MULTIKILL!", "MEGAKILL!", "ULTRAKILL!!!", "MONSTERKILL!!!", "LUDICROUSKILL!!!", "H O L Y  S H I T!!!"},
		killlog = {},
		damageDealers = {},
		killList = {},
		deathList = {},
		kssoundH = "humiliation.ogg",	
		sink20Sticky = true,
		sink20OutputSink = "Default",
		sink20ScrollArea = "Outgoing",
	},
}

function dgks:OnInitialize()

	-- Setup DB
	self.db = LibStub("AceDB-3.0"):New("dgksDB", defaults, "Default")

	-- Increment newestconfigversion to reset db to defaults when needed
	self:SetSinkStorage(self.db.profile)
	if (dgks.db.profile.configversion < newestconfigversion ) then
		dgks:Print("Config outdated, reverting to defaults.")
		dgks.db:ResetProfile()
	end
	
	-- Setup Config Screens
	local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

	AceConfigRegistry:RegisterOptionsTable("dG KillShot", giveOptions)
	AceConfigRegistry:RegisterOptionsTable("dG KillShot General", giveGeneral)
	AceConfigRegistry:RegisterOptionsTable("dG KillShot Broadcasts", giveBroadcasts)
	AceConfigRegistry:RegisterOptionsTable("dG KillShot Screenshots", giveScreenshots)
	AceConfigRegistry:RegisterOptionsTable("dG KillShot Duels", giveDuels)
	AceConfigRegistry:RegisterOptionsTable("dG KillShot Ranks", giveRanks)
	AceConfigRegistry:RegisterOptionsTable("dG KillShot File Setup", giveSoundFileSetup)
	AceConfigRegistry:RegisterOptionsTable("dG KillShot Output", giveOutput)	
	
	local AceConfigDialog = LibStub("AceConfigDialog-3.0")
	
	AceConfigDialog:AddToBlizOptions("dG KillShot", "dG KillShot")
	AceConfigDialog:AddToBlizOptions("dG KillShot General", "General", "dG KillShot")
	AceConfigDialog:AddToBlizOptions("dG KillShot Broadcasts", "Broadcasts", "dG KillShot")
	AceConfigDialog:AddToBlizOptions("dG KillShot Screenshots", "Screenshots", "dG KillShot")
	AceConfigDialog:AddToBlizOptions("dG KillShot Duels", "Duels", "dG KillShot")
	AceConfigDialog:AddToBlizOptions("dG KillShot Ranks", "Ranks", "dG KillShot")
	-- Clean up UI
	-- AceConfigDialog:AddToBlizOptions("dG KillShot File Setup", "Sound File Setup", "dG KillShot")
	AceConfigDialog:AddToBlizOptions("dG KillShot Output", "Combat Text Output", "dG KillShot")
    

	-- Setup slash commands
	-- The triple call fixes bug that doesn't open on first run and expans the sub pages
	self:RegisterChatCommand("dgks", function() InterfaceOptionsFrame_OpenToCategory("dG KillShot") InterfaceOptionsFrame_OpenToCategory("General") InterfaceOptionsFrame_OpenToCategory("dG KillShot") end)
	self:RegisterChatCommand("ks", function() InterfaceOptionsFrame_OpenToCategory("dG KillShot") InterfaceOptionsFrame_OpenToCategory("General") InterfaceOptionsFrame_OpenToCategory("dG KillShot") end)
	
	
	-- Setup Comms
	self:RegisterComm("dgks") --Killshots
	self:RegisterComm("dgksV") --Version check
	self:RegisterComm("dgksVR") --Version check responses
	self:RegisterComm("dgksDUEL") --Duels
end

function dgks:SoundEventHandler(info, sound)
	if (dgks.db.profile.dosound) then
		if (tonumber(GetCVar("Sound_EnableAllSound") and GetCVar("Sound_EnableSFX")) == 1) then
			PlaySoundFile(sound,dgks.db.profile.soundchannel)
		end
	end
end

function dgks:OnDisable()
    -- Called when the addon is disabled
end

function dgks:CombatLogEventHandler(info, timestamp, event, hideCaster, sourceGUID, sourceName, sourceFlags, sourceFlags2, destGUID, destName, destFlags, destFlags2, ...)
	
	-- Example of player kill
	-- 7/21 01:23:16.879  PARTY_KILL,Player-9-00064F35,"Ratchet-Kil'jaeden",0x511,0x0,Player-3676-09BED6E0,"Kruulmokthan-Area52",0x10548,0x0
	-- 7/21 01:23:16.879  SPELL_DAMAGE,Player-9-00064F35,"Ratchet-Kil'jaeden",0x511,0x0,Player-3676-09BED6E0,"Kruulmokthan-Area52",0x10548,0x0,585,"Smite",0x2,0000000000000000,0000000000000000,0,0,0,0,0,-1,0,0,0,0.00,0.00,628,0.0000,0,930,969,249,2,0,0,0,nil,nil,nil
    -- 7/21 01:23:16.879  UNIT_DIED,0000000000000000,nil,0x80000000,0x80000000,Player-3676-09BED6E0,"Kruulmokthan-Area52",0x10548,0x0
	
	-- FIXME Use party_kill for all kills by player, use unit_died for owned pets only
	-- Remove Party Kill to test damageDealers table This maybe required to detect Feign Death
	if event == "PARTY_KILL" then
		if (destFlags == nil) then return end
		if (bit.band(destFlags, COMBATLOG_OBJECT_TYPE_PLAYER) == COMBATLOG_OBJECT_TYPE_PLAYER) or dgks.db.profile.dopve then
			-- A unit has died to someone in our party
				
			if sourceGUID == UnitGUID("player") then
							
				--@debug@
				-- Dev Debugging functions
				self.Print("DEBUG: " .. UnitName("player") .. " has landed the kill.")
				self.Print("DEBUG: " .. "Sending "..destName.." and "..timestamp.." to KillshotTX." )
				--@end-debug@
				
				-- The player has landed a killshot
				self:KillshotTX(destName, timestamp)
			end
		end
	end
	-- Check for player death by pet
	-- FIXME limit this to pet kills only
	if event == "UNIT_DIED" then
		if destName == playerName then
			-- Player has died
			local myKiller = damageDealers[destName]			
			self:PlayerDeath(myKiller)
			-- Test is probably broken
		elseif bit.band(destFlags, COMBATLOG_OBJECT_TYPE_PLAYER) == COMBATLOG_OBJECT_TYPE_PLAYER or dgks.db.profile.dopve or destName == "Test-Victim" then
				if damageDealers[destName] == "PlayerPet" then
				-- Last damage dealt to dead unit was from player
				--@debug@
				-- Dev Debugging functions
				self:Print("DEBUG: " .. UnitName("player") .. " has landed the kill.")
				self:Print("DEBUG: " .. "Sending "..destName.." and "..timestamp.." to KillshotTX." )
				--@end-debug@
				-- The player has landed a killshot,this detection method is fooled by Feign Death so we do PARTY_KILL ALSO
				self:KillshotTX(destName, timestamp)
			end
		end
	end
	
	-- Record last damage source for pet kill and player death tracking
	if string.find(event, "_DAMAGE") then
		-- This should log pets and creatures under players control to the player
		-- This worked, but we need to superate pets -- if sourceName ~= playerName and bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) > 0 then sourceName = playerName end
		if sourceName ~= playerName and bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) > 0 then sourceName = "PlayerPet" end
		damageDealers[destName] = sourceName
		
		-- Check for execute if enabled
		if dgks.db.profile.doexecutesound or dgks.db.profile.doexecutesoundpve then
		--Only do execute if we have a target and they are hostile 
			if GetUnitName("target", true) == destName then
				-- This _DAMAGE event is for out target
				if UnitIsEnemy("player","target") then 
					-- This is an enemy
					if bit.band(destFlags, COMBATLOG_OBJECT_TYPE_PLAYER) == COMBATLOG_OBJECT_TYPE_PLAYER or dgks.db.profile.doexecutesoundpve then
						-- dest is a player or pve is enabled
						local targetHealthPercent = floor(UnitHealth("target") / UnitHealthMax("target") * 100,0)
						if targetHealthPercent <= dgks.db.profile.doexecutepercent and targetHealthPercent > 1 then
							-- Target is under threshold
							--@debug@
							-- Dev Debugging functions
							--dgks:Print("DEBUG: " .. GetUnitName("target",true) .. " " .. destName .. " " .. targetHealthPercent)
							--@end-debug@
							if targetList[GetUnitName("target",true)] == nil then
								--First time we have seen this target in execute range
								dgks:dgks_SoundPack(dgks.db.profile.kssoundE)
							elseif targetList[GetUnitName("target",true)] <= dgks.db.profile.doexecutepercent then
								--Target was already under threshold don't spam
							else
								-- Target is now below threshhold play sound
								dgks:dgks_SoundPack(dgks.db.profile.kssoundE)
							end
						end
						--Store target health in table so we can filter repeat executes
						targetList[GetUnitName("target",true)] = targetHealthPercent
						--dgks:Print(targetList[GetUnitName("target",true)])
					end
				end
			end
		end
	end 
end

function dgks:KillshotTX(txvictim,txtimestamp)
	-- Process the detect killshot
	-- Increment killshot streak 
	streak = streak + 1
	-- Check and set multikill
	if (lastkill + 10) > txtimestamp then
		-- Ladies and Gentlemen we have a multikill
		multikill = multikill + 1;
		-- This most like will never be used except in test mode, but lets prevent the error anyways
		if (multikill > table.maxn(self.db.profile.kstextM)) then multikill = table.maxn(self.db.profile.kstextM) end
	else
		multikill =  0 
	end
	
	-- New Multikill timer
	lastkill = txtimestamp
	
	-- Reset deathstreak
	deathstreak = 0
	
	-- Broadcast our Killshot
	self:SendCM("dgks",dgks:Serialize(playerName,txvictim,txtimestamp,streak,multikill))
	
end

function dgks:DuelTX(txvictim,txtimestamp)
	-- Process the detect killshot
	-- Increment killshot streak 
	streak = streak + 1
	
	-- Reset deathstreak
	deathstreak = 0
	
	-- Broadcast our duel win
	self:SendCM("dgksDUEL",dgks:Serialize(playerName,txvictim,txtimestamp,streak,multikill))
end

function dgks:PlayerLoss(myKiller)
	streak = 0;
	deathstreak = deathstreak + 1;
	if (deathstreak > dgks.db.profile.maxdeathstreak) then dgks.db.profile.maxdeathstreak = deathstreak end
	if (myKiller == nil) then myKiller = "Unknown Entity" end
	-- Add to log
    tinsert(dgks.db.profile.killlog, 1, "[" .. date() .. "]" .. " You were defeated by " .. myKiller .. ".")
	-- If log is too long prune it
    if (dgks.db.profile.killlog[21]) then tremove(dgks.db.profile.killlog,21) end
	-- Store in deathList
	-- If deathList doesn't exist create it
	if not dgks.db.profile.deathList[myKiller] then dgks.db.profile.deathList[myKiller] = {} end
	tinsert(dgks.db.profile.deathList[myKiller], date("%m/%d/%y %H:%M:%S"))
	if (dgks.db.profile.dochatbox) then dgks:Print("You been defeated by "..myKiller.." "..#dgks.db.profile.deathList[myKiller].." times.") end
	if dgks.db.profile.doscreenshotonduelloss then Screenshot() end
	if dgks.db.profile.duelemoteloss ~= "none" then
		DoEmote(dgks.db.profile.duelemoteloss, myKiller)
	end
end

function dgks:OnCommReceived(cchan, message, distribution, sender)
	
	--If broadcast type is off return
	if not dgks.db.profile.dobroadcasts and distribution == "YELL" then return end 	
	-- If Guild broadcast is off and we received a guild broadcast just return
	if not dgks.db.profile.doguild and distribution == "GUILD" then return end
	-- If raid broadcast is off and we received a raid broadcast just return
	if not dgks.db.profile.doraid and distribution == "RAID" then return end
	if not dgks.db.profile.doraid and distribution == "PARTY" then return end
	if not dgks.db.profile.doraid and distribution == "INSTANCE_CHAT" then return end

	local timestamp = time()
	
	--Process non-serialized cchan
	--@debug@
	self:Print("OnCommReceived: CChan= " .. cchan .. " " .. message .. distribution .. sender)
	--@end-debug@
	if cchan == "dgksVR" then
		if sender ~= playerName then self:Print(sender .. " is on version " .. message) end
	
	elseif cchan == "dgksV" then
		-- Check for duplicates here
		if sender == lastSender and message == lastMessage and timestamp == lastTimestamp then return end
		-- Respond with our version
		self:Print(sender .. " is on version " .. message)
		--FIXME Should this use SendCM function?
		--C_ChatInfo.SendAddonMessage("dgksVR", version, WHISPER, sender)
		--This should always be a direct whisper
		self:SendCommMessage("dgksVR",version,WHISPER,sender)
	
	elseif cchan == "dgks" or "dgksDUEL" then
		--Verify we have a valid event	
		local ok,rxkiller,rxvictim,rxtimestamp,rxstreak,rxmultikill = dgks:Deserialize(message)
		if not ok then return else
		
			-- Check for duplicates here
			if rxkiller == lastrxkiller and rxvictim == lastrxvictim and rxtimestamp == lastrxtimestamp then return	end
			-- Set duplicate prevention variables
			lastrxkiller, lastrxvictim, lastrxtimestamp = rxkiller, rxvictim, rxtimestamp
		
			-- Generate Text
			if cchan == "dgks" then 
				killshottext = string.gsub(string.gsub(dgks.db.profile.kstext, "$k", rxkiller), "$v", rxvictim)
				-- Killshot Emotes
				if (dgks.db.profile.dotxtemote and playerName == rxkiller) then
					emotestring=string.gsub(string.gsub(dgks.db.profile.ksemote, "$v", rxvictim), "$s", streak)
					SendChatMessage(emotestring, "EMOTE")
				end
				if (dgks.db.profile.doemote ~= "none" and playerName == rxkiller) then
					-- fixme targeting doesn't seem to work with NPCs
					DoEmote(dgks.db.profile.doemote, rxvictim)
				end
			else
				killshottext = string.gsub(string.gsub(dgks.db.profile.dueltext, "$k", rxkiller), "$v", rxvictim)
				--Duel Emotes
				if (dgks.db.profile.dueltxtemote and playerName == rxkiller) then
					emotestring=string.gsub(string.gsub(dgks.db.profile.duelcustomemote, "$v", rxvictim), "$s", streak)
					SendChatMessage(emotestring, "EMOTE")
				end
				if (dgks.db.profile.duelemotewin ~= "none" and playerName == rxkiller) then
					-- fixme targeting doesn't seem to work with NPCs
					DoEmote(dgks.db.profile.duelemotewin, rxvictim)
				end
			end
			
			-- Send to sink for local output
			self:ScrollText(killshottext)
			
			-- Process multikill and play appropiate sound and text
			if rxmultikill > 0 then
				self:ScrollText(rxkiller .. " got a " .. self.db.profile.kstextM[rxmultikill] .. "!")
				self:dgks_SoundPack(self.db.profile.kssoundM[rxmultikill])
			else
				self:dgks_SoundPack(dgks:GetKillshotSound(rxstreak))
			end

			-- We have landed a kill
			if playerName == rxkiller then
				local setMaxStreak = false
				
				-- Increment maxstreak if this is a record high
				if ( streak > dgks.db.profile.maxstreak ) then 
					dgks.db.profile.maxstreak = streak
					setMaxStreak = true
				end
						
				-- This now triggers a global cool and most likely cannot work anymore
				-- if dgks.db.profile.dopet then C_PetJournal.SummonRandomPet(allPets) end
				
				if dgks.db.profile.doscreenshotonkill then Screenshot()
				elseif dgks.db.profile.doscreenshotonstreak and setMaxStreak then Screenshot()
				elseif dgks.db.profile.doscreenshotonmultikill and rxmultikill > 0 then Screenshot() end
				
				-- Store in killList
				if not dgks.db.profile.killList[rxvictim] then dgks.db.profile.killList[rxvictim] = {} end
				tinsert(dgks.db.profile.killList[rxvictim], date("%m/%d/%y %H:%M:%S"))
				--fixme this count my be inaccurate due to the way lua handles tables without numeric index
				if (dgks.db.profile.dochatbox) then dgks:Print("You have killed "..rxvictim.." "..#dgks.db.profile.killList[rxvictim].." times.") end
			end
		end
	end

	--Set duplicate prevention variables
	lastMessage, lastSender, lastTimestamp = message, sender, timestamp

end

function dgks:PlayerDeath(myKiller)
	streak = 0;
	deathstreak = deathstreak + 1;
	if (deathstreak > dgks.db.profile.maxdeathstreak) then dgks.db.profile.maxdeathstreak = deathstreak end
	if (myKiller == nil) then myKiller = "Unknown Entity" end
	-- Add to log
    tinsert(dgks.db.profile.killlog, 1, "[" .. date() .. "]" .. " You were killed by " .. myKiller .. ".")
	-- If log is too long prune it
    if (dgks.db.profile.killlog[21]) then tremove(dgks.db.profile.killlog,21) end
	-- Store in deathList
	-- If deathList doesn't exist create it
	if not dgks.db.profile.deathList[myKiller] then dgks.db.profile.deathList[myKiller] = {} end
	tinsert(dgks.db.profile.deathList[myKiller], date("%m/%d/%y %H:%M:%S"))
	if (dgks.db.profile.dochatbox) then dgks:Print("You been murdered by "..myKiller.." "..#dgks.db.profile.deathList[myKiller].." times.") end
	if dgks.db.profile.doscreenshotondeath then Screenshot() end
end

function dgks:GetKillshotSound(streak)
	if (dgks.db.profile.style == "dota") then
		-- DoTA Style
		for x = 7, 0, -1 do
			if (dgks.db.profile.ksrank[x] > 0) and (streak >= dgks.db.profile.ksrank[x]) then return dgks.db.profile.kssound[x]; end
		end
	else
		-- UT Style
		if (streak == 1) then return dgks.db.profile.kssound[1]; end
		if (streak %  dgks.db.profile.utrank == 0) then 
			local uttmp = streak / dgks.db.profile.utrank
			if (uttmp > 7) then
				return dgks.db.profile.kssound[7]
			else
				return dgks.db.profile.kssound[uttmp]
			end
		else
			return
		end
	end
    --If we get here the user has messed up their config we could build some sort of safety someday but for now we will just default to kssound1 FIXME
	return dgks.db.profile.kssound[1];
end

function dgks:ScrollText(msg)
	
	tinsert(dgks.db.profile.killlog, 1, "[" .. date() .. "] " .. msg)
	if (dgks.db.profile.killlog[21]) then tremove(dgks.db.profile.killlog,21) end
	
	if (dgks.db.profile.docombattext) then
		--if (GetCVar("enableFloatingCombatText") == "0") then
		--	dgks:Print("Setting Combat Scrolling Text for Self to enabled. Please /reload your UI or restart client.")
		--	SetCVar("enableFloatingCombatText", 1)
		--end
		dgks:Pour(msg, 1.0, 0.1, 0.1)
		
	end
end

-- FIXME Entire version checking needs cleanup for duplicate sends
function dgks:VersionCheck()
    self:SendCM("dgksV",version)
end

function dgks:dgks_SoundPack(sound)
	-- FIXME	
	if not sound then sound = 1 end
    local soundfile = self.db.profile.soundpath .. sound
    dgks:SoundEventHandler(info, soundfile)
end

function dgks:getSoundPack()
    return self.db.profile.soundpack;
end

function dgks:setSoundPack(info, newsoundset)
    if (newsoundset == "male") then
        self.db.profile.soundpack = newsoundset
        self.db.profile.soundpath = soundPath
    elseif (newsoundset == "female") then
		self.db.profile.soundpack = newsoundset
		self.db.profile.soundpath = soundPath .. "\\female\\"
    elseif (newsoundset == "sexy") then
		self.db.profile.soundpack = newsoundset
		self.db.profile.soundpath = soundPath .. "\\sexy\\"
    elseif (newsoundset == "baby") then
		self.db.profile.soundpack = newsoundset
		self.db.profile.soundpath = soundPath .. "\\baby\\"
    else
        message("Error: That is not a valid option")
    end
end

function dgks:getKillLog()
	local plog = ""
	table.foreach(dgks.db.profile.killlog, function(k,v) plog = plog .. v .. "\n" end)
	return plog
end

function dgks:SendCM(cchan,msg)
	-- Example usage: self:SendCM("dgksDUEL",dgks:Serialize(playerName,txvictim,txtimestamp,streak,multikill)

	-- Whisper to ourselves if broadcasts are off or guild is off or we are not in a guild
	if not dgks.db.profile.dobroadcasts or not dgks.db.profile.doguild or not IsInGuild() then
		--@debug@
		self:Print("Sending: CChan= " .. cchan .. " " .. msg .. " to WHISPER self")
		--@end-debug@
		self:SendCommMessage(cchan,msg,"WHISPER",playerName)
	end

	if dgks.db.profile.dobroadcasts then

		-- If not Retail, send to yell
		-- https://wowpedia.fandom.com/wiki/WOW_PROJECT_ID
		if WOW_PROJECT_ID ~= 1 then
			self:SendCommMessage(cchan,msg,"YELL")
			--@debug@
			self:Print("Sending: CChan= " .. cchan .. " " .. msg .. " to YELL")
			--@end-debug@

		end

		if dgks.db.profile.doguild and IsInGuild() then
			self:SendCommMessage(cchan,msg,"GUILD")
			--@debug@
			self:Print("Sending: CChan= " .. cchan .. " " .. msg .. " to GUILD")
			--@end-debug@

		end

		-- Send to Battleground / Arena	
		if dgks.db.profile.dobg then
			if inBG or inArena then 
				--@debug@
				self:Print("Sending: BG CChan= " .. cchan .. " " .. msg .. " to INSTANCE_CHAT")
				--@end-debug@
				self:SendCommMessage(cchan,msg,"INSTANCE_CHAT")
			end
		end

		-- Send to Raid
		-- LFG style parties and raids use INSTANCE_CHAT
		if dgks.db.profile.doraid then
			-- Raid/Party Broadcast on

			--Standard Raid
			if IsInRaid(LE_PARTY_CATEGORY_HOME) and not inArena and not inBG then
				--@debug@
				self:Print("Sending: CChan= " .. cchan .. " " .. msg .. " to RAID")
				--@end-debug@
				self:SendCommMessage(cchan,msg,"RAID") 
			end

				-- LFG or Group Finder Raid
			if IsInRaid(LE_PARTY_CATEGORY_INSTANCE) and not inArena and not inBG then
				--@debug@
				self:Print("Sending: RAID CChan= " .. cchan .. " " .. msg .. " to INSTANCE_CHAT")
				--@end-debug@
				self:SendCommMessage(cchan,msg,"INSTANCE_CHAT")
			end

			if UnitInParty("player") and not inArena and not inBG then
				self:SendCommMessage(cchan,msg,"PARTY")
				--@debug@
				self:Print("Sending: CChan= " .. cchan .. " " .. msg .. " to PARTY")
				--@end-debug@

			end
		end

		--Whisper to friends
		if dgks.db.profile.dofriends then
			for i = 1, C_FriendList.GetNumFriends() do
				local info = C_FriendList.GetFriendInfoByIndex(i)
				if info and info.connected then
					self:SendCommMessage(cchan,msg,"WHISPER",info.name)
					--@debug@
					self:Print("Sending: CChan= " .. cchan .. " " .. msg .. " to WHISPER " .. " Name: " .. info.name)
					--@end-debug@
					--C_ChatInfo.SendAddonMessage(prefix, message, "WHISPER", info.name)
				end
			end
			--Battle.net friends

			--@debug@
			--for i = 1, BNGetNumFriends() do
			--	for j = 1, C_BattleNet.GetFriendNumGameAccounts(i) do
			--		local game = C_BattleNet.GetFriendGameAccountInfo(i, j)
			--		if game.isOnline and game.factionName then
			--			print(game.gameAccountID, game.isOnline, game.factionName, UnitFactionGroup("player"), game.realmName, GetRealmName())
			--		end
			--	end
			--end
			--@end-debug@

			local totalBFriends, onlineBFriends = BNGetNumFriends()
			for i = 1, onlineBFriends  do
				for j = 1, C_BattleNet.GetFriendNumGameAccounts(i) do
					local game = C_BattleNet.GetFriendGameAccountInfo(i, j)
					if game.characterName == nil or game.realmName == nil or game.factionName == nil then
						break
					end
							--@debug@
							self:Print("BNET: " .. j .. "Name: " .. game.characterName .. "Realm: " .. game.realmName .. GetRealmName())
							--@end-debug@
					--if game.realmName == GetRealmName() and game.factionName == UnitFactionGroup("player") then
					if game.factionName == UnitFactionGroup("player") then
						self:SendCommMessage(cchan,msg,"WHISPER",game.characterName)
						
						--@debug@
						self:Print("Sending: CChan= " .. cchan .. " " .. msg .. " to WHISPER " .. game.characterName)
						--@end-debug@
						--C_ChatInfo.SendAddonMessage(prefix, message, "WHISPER", info.name)
					end
				end
			end
		end
	end
end

--@debug@
-- Dev Debugging functions
function dgks:Test()
	-- Dev Debugging functions
	self:Print("DEBUG: " .. "Sending KillShot Event...")
	-- Example combat log entries
	-- Old 12/6 10:49:47.392  UNIT_DIED,0x0000000000000000,nil,0x80000000,0x80000000,0x0300000007362B6E,"Vvatsitchy-Caelestrasz",0x512,0x0
	-- Old 12/6 10:51:35.342  PARTY_KILL,0x0300000000064F35,"Ratchet",0x511,0x0,0xF130388200000029,"Horde Battle Standard",0x2148,0x0
	-- 9/12 20:28:09.501  PARTY_KILL,Player-9-00064F35,"Ratchet-Kil'jaeden",0x511,0x0,Player-9-0A43E636,"Liinx-Kil'jaeden",0x10548,0x0
	-- 7/21 01:23:16.879  PARTY_KILL,Player-9-00064F35,"Ratchet-Kil'jaeden",0x511,0x0,Player-3676-09BED6E0,"Kruulmokthan-Area52",0x10548,0x0
	-- 7/21 01:23:16.879  SPELL_DAMAGE,Player-9-00064F35,"Ratchet-Kil'jaeden",0x511,0x0,Player-3676-09BED6E0,"Kruulmokthan-Area52",0x10548,0x0,585,"Smite",0x2,0000000000000000,0000000000000000,0,0,0,0,0,-1,0,0,0,0.00,0.00,628,0.0000,0,930,969,249,2,0,0,0,nil,nil,nil
    -- 7/21 01:23:16.879  UNIT_DIED,0000000000000000,nil,0x80000000,0x80000000,Player-3676-09BED6E0,"Kruulmokthan-Area52",0x10548,0x0
	self:CombatLogEventHandler(info,GetTime(),"PARTY_KILL",false,"Player-9-00064F35","Ratchet-Kil'jaeden",0x511,0x0,"Player-3676-09BED6E0","Test-Victim",0x10548,0x0)
	self:CombatLogEventHandler(info,GetTime(),"SPELL_DAMAGE",false,"Player-9-00064F35","Ratchet-Kil'jaeden",0x511,0x0,"Player-3676-09BED6E0","Test-Victim",0x10548,0x0,585,"Smite",0x2,0000000000000000,0000000000000000,0,0,0,0,0,-1,0,0,0,0.00,0.00,628,0.0000,0,930,969,249,2,0,0,0,nil,nil,nil)
	self:CombatLogEventHandler(info,GetTime(),"UNIT_DIED",false,0000000000000000,nil,0x80000000,0x80000000,"Player-3676-09BED6E0","Test-Victim",0x10548,0x0)
end

function dgks:TestPlayerDeath()
	-- Example from combat log
	-- Old 12/6 10:50:47.727  RANGE_DAMAGE,0x0300000006B14637,"Kumonu-Ner'zhul",0x10548,0x0,0x0300000000064F35,"Ratchet",0x511,0x0,75,"Auto Shot",0x1,10990,-1,1,0,0,0,nil,nil,nil
	-- Old 12/6 10:50:48.308  UNIT_DIED,0x0000000000000000,nil,0x80000000,0x80000000,0x0300000000064F35,"Ratchet",0x511,0x0
	-- 07202018 7/21 00:34:33.944  SPELL_PERIODIC_DAMAGE,Player-11-0A947E83,"Invictusgg-Tichondrius",0x548,0x0,Player-9-00064F35,"Ratchet-Kil'jaeden",0x511,0x0,198097,"Creeping Venom",0x8,0000000000000000,0000000000000000,0,0,0,0,0,-1,0,0,0,0.00,0.00,92,0.0000,0,116,134,97,8,0,0,0,nil,nil,nil
	-- 07202018 7/21 00:34:33.944  UNIT_DIED,0000000000000000,nil,0x80000000,0x80000000,Player-9-00064F35,"Ratchet-Kil'jaeden",0x511,0x0
	self:Print("DEBUG: " .. "Sending Player Death Event...")
	self:CombatLogEventHandler(info,GetTime(),"RANGE_DAMAGE",false,0x030000000086920F,"KillerName",0x548,0x0,UnitGUID("Player"),playerName,0x511,50622,"Auto Shot",0x1,10990,-1,1,0,0,0,nil,nil,nil)
	self:CombatLogEventHandler(info,GetTime(),"UNIT_DIED",false,0x0000000000000000,nil,0x80000000,0x80000000,UnitGUID("Player"),playerName,0x511,0x0)
end
--@end-debug@

function events:COMBAT_LOG_EVENT_UNFILTERED(info, event, ...)
	local timestamp, event, hideCaster, sourceGUID, sourceName, sourceFlags, sourceFlags2, destGUID, destName, destFlags, destFlags2 = CombatLogGetCurrentEventInfo()
	dgks:CombatLogEventHandler(info, timestamp, event, hideCaster, sourceGUID, sourceName, sourceFlags, sourceFlags2, destGUID, destName, destFlags, destFlags2, ...)
end

function events:ZONE_CHANGED_NEW_AREA(info, event, ...)
	
	if (dgks.db.profile.dozonechange) then
		streak = 0
		deathstreak = 0
	end

	-- Check for Arena and Battleground
	if IsActiveBattlefieldArena() ~=nil then inArena = true else inArena = false end
	if UnitInBattleground("Player") ~= nil then inBG = true else inBG = false end

	--if (dgks.db.profile.dopreparesound) then
		--local junk
		--junk, inbg = IsInInstance()
		--if inbg == "pvp" or IsActiveBattlefieldArena() then
			--fixme dgks:dgks_SoundPack(dgks.db.profile.kssoundP)
		--end
	--end
end

function events:CHAT_MSG_BG_SYSTEM_NEUTRAL(msg, ...)
	-- Prepare for Battleground
	if (dgks.db.profile.dopreparesound) then
		if msg == "The battle begins in 30 seconds!" then dgks:dgks_SoundPack(dgks.db.profile.kssoundP) end
	end
end

function events:CHAT_MSG_SYSTEM(msg, ...)
	-- Prepare for Duel
	if (dgks.db.profile.dopreparesound) then
		if msg == format(DUEL_COUNTDOWN,3) then dgks:dgks_SoundPack(dgks.db.profile.kssoundP) end
	end
	-- Player fled from Duel
	if strmatch(msg, format(DUEL_WINNER_RETREAT, "(.-%--.-)", playerName)) then
		if dgks.db.profile.duelhumiliation then dgks:dgks_SoundPack(dgks.db.profile.kssoundH) end
		opponent = strmatch(msg, format(DUEL_WINNER_RETREAT, "(.-%--.-)", playerName))
		self:PlayerLoss(opponent)
	--fixme should probably create new msgs for duels in the future
	-- Opponent fled from Duel
	elseif strmatch(msg, format(DUEL_WINNER_RETREAT, playerName, "(.-%--.-)")) then
		opponent = strmatch(msg, format(DUEL_WINNER_RETREAT, playerName, "(.-%--.-)"))
		dgks:DuelTX(opponent,GetTime())
	-- Won Duel
	elseif strmatch(msg, format(DUEL_WINNER_KNOCKOUT, playerName, "(.-%--.-)")) then
		opponent = strmatch(msg, format(DUEL_WINNER_KNOCKOUT, playerName, "(.-%--.-)"))
		dgks:DuelTX(opponent,GetTime())
	-- Lost Duel
	elseif strmatch(msg, format(DUEL_WINNER_KNOCKOUT, "(.-%--.-)", playerName)) then
		opponent = strmatch(msg, format(DUEL_WINNER_KNOCKOUT, "(.-%--.-)", playerName))
		dgks:PlayerLoss(opponent,GetTime())
	else
		--@debug@
		-- Dev Debugging functions
		--dgks:Print("DEBUG: " .. msg)
		--@end-debug@
	end
end

function dgks:OnEnable()
	--self:RegisterEvent("CHAT_MSG_ADDON", "AddonMessageHandler")
	--OnEvent runs the function events:event
	frame:SetScript("OnEvent", function(self, event, ...)
		events[event](self,...);
	end);
	--Regeister all events with function events:event
	for k, v in pairs(events) do
		frame:RegisterEvent(k);
	end
	--self:SetSinkStorage(self.db.profile)
	--Check if this is dgks_classic, if so print warning and set path correctly
	if (addonName == "dgks_classic") then
		SendSystemMessage("Please switch to dG Killshot, the classic specific version, dG Killshot Classic, is no longer getting updates.")
		soundPath = "Interface\\AddOns\\dgks_classic\\sounds\\"
	end

end

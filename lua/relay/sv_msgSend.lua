require("chttp")

local tmpAvatars = {}
-- for bots
tmpAvatars['0'] = 'https://avatars.cloudflare.steamstatic.com/fef49e7fa7e1997310d705b2a6158ff8dc1cdfeb_full.jpg'

local IsValid = IsValid
local util_TableToJSON = util.TableToJSON
local util_SteamIDTo64 = util.SteamIDTo64
local http_Fetch = http.Fetch
local coroutine_resume = coroutine.resume
local coroutine_create = coroutine.create
local string_find = string.find

function Discord.send(form) 
	if type( form ) ~= "table" then Error( '[Discord] invalid type!' ) return end

	CHTTP({
		["failed"] = function( msg )
			print( "[Discord] "..msg )
		end,
		["method"] = "POST",
		["url"] = Discord.webhook,
		["body"] = util_TableToJSON(form),
		["type"] = "application/json; charset=utf-8"
	})
end

function Discord.editMessage(form, messageId)
    if type(form) ~= "table" or not messageId then Error("[Discord] invalid parameters!") return end

    CHTTP({
        ["failed"] = function(msg)
            print("[Discord] " .. msg)
        end,
        ["method"] = "PATCH",
        ["url"] = Discord.statuswebhook .. "/messages/" .. messageId,
        ["body"] = util_TableToJSON(form),
        ["type"] = "application/json; charset=utf-8"
    })
end

local function getAvatar(id, co)
	http_Fetch( "https://steamcommunity.com/profiles/"..id.."?xml=1", 
	function(body)
		local _, _, url = string_find(body, '<avatarFull>.*.(https://.*)]].*\n.*<vac')
		tmpAvatars[id] = url

		coroutine_resume(co)
	end, 
	function (msg)
		Error("[Discord] error getting avatar ("..msg..")")
	end )
end

local function formMsg( ply, str )
	local id = tostring( ply:SteamID64() )

	local co = coroutine_create( function() 
		local form = {
			["username"] = ply:Nick(),
			["content"] = str,
			["avatar_url"] = tmpAvatars[id],
			["allowed_mentions"] = {
				["parse"] = {}
			},
		}
		
		Discord.send(form)
	end )

	if tmpAvatars[id] == nil then 
		getAvatar( id, co )
	else 
		coroutine_resume( co )
	end
end

local function playerConnect( ply )
	local steamid64 = util_SteamIDTo64( ply.networkid )

	local co = coroutine_create( function()
		local form = {
			["username"] = Discord.hookname,
			["embeds"] = {{
				["author"] = {
					["name"] = ply.name .. " подключается...",
					["icon_url"] = tmpAvatars[steamid64],
					["url"] = 'https://steamcommunity.com/profiles/' .. steamid64,
				},
				["color"] = 16763979,
				["footer"] = {
					["text"] = ply.networkid,
				},
			}},
			["allowed_mentions"] = {
				["parse"] = {}
			},
		}

		Discord.send(form)
	end)

	if tmpAvatars[steamid64] == nil then 
		getAvatar( steamid64, co )
	else 
		coroutine_resume( co )
	end
end

local function plyFrstSpawn(ply)
	if IsValid(ply) then
		local steamid = ply:SteamID()
		local steamid64 = util_SteamIDTo64( steamid )

		local co = coroutine_create(function()
			local form = {
				["username"] = Discord.hookname,
				["embeds"] = {{
					["author"] = {
						["name"] = ply:Nick() .. " подключился",
						["icon_url"] = tmpAvatars[steamid64],
						["url"] = 'https://steamcommunity.com/profiles/' .. steamid64,
					},
					["color"] = 4915018,
					["footer"] = {
						["text"] = steamid,
					},
				}},
				["allowed_mentions"] = {
					["parse"] = {}
				},
			}

			Discord.send(form)
		end)

		if tmpAvatars[steamid64] == nil then 
			getAvatar( steamid64, co )
		else 
			coroutine_resume( co )
		end
	end
end

local function plyDisconnect(ply)
	local steamid64 = util_SteamIDTo64( ply.networkid )

	local co = coroutine_create(function()
		local form = {
			["username"] = Discord.hookname,
			["embeds"] = {{
				["author"] = {
					["name"] = ply.name .. " отключился",
					["icon_url"] = tmpAvatars[steamid64],
					["url"] = 'https://steamcommunity.com/profiles/' .. steamid64,
				},
				["description"] = '```' .. ply.reason .. '```',
				["color"] = 16730698,
				["footer"] = {
					["text"] = ply.networkid,
				},
			}},
			["allowed_mentions"] = {
				["parse"] = {}
			},
		}

		Discord.send(form)

		tmpAvatars[steamid64] = nil
	end)

	if tmpAvatars[steamid64] == nil then 
		getAvatar( steamid64, co )
	else 
		coroutine_resume( co )
	end

end

hook.Add("PlayerSay", "!!discord_sendmsg", formMsg)
gameevent.Listen( "player_connect" )
hook.Add("player_connect", "!!discord_plyConnect", playerConnect)
hook.Add("PlayerInitialSpawn", "!!discordPlyFrstSpawn", plyFrstSpawn)
gameevent.Listen( "player_disconnect" )
hook.Add("player_disconnect", "!!discord_onDisconnect", plyDisconnect)
hook.Add("Initialize", "!!discord_srvStarted", function() 
	local form = {
		["username"] = Discord.hookname,
		["embeds"] = {{
			["title"] = "Сервер запущен!",
			["description"] = "Карта сейчас - " .. game.GetMap(),
			["color"] = 5793266
		}}
	}

	Discord.send(form)
	hook.Remove("Initialize", "!!discord_srvStarted")
end)

timer.Create("ServerStatus_Discord", 1, 0, function()
	local playersList = ""
	local plyall = player.GetAll()
	local plyallcount = #plyall

	if plyallcount > 0 then
		for _, ply in ipairs(plyall) do
			playersList = playersList .. ply:Nick() .. "\n"
		end
	else
		playersList = "Никого"
	end

	local PLAYERS_COUNT = plyallcount
	local MAP = game.GetMap()
	local UPTIME = math.Round(SysTime() / 3600, 1)
	local MAP_UPTIME = math.Round(CurTime() / 3600, 1)
	local MODELCACHE = GetGlobalInt("ModelCache", 0) .. "/4096"

	local desc = string.format("**Игроки:**\n```\n%s\n```\n:busts_in_silhouette: Кол-во игроков: %d\n:map: Карта: %s\n:tools: Кэш моделей: %s\n:repeat: Аптайм сервера: %s часов\n:clock1: Аптайм карты: %s часов", playersList, PLAYERS_COUNT, MAP, MODELCACHE, UPTIME, MAP_UPTIME)

	local form = {
		["username"] = Discord.hookname,
		["embeds"] = {
			{
				["title"] = GetHostName(),
				["url"] = "https://classicbox.myarena.site/join.html",
				["description"] = desc,
				["color"] = nil,
			}
		},
		["attachments"] = {}
	}

	Discord.editMessage(form, "1259410534978162781")
end)
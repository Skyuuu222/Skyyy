local cloneref = cloneref or function(x) return x end

local game          = cloneref(game)
local http_service  = cloneref(game:GetService("HttpService"))
local players       = cloneref(game:GetService("Players"))
local starter_gui   = cloneref(game:GetService("StarterGui"))


--@types
type loader_config = {
	name: string,
	url: string,
	version: string?,
	author: string?,
}

--@list_game_loaders
local ___loaders: { [number]: loader_config } = {
	[6701277882] = {
		name    = "fish it",
		url     = "https://luaegis.net/scripts/v4/loaders/8686cf63-8b4b-4537-ad62-46370cd123c9.lua",
		version = "1.0.0",
		author  = "euphoria",
	},
    [2640407187] = {
        name    = "cedit",
        url     = "https://luaegis.net/scripts/v4/loaders/9a49143d-e012-4adc-8184-7daaa663c287.lua",
        version = "4.2.5",
        author  = "kimmy",
    },
    [9186719164] = {
        name    = "sailor-piece",
        url     = "https://api.luarmor.net/files/v4/loaders/bb6b824d6b34ae2345aeedf237580bb5.lua",
        version = "0.0.1",
        author  = "atomic",
    },
    [7089588429] = {
        name    = "drag-drive-simulator-dds",
        url     = "https://luaegis.net/scripts/v4/loaders/cf0d5530-e8d7-4ebd-9979-78b4358332af.lua",
        version = "0.0.1",
        author  = "atomic",
    },
    [6739698191] = {
        name    = "violence-district",
        url     = "https://api.luasec.org/loader/0cd309dd86c1",
        version = "0.0.1",
        author  = "atomic",
    },
    [10004244222] = {
        name    = "kick-a-lucky-block",
        url     = "https://luaegis.net/scripts/v4/loaders/022ddf9e-e2da-461d-a1e5-4e421dadc2ec.lua",
        version = "0.0.1",
        author  = "atomic",
    },
    [10200395747] = {
        name    = "grow-a-garden2",
        url     = "https://luaegis.net/scripts/v4/loaders/7b8ee026-c7cd-44ea-ba82-131087e8751a.lua",
        version = "0.0.1",
        author  = "atomic",
    },
    [9826885587] = {
        name    = "evomon",
        url     = "https://luaegis.net/scripts/v4/loaders/d2d69abb-e664-42fc-8e8b-72666fd81acf.lua",
        version = "0.0.1",
        author  = "atomic",
    },
    [5750914919] = {
        name    = "fisch",
        url     = "https://luaegis.net/scripts/v4/loaders/9332ba9b-6190-45b8-9e1c-0629282f9d78.lua",
        version = "0.0.1",
        author  = "atomic",
    },
    [7613921865] = {
        name    = "Anime Expeditions",
        url     = "https://luaegis.net/scripts/v4/loaders/0400cbe0-d0a7-4c3d-a234-8dedb385cdb9.lua",
        version = "0.0.1",
        author  = "atomic",
    },
    [10148749921] = {
        name    = "Animal Hospital",
        url     = "https://luaegis.net/scripts/v4/loaders/8a55ab5d-6ac7-4bd4-854b-69f3b577799e.lua",
        version = "0.0.1",
        author  = "atomic",
    },
}


--@list_place_loaders
local ___place_loaders: { [number]: loader_config } = {

	--@temp
    [132986577553100] = {
        name    = "cdid-sapi-quest",
        url     = "https://luaegis.net/scripts/v4/loaders/45250ba9-a034-47a0-b938-d6d4978e064c.lua",
        version = "0.0.1",
        author  = "atomic",
    },
}

--@utility
local function __notify(title: string, text: string): ()
	pcall(function()
		starter_gui:SetCore("SendNotification", {
			Title    = title,
			Text     = text,
			Duration = 5,
		})
	end)
end
--@loader
local function __load_script(url: string): boolean
	local success: boolean, result: any = pcall(function()
		local script_content: string = game:HttpGet(url)
		local loaded_function: any = loadstring(script_content)

		if loaded_function then
			loaded_function()
			return true
		else
			error("failed to compile script")
		end
	end)

	if not success then
		warn("[loader] failed:", result)
		__notify("euphoria loader", "failed to load script")
		return false
	end

	return true
end
--@main loader
local place_id: number    = game.PlaceId
local universe_id: number = game.GameId
local loader_config: loader_config? = ___place_loaders[place_id]
	or ___loaders[universe_id]
    
--@main execution
if not loader_config then
	warn("[loader] unsupported game:", place_id, universe_id)
	__notify("euphoria loader", "this game is not supported")
	return
end

__load_script(loader_config.url)

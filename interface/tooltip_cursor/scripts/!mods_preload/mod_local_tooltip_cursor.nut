local mod = ::Hooks.register("mod_local_tooltip_cursor", "1.1.0", "缺失光标坐标与地图标签修复");

local function isNoLauncher()
{
	return ("NoLauncherCN" in ::Const) && ::Const.NoLauncherCN == true;
}

local function hasNonAscii( _text )
{
	if (typeof _text != "string" || _text == "")
		return false;
	for (local i = 0; i < _text.len(); ++i)
	{
		if (_text[i] < 0 || _text[i] >= 128)
			return true;
	}
	return false;
}

local function hasAsciiAlnum( _text )
{
	for (local i = 0; i < _text.len(); ++i)
	{
		local ch = _text[i];
		if ((ch >= 48 && ch <= 57) || (ch >= 65 && ch <= 90) || (ch >= 97 && ch <= 122))
			return true;
	}
	return false;
}

local function toAsciiPrefix( _text )
{
	local prefix = "";
	for (local i = 0; i < _text.len(); ++i)
	{
		local ch = _text[i];
		if (ch >= 32 && ch <= 126)
			prefix += _text.slice(i, i + 1);
		else
			break;
	}
	prefix = strip(prefix);
	return hasAsciiAlnum(prefix) ? prefix : "";
}

local function resolveAsciiLabel( _entity, _rawText )
{
	local scriptName = "";
	try
	{
		scriptName = ::IO.scriptFilenameByHash(_entity.ClassNameHash);
	}
	catch (_e)
	{
	}

	if (("PaleSovereign" in ::getroottable()) && ::PaleSovereign.isActive() && ::PaleSovereign.isCastle(_entity))
		return "Pale Keep";

	if (scriptName.find("stronghold_player_base") != null)
	{
		local size = 1;
		try { size = _entity.getSize(); } catch (_e) {}
		if (size <= 1)
			return "Outpost";
		if (size == 2)
			return "Fort";
		return "Stronghold";
	}

	if (scriptName.find("stronghold_hamlet") != null)
		return "Hamlet";

	if (scriptName.find("cultist_camp_location") != null)
		return "Cultist Camp";

	if (_rawText.find("讨伐") != null)
		return "Crusaders";
	if (_rawText.find("攻城") != null)
		return "Raiders";
	if (_rawText.find("邪教") != null)
		return "Cultists";
	if (_rawText.find("雇佣兵") != null || _rawText.find("佣兵") != null)
		return "Mercenary Patrol";
	if (_rawText.find("巡逻") != null)
		return "Patrol";
	if (_rawText.find("商队") != null)
		return "Caravan";
	if (_rawText.find("驻军") != null || _rawText.find("守卫") != null || _rawText.find("护卫") != null)
		return "Garrison";
	if (_rawText.find("野蛮") != null || _rawText.find("氏族") != null)
		return "Barbarians";

	local prefix = toAsciiPrefix(_rawText);
	if (prefix != "")
		return prefix;

	local isLoc = false;
	try { isLoc = _entity.isLocation(); } catch (_e) {}
	if (isLoc)
	{
		if (scriptName.find("settlements/") != null)
			return "Settlement";
		return "Location";
	}
	return "Party";
}

local function sanitizeEntityLabel( _entity )
{
	if (!isNoLauncher())
		return;
	if (_entity == null || ::MSU.isNull(_entity))
		return;

	local hasLabel = false;
	try { hasLabel = _entity.hasLabel("name"); } catch (_e) { return; }
	if (!hasLabel)
		return;

	local label = null;
	try { label = _entity.getLabel("name"); } catch (_e) { return; }
	if (label == null)
		return;

	local rawText = label.Text;
	if (!hasNonAscii(rawText))
		return;

	// Only sanitize the OpenGL world-map label; keep entity.m.Name / getName() in Chinese for UI and tooltips.
	label.Text = resolveAsciiLabel(_entity, rawText);
}

mod.queue(">mod_msu", function()
{
	mod.hook("scripts/ui/screens/tooltip/modules/tooltip", function(q)
	{
		foreach (method in ["mouseEnterTile", "mouseHoverTile"])
		{
			q[method] = @(__original) function(...)
			{
				// The world can update before the cursor has a position.
				if (vargv.len() >= 2 && (vargv[0] == null || vargv[1] == null))
					return;
				local args = [this];
				args.extend(vargv);
				return __original.acall(args);
			};
		}
	});
});

mod.queue([">mod_msu", ">mod_pale_sovereign"], function()
{
	mod.hook("scripts/entity/world/world_entity", function(q)
	{
		q.onInit = @(__original) function()
		{
			__original();
			sanitizeEntityLabel(this);
		};

		q.setName = @(__original) function( _n )
		{
			local ret = __original(_n);
			sanitizeEntityLabel(this);
			return ret;
		};

		q.onDeserialize = @(__original) function( _in )
		{
			local ret = __original(_in);
			sanitizeEntityLabel(this);
			return ret;
		};
	});

	local hookLabelRefresh = function( _scriptPath, _methodName )
	{
		mod.hook(_scriptPath, function(q)
		{
			q[_methodName] = @(__original) function()
			{
				local ret = __original();
				sanitizeEntityLabel(this);
				return ret;
			};
		});
	};

	hookLabelRefresh("scripts/entity/world/settlements/stronghold_player_base", "updateTown");
	hookLabelRefresh("scripts/entity/world/settlements/stronghold_hamlet", "updateTown");
	hookLabelRefresh("scripts/entity/world/locations/cultist_camp_location", "updateName");

	mod.hook("scripts/ui/screens/stronghold/modules/stronghold_screen_main_module", function(q)
	{
		q.changeBaseName = @(__original) function( _data )
		{
			local ret = __original(_data);
			sanitizeEntityLabel(this.getTown());
			return ret;
		};
	});
}, ::Hooks.QueueBucket.VeryLate);

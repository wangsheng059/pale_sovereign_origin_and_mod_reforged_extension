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

local function extractAsciiParenSuffix( _text )
{
	if (typeof _text != "string" || _text.len() < 4)
		return "";
	if (_text.slice(_text.len() - 1) != ")")
		return "";

	for (local i = _text.len() - 3; i >= 0; --i)
	{
		if (_text.slice(i, i + 2) == " (")
		{
			local suffix = _text.slice(i);
			if (!hasNonAscii(suffix) && suffix.len() >= 4)
				return suffix;
			return "";
		}
	}
	return "";
}

local function resolveAsciiLabel( _entity, _rawText )
{
	local suffix = extractAsciiParenSuffix(_rawText);
	local coreText = suffix != "" ? _rawText.slice(0, _rawText.len() - suffix.len()) : _rawText;

	local scriptName = "";
	try
	{
		scriptName = ::IO.scriptFilenameByHash(_entity.ClassNameHash);
	}
	catch (_e)
	{
	}

	local baseLabel = "";
	if (("PaleSovereign" in ::getroottable()) && ::PaleSovereign.isActive() && ::PaleSovereign.isCastle(_entity))
		baseLabel = "Pale Keep";
	else if (scriptName.find("stronghold_player_base") != null)
	{
		local size = 1;
		try { size = _entity.getSize(); } catch (_e) {}
		if (size <= 1)
			baseLabel = "Outpost";
		else if (size == 2)
			baseLabel = "Fort";
		else
			baseLabel = "Stronghold";
	}
	else if (scriptName.find("stronghold_hamlet") != null)
		baseLabel = "Hamlet";
	else if (scriptName.find("cultist_camp_location") != null)
		baseLabel = "Cultist Camp";
	else if (coreText.find("讨伐") != null)
		baseLabel = "Crusaders";
	else if (coreText.find("攻城") != null)
		baseLabel = "Raiders";
	else if (coreText.find("邪教") != null)
		baseLabel = "Cultists";
	else if (coreText.find("雇佣兵") != null || coreText.find("佣兵") != null)
		baseLabel = "Mercenary Patrol";
	else if (coreText.find("巡逻") != null)
		baseLabel = "Patrol";
	else if (coreText.find("商队") != null)
		baseLabel = "Caravan";
	else if (coreText.find("驻军") != null || coreText.find("守卫") != null || coreText.find("护卫") != null)
		baseLabel = "Garrison";
	else if (coreText.find("野蛮") != null || coreText.find("氏族") != null)
		baseLabel = "Barbarians";
	else
	{
		local prefix = toAsciiPrefix(coreText);
		if (prefix != "")
			baseLabel = prefix;
		else
		{
			local isLoc = false;
			try { isLoc = _entity.isLocation(); } catch (_e) {}
			if (isLoc)
				baseLabel = scriptName.find("settlements/") != null ? "Settlement" : "Location";
			else
				baseLabel = "Party";
		}
	}

	return baseLabel + suffix;
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

mod.queue([">mod_msu", ">mod_modular_vanilla", ">mod_reforged", ">mod_pale_sovereign"], function()
{
	local wrapZeroArg = function( _q, _methodName )
	{
		_q[_methodName] = @(__original) function()
		{
			local ret = __original();
			sanitizeEntityLabel(this);
			return ret;
		};
	};

	local wrapOneArg = function( _q, _methodName )
	{
		_q[_methodName] = @(__original) function( _arg )
		{
			local ret = __original(_arg);
			sanitizeEntityLabel(this);
			return ret;
		};
	};

	local zeroArgMethods = [
		"onInit",
		"onAfterInit",
		"updateStrength",
		"updateName",
		"updateTown",
		"onCombatLost"
	];

	local oneArgMethods = [
		"setName",
		"onDeserialize"
	];

	local wrapEntityClass = function( _q )
	{
		foreach (m in zeroArgMethods)
		{
			if (_q.contains(m, false))
				wrapZeroArg(_q, m);
		}
		foreach (m in oneArgMethods)
		{
			if (_q.contains(m, false))
				wrapOneArg(_q, m);
		}
	};

	mod.hook("scripts/entity/world/world_entity", function(q)
	{
		wrapEntityClass(q);
	});

	mod.hookTree("scripts/entity/world/world_entity", function(q)
	{
		wrapEntityClass(q);
	});

	mod.hook("scripts/entity/world/party", function(q)
	{
		if (q.contains("onUpdate", false))
			wrapZeroArg(q, "onUpdate");
	});

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

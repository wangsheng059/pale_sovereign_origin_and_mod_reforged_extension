// Career Stats (refactored Legacy module v2.0.0).
// Pure Simplified Chinese, Modern Hooks, save-bloat fixed, closure-leak fixed, zero log spam.

::CareerStats <- {
	ID = "mod_career_stats",
	Version = "2.0.0",
	Name = "生涯统计",
	Mod = null,
	ActiveUser = null,
	ActiveTarget = null,
	MinHitChance = 5,
	MaxHitChance = 95,
	evaluateRanks = null,
	DummyStats = ::new("scripts/mods/career_stats/career_stats"),
	IsLoading = false,
	LastFallen = null,
	PendingDeparture = null,
	HallOfFameTooltips = [],
	AppearanceLayers = [
		"body", "head", "hair", "beard", "beard_top", "tattoo_body", "tattoo_head",
		"permanent_injury_1", "permanent_injury_2", "permanent_injury_3", "permanent_injury_4"
	]
};

// Capture sprite brush names from a living brother before removal/death.
::CareerStats.captureAppearance <- function( _bro )
{
	local appearance = {};
	foreach (layer in ::CareerStats.AppearanceLayers)
	{
		try
		{
			local sprite = _bro.getSprite(layer);
			appearance[layer] <- (sprite != null && sprite.HasBrush) ? sprite.getBrush().Name : "";
		}
		catch (e)
		{
			appearance[layer] <- "";
		}
	}
	return appearance;
};

// Strip empty sprite layer entries before saving to keep saves compact.
::CareerStats._compactAppearance <- function( _appearance )
{
	if (_appearance == null) return null;
	local out = {};
	foreach (k, v in _appearance)
	{
		if (v != null && v != "") out[k] <- v;
	}
	return out.len() > 0 ? out : null;
};

// Detect DOT / environmental fatal cause as a fallback if vanilla addFallen does not fire.
::CareerStats.detectFatalCause <- function( _bro, _skill, _fatalityType )
{
	local function classify( _id )
	{
		if (_id == null || _id == "") return null;
		local lid = _id.tolower();
		if (lid.find("bleed") != null) return "失血而亡";
		if (lid.find("burn") != null || lid.find("fire") != null) return "被烧死";
		if (lid.find("poison") != null) return "中毒身亡";
		if (lid.find("acid") != null) return "被腐蚀殆尽";
		if (lid.find("frost") != null || lid.find("freez") != null || lid.find("hypotherm") != null) return "冻死";
		if (lid.find("disease") != null || lid.find("plague") != null || lid.find("infect") != null) return "病死";
		return null;
	}

	if (_skill != null)
	{
		try
		{
			local cause = classify(_skill.getID());
			if (cause != null) return cause;
		}
		catch (e) {}
	}

	if (_bro != null)
	{
		try
		{
			foreach (s in _bro.getSkills().query())
			{
				try
				{
					local cause = classify(s.getID());
					if (cause != null) return cause;
				}
				catch (e2) {}
			}
		}
		catch (e) {}
	}

	return null;
};

// Compact past days of finance history to one entry per day while keeping recent days intact.
::CareerStats.compactFinanceHistory <- function( _hist, _keepRecentDays = 1 )
{
	if (_hist == null) return [];
	local n = _hist.len();
	if (n <= 1) return _hist;

	local function safeDay( e )   { return ("day" in e) ? e.day : 0; }
	local function safeBal( e )   { return ("balance" in e) ? e.balance : 0; }
	local function safeDelta( e ) { return ("delta" in e) ? e.delta : 0; }

	local latestDay = safeDay(_hist[n - 1]);
	local cutoffDay = latestDay - _keepRecentDays;

	local result = [];
	local curDay = -2147483647;
	local curBal = 0;
	local curDelta = 0;
	local hasAgg = false;

	for (local i = 0; i < n; i++)
	{
		local e = _hist[i];
		local d = safeDay(e);

		if (d > cutoffDay)
		{
			if (hasAgg)
			{
				result.push({ day = curDay, balance = curBal, delta = curDelta });
				hasAgg = false;
			}
			result.push({ day = d, balance = safeBal(e), delta = safeDelta(e) });
			continue;
		}

		if (d != curDay)
		{
			if (hasAgg)
				result.push({ day = curDay, balance = curBal, delta = curDelta });
			curDay = d;
			curBal = safeBal(e);
			curDelta = safeDelta(e);
			hasAgg = true;
		}
		else
		{
			curBal = safeBal(e);
			curDelta += safeDelta(e);
		}
	}

	if (hasAgg)
		result.push({ day = curDay, balance = curBal, delta = curDelta });

	return result;
};

::CareerStats.MH <- ::Hooks.register(::CareerStats.ID, ::CareerStats.Version, ::CareerStats.Name);
::CareerStats.MH.require("mod_msu >= 1.2.0", "mod_legacy");

::CareerStats.MH.queue(">mod_msu", ">mod_legacy", function()
{
	::CareerStats.Mod = ::MSU.Class.Mod(::CareerStats.ID, ::CareerStats.Version, ::CareerStats.Name);

	local currentStatGetter = null;
	local function compareByStat( _a, _b )
	{
		return _b.m.CareerStats_Stats[currentStatGetter]() <=> _a.m.CareerStats_Stats[currentStatGetter]();
	}

	::CareerStats.evaluateRanks = function()
	{
		if (::CareerStats.IsLoading) return;
		local bros = [];
		try
		{
			foreach (b in ::World.getPlayerRoster().getAll())
			{
				if (b != null && !("isNull" in b && b.isNull())
					&& ("CareerStats_Stats" in b.m) && b.m.CareerStats_Stats != null)
					bros.push(b);
			}
		}
		catch (e) { return; }

		if (bros.len() == 0) return;

		foreach (statKey, _unused in ::CareerStats.DummyStats.m.Ranks)
		{
			local clonedBros = clone bros;
			currentStatGetter = "get" + statKey;
			clonedBros.sort(compareByStat);

			local lastChange = 0;
			for (local i = 0; i < clonedBros.len(); ++i)
			{
				if (clonedBros[i].m.CareerStats_Stats[currentStatGetter]() != clonedBros[lastChange].m.CareerStats_Stats[currentStatGetter]())
					lastChange = i;
				clonedBros[i].m.CareerStats_Stats.m.Ranks[statKey] = lastChange + 1;
			}
		}
	};

	::CareerStats.Mod.Tooltips.setTooltips({
		Fallen = ::MSU.Class.CustomTooltip(@(_data) ::World.Statistics.CareerStats_getTooltipForFallen(_data.CareerStats_Idx)),
		HallOfFame = ::MSU.Class.CustomTooltip(@(_data) ::CareerStats.HallOfFameTooltips.len() > _data.HallOfFameIdx
			? ::CareerStats.HallOfFameTooltips[_data.HallOfFameIdx]
			: [{ id = 1, type = "text", text = "暂无数据" }])
	});

	::include("career_stats/player");
	::include("career_stats/actor");
	::include("career_stats/combat_hooks");
	::include("career_stats/tactical_screen_topbar_event_log");
	::include("career_stats/statistics_manager");
	::include("career_stats/world_player_roster");
	::include("career_stats/finance_tracker");
	::include("career_stats/strength_tracker");
	::include("career_stats/top_traits");
	::include("career_stats/portraits");
	::include("career_stats/world_obituary_screen");

	::Hooks.registerJS("ui/mods/career_stats/portrait_sprites.js");
	::Hooks.registerJS("ui/mods/career_stats/world_obituary_screen.js");
});

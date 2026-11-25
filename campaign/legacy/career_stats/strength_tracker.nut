// Party Strength Tracker (v3 proven hit/dodge average of top-12 brothers).
// Clean refactor: removed archived v2 dead code and all LegacyPerma dependencies.
// Retains read-only deserialization of CareerStats_InjuryMarkers for old-save safety.

::CareerStats.STRENGTH2_STAT_FLOOR <- 50.0;
::CareerStats.STRENGTH2_BROS       <- 12;
::CareerStats.STRENGTH2_RAMP_START <- 8;
::CareerStats.STRENGTH2_RAMP_FULL  <- 50;
::CareerStats.RANK_POINTS_MAX      <- 100;

::CareerStats.rampWeight <- function( _attempts )
{
	local start = ::CareerStats.STRENGTH2_RAMP_START.tofloat();
	local full  = ::CareerStats.STRENGTH2_RAMP_FULL.tofloat();
	if (_attempts <= start) return 0.0;
	if (_attempts >= full || full <= start) return 1.0;
	return (_attempts - start) / (full - start);
};

::CareerStats.smoothedRate <- function( _successes, _attempts )
{
	local prior = ::CareerStats.STRENGTH2_STAT_FLOOR / 100.0;
	if (_attempts <= 0) return prior;
	local raw = _successes.tofloat() / _attempts;
	return prior + (raw - prior) * ::CareerStats.rampWeight(_attempts);
};

::CareerStats.provenRate <- function( _successes, _attempts )
{
	if (_attempts <= 0) return 0.0;
	return _successes.tofloat() / _attempts * ::CareerStats.rampWeight(_attempts);
};

::CareerStats.computeBrotherScores <- function( _bro )
{
	local hitPct = 0.0;
	local dodgePct = 0.0;
	local lvl = 1;
	try
	{
		if (_bro != null && ("CareerStats_Stats" in _bro.m) && _bro.m.CareerStats_Stats != null)
		{
			local st = _bro.m.CareerStats_Stats.m.Stats;
			hitPct   = ::CareerStats.provenRate(st.NumAccuracyHits, st.NumAccuracyHits + st.NumAccuracyMisses) * 100.0;
			dodgePct = ::CareerStats.provenRate(st.NumAccuracyDodges, st.NumAccuracyDodges + st.NumAccuracyHitsReceived) * 100.0;
		}
		try { lvl = _bro.getLevel(); } catch (e) {}
	}
	catch (e) {}
	return { eff = (hitPct + dodgePct) / 2.0, hit = hitPct, dodge = dodgePct, level = lvl };
};

::CareerStats.computePartyStrength <- function()
{
	local list = [];
	try
	{
		foreach (bro in ::World.getPlayerRoster().getAll())
		{
			if (bro == null) continue;
			try { if (bro.isNull()) continue; } catch (e) {}
			list.push(::CareerStats.computeBrotherScores(bro));
		}
	}
	catch (e) { return { strength = 0.0, hit = 0.0, dodge = 0.0 }; }

	list.sort(function( a, b ) { return b.eff <=> a.eff; });

	local denom = ::CareerStats.STRENGTH2_BROS;
	local take = list.len() < denom ? list.len() : denom;
	local sumE = 0.0, sumH = 0.0, sumD = 0.0;
	for (local i = 0; i < take; i++)
	{
		sumE += list[i].eff;
		sumH += list[i].hit;
		sumD += list[i].dodge;
	}

	local clampPct = function( _v )
	{
		if (_v > 100.0) return 100.0;
		if (_v < 0.0) return 0.0;
		return _v;
	};
	return {
		strength = clampPct(sumE / denom),
		hit      = clampPct(sumH / denom),
		dodge    = clampPct(sumD / denom)
	};
};

// Optional Hardened world-difficulty scaling (no-op when Hardened is not installed).
::CareerStats.hasHardenedScaling <- function()
{
	try
	{
		if (!("Hardened" in ::getroottable()) || ::Hardened == null) return false;
		if (!("Global" in ::Hardened) || ::Hardened.Global == null) return false;
		local g = ::Hardened.Global;
		return ("WorldScalingBase" in g) && ("WorldScalingMax" in g) && ("WorldScalingPerDay" in g);
	}
	catch (e) { return false; }
};

::CareerStats.worldDifficultyForDay <- function( _day )
{
	try
	{
		if (!::CareerStats.hasHardenedScaling()) return 1.0;
		local g = ::Hardened.Global;
		local d = _day < 0 ? 0 : _day;
		local ret = g.WorldScalingBase * (1.0 + d.tofloat() * g.WorldScalingPerDay);
		local lo = ("WorldScalingMin" in g) ? g.WorldScalingMin : ret;
		local hi = g.WorldScalingMax;
		if (ret < lo) ret = lo;
		if (ret > hi) ret = hi;
		return ret;
	}
	catch (e) { return 1.0; }
};

::CareerStats.difficultyFactorForDay <- function( _day )
{
	try
	{
		if (!::CareerStats.hasHardenedScaling()) return 1.0;
		local max = ::Hardened.Global.WorldScalingMax;
		if (max <= 0.0001) return 1.0;
		local f = ::CareerStats.worldDifficultyForDay(_day) / max;
		if (f < 0.0) f = 0.0;
		if (f > 1.0) f = 1.0;
		return f;
	}
	catch (e) { return 1.0; }
};

::CareerStats.currentWorldDifficultyPct <- function()
{
	try
	{
		if (!::CareerStats.hasHardenedScaling()) return null;
		return ::CareerStats.worldDifficultyForDay(::World.getTime().Days) * 100.0;
	}
	catch (e) { return null; }
};

::CareerStats.maxWorldDifficultyPct <- function()
{
	try
	{
		if (!::CareerStats.hasHardenedScaling()) return null;
		return ::Hardened.Global.WorldScalingMax * 100.0;
	}
	catch (e) { return null; }
};

// Confirm or discard pending death markers (discard if Nine Lives saved the brother).
::CareerStats.validateDeathMarkers <- function()
{
	try
	{
		if (::World == null || ::World.Statistics == null) return;
		if (!("CareerStats_DeathMarkers" in ::World.Statistics.m)) return;

		local markers = ::World.Statistics.m.CareerStats_DeathMarkers;
		local hasPending = false;
		foreach (m in markers)
			if (("pending" in m) && m.pending) { hasPending = true; break; }
		if (!hasPending) return;

		local aliveIds = {};
		foreach (bro in ::World.getPlayerRoster().getAll())
		{
			if (bro == null) continue;
			try { if (bro.isNull()) continue; } catch (e) {}
			try { aliveIds[bro.getID()] <- true; } catch (e) {}
		}

		local kept = [];
		foreach (m in markers)
		{
			if (("pending" in m) && m.pending)
			{
				local id = ("id" in m) ? m.id : null;
				if (id != null && (id in aliveIds)) continue;
				m.pending = false;
			}
			kept.push(m);
		}
		::World.Statistics.m.CareerStats_DeathMarkers = kept;
	}
	catch (e) {}
};

// Optional BP Jewelry legendary ring markers.
::CareerStats.hasJewelryMod <- function()
{
	try { if (::Hooks.hasMod("BP_jewelry")) return true; } catch (e) {}
	try { if ("bp_ring" in ::getroottable()) return true; } catch (e) {}
	return false;
};

::CareerStats.ringBlankIcon <- function( _it )
{
	local skin = -1;
	try { skin = _it.m.Skin; } catch (e) {}
	if (typeof skin != "integer" || skin < 0) return "ui/items/accessory/ring_1.png";
	return "ui/items/accessory/ring_" + (skin + 1) + ".png";
};

::CareerStats.ringIconToBlank <- function( _icon )
{
	if (typeof _icon != "string" || _icon.len() == 0) return "ui/items/accessory/ring_1.png";
	foreach (suf in ["_legendary.png", "_rare.png", "_magic.png"])
	{
		local i = _icon.find(suf);
		if (i != null && i + suf.len() == _icon.len()) return _icon.slice(0, i) + ".png";
	}
	return _icon;
};

::CareerStats.ringSignature <- function( _it )
{
	local sig = "R";
	try { sig += ":s" + _it.m.Skin; } catch (e) { sig += ":s-1"; }
	try { sig += ":v" + _it.m.NameVariant; } catch (e) { sig += ":v-1"; }
	try { sig += ":p" + _it.m.PrefixIdx; } catch (e) { sig += ":p-1"; }
	try { sig += ":f" + _it.m.SuffixIdx; } catch (e) { sig += ":f-1"; }
	try { sig += ":d" + _it.m.DemonIdx; } catch (e) { sig += ":d-1"; }
	return sig;
};

::CareerStats.scanLegendaryRings <- function()
{
	local out = [];
	local scan = function( _it )
	{
		if (_it == null) return;
		try { if (_it.getID() != "accessory.bp_ring") return; } catch (e) { return; }
		local rar = -1;
		try { rar = _it.m.Rarity; } catch (e) {}
		if (rar != 2) return;
		local appr = true;
		try { appr = _it.m.Appraised; } catch (e) {}
		if (!appr) return;
		local name = "";
		try { name = _it.getName(); } catch (e) {}
		out.push({
			sig = ::CareerStats.ringSignature(_it),
			name = name,
			icon = ::CareerStats.ringBlankIcon(_it)
		});
	};

	try
	{
		foreach (bro in ::World.getPlayerRoster().getAll())
		{
			if (bro == null) continue;
			try { if (bro.isNull()) continue; } catch (e) {}
			local items = bro.getItems();
			if (items != null)
				foreach (it in items.getAllItems()) scan(it);
		}
	}
	catch (e) {}

	try { foreach (it in ::World.Assets.getStash().getItems()) scan(it); } catch (e) {}
	return out;
};

::CareerStats.syncRingMarkers <- function()
{
	try
	{
		if (!::CareerStats.hasJewelryMod()) return;
		if (::World == null || ::World.Statistics == null) return;
		local stat = ::World.Statistics;
		if (!("CareerStats_RingMarkers" in stat.m)) return;

		local firstRun = !("CareerStats_RingSeenSigs" in stat.m) || typeof stat.m.CareerStats_RingSeenSigs != "table";
		if (firstRun) stat.m.CareerStats_RingSeenSigs <- {};
		local seen = stat.m.CareerStats_RingSeenSigs;

		local rings = ::CareerStats.scanLegendaryRings();
		local byName = {};
		foreach (r in rings)
			if (typeof r.name == "string" && r.name.len() > 0 && !(r.name in byName))
				byName[r.name] <- r.icon;

		foreach (mk in stat.m.CareerStats_RingMarkers)
		{
			if (typeof mk != "table") continue;
			local ic = ("icon" in mk) ? mk.icon : "";
			if ((ic == "" || ic == "ui/items/accessory/ring_1_legendary.png") && ("name" in mk) && (mk.name in byName))
				ic = byName[mk.name];
			ic = ::CareerStats.ringIconToBlank(ic);
			if ("icon" in mk) mk.icon = ic; else mk.icon <- ic;
		}

		if (firstRun)
		{
			foreach (r in rings) seen[r.sig] <- true;
			return;
		}

		local day = 0;
		try { day = ::World.getTime().Days; } catch (e) {}
		foreach (r in rings)
		{
			if (r.sig in seen) continue;
			seen[r.sig] <- true;
			stat.m.CareerStats_RingMarkers.push({ day = day, icon = r.icon, name = r.name });
		}
	}
	catch (e) {}
};

::CareerStats.strengthIntervalForDay <- function( _day )
{
	local iv = 5;
	while (_day >= iv * 30) iv = iv * 2;
	return iv;
};

::CareerStats.updateStrengthSnapshots <- function()
{
	try
	{
		if (::CareerStats.IsLoading) return;
		if (::World == null || ::World.Statistics == null) return;

		::CareerStats.validateDeathMarkers();
		::CareerStats.syncRingMarkers();
		try { if ("updateTopTraits" in ::CareerStats) ::CareerStats.updateTopTraits(false); } catch (e) {}

		local stat = ::World.Statistics;
		if (!("CareerStats_StrengthHistory_V2" in stat.m))
			stat.m.CareerStats_StrengthHistory_V2 <- [];

		local curDay = ::World.getTime().Days;
		local iv = ::CareerStats.strengthIntervalForDay(curDay);
		local hist = stat.m.CareerStats_StrengthHistory_V2;

		if (hist.len() > 0)
		{
			local needCompact = false;
			foreach (p in hist)
				if (p.day % iv != 0) { needCompact = true; break; }
			if (needCompact)
			{
				local kept = [];
				foreach (p in hist)
					if (p.day % iv == 0) kept.push(p);
				hist = kept;
				stat.m.CareerStats_StrengthHistory_V2 = kept;
			}
		}

		if (hist.len() == 0)
		{
			local d0 = curDay - (curDay % iv);
			local r = ::CareerStats.computePartyStrength();
			if (curDay < iv)
			{
				hist.push({ day = d0, strength = r.strength, hit = r.hit, dodge = r.dodge });
				stat.m.CareerStats_LastStrengthDayV2 = d0;
				return;
			}
			local d = 0;
			local guard = 0;
			while (d <= d0 && guard < 100000)
			{
				hist.push({ day = d, strength = r.strength, hit = r.hit, dodge = r.dodge, bf = true });
				d += iv;
				guard++;
			}
			stat.m.CareerStats_LastStrengthDayV2 = hist.len() > 0 ? hist[hist.len() - 1].day : d0;
			return;
		}

		if (hist[0].day > 0)
		{
			local r = ::CareerStats.computePartyStrength();
			local firstReal = hist[0].day;
			local prefix = [];
			local d = 0;
			local guard = 0;
			while (d < firstReal && guard < 100000)
			{
				prefix.push({ day = d, strength = r.strength, hit = r.hit, dodge = r.dodge, bf = true });
				d += iv;
				guard++;
			}
			if (prefix.len() > 0)
			{
				foreach (p in hist) prefix.push(p);
				hist = prefix;
				stat.m.CareerStats_StrengthHistory_V2 = hist;
			}
		}

		local lastDay = hist[hist.len() - 1].day;
		local nextDay = lastDay + iv;
		local guard = 0;
		while (curDay >= nextDay && guard < 100000)
		{
			local r = ::CareerStats.computePartyStrength();
			hist.push({ day = nextDay, strength = r.strength, hit = r.hit, dodge = r.dodge });
			lastDay = nextDay;
			nextDay += iv;
			guard++;
		}
		stat.m.CareerStats_LastStrengthDayV2 = lastDay;
	}
	catch (e) {}
};

// Serialize/deserialize strength history & markers on statistics_manager.
::CareerStats.MH.hook("scripts/statistics/statistics_manager", function(q)
{
	q.m.CareerStats_StrengthHistory_V2 <- [];
	q.m.CareerStats_DeathMarkers       <- [];
	q.m.CareerStats_InjuryMarkers      <- [];
	q.m.CareerStats_RingMarkers        <- [];
	q.m.CareerStats_RingSeenCount      <- 0;
	q.m.CareerStats_RingSeenSigs       <- {};
	q.m.CareerStats_LastStrengthDayV2  <- -5;

	q.create = @(__original) function()
	{
		__original();
		this.m.CareerStats_StrengthHistory_V2 = [];
		this.m.CareerStats_DeathMarkers = [];
		this.m.CareerStats_InjuryMarkers = [];
		this.m.CareerStats_RingMarkers = [];
		this.m.CareerStats_RingSeenCount = 0;
		this.m.CareerStats_RingSeenSigs = {};
		this.m.CareerStats_LastStrengthDayV2 = -5;
	};

	q.onSerialize = @(__original) function( _out )
	{
		try
		{
			::CareerStats.Mod.Serialization.flagSerialize("CareerStats_StrengthHistory_V2", this.m.CareerStats_StrengthHistory_V2, this.m.Flags);
			::CareerStats.Mod.Serialization.flagSerialize("CareerStats_DeathMarkers",       this.m.CareerStats_DeathMarkers,       this.m.Flags);
			::CareerStats.Mod.Serialization.flagSerialize("CareerStats_InjuryMarkers",      this.m.CareerStats_InjuryMarkers,      this.m.Flags);
			::CareerStats.Mod.Serialization.flagSerialize("CareerStats_RingMarkers",        this.m.CareerStats_RingMarkers,        this.m.Flags);
			::CareerStats.Mod.Serialization.flagSerialize("CareerStats_RingSeenCount",      [this.m.CareerStats_RingSeenCount],    this.m.Flags);
			local rssOut = (typeof this.m.CareerStats_RingSeenSigs == "table") ? this.m.CareerStats_RingSeenSigs : {};
			::CareerStats.Mod.Serialization.flagSerialize("CareerStats_RingSeenSigs",       rssOut,                                this.m.Flags);
		}
		catch (e) {}
		return __original(_out);
	};

	q.onDeserialize = @(__original) function( _in )
	{
		local ret = __original(_in);
		try
		{
			local h = ::CareerStats.Mod.Serialization.flagDeserialize("CareerStats_StrengthHistory_V2", [], null, this.m.Flags);
			this.m.CareerStats_StrengthHistory_V2 = (typeof h == "array") ? h : [];

			local d = ::CareerStats.Mod.Serialization.flagDeserialize("CareerStats_DeathMarkers", [], null, this.m.Flags);
			this.m.CareerStats_DeathMarkers = (typeof d == "array") ? d : [];

			local inj = ::CareerStats.Mod.Serialization.flagDeserialize("CareerStats_InjuryMarkers", [], null, this.m.Flags);
			this.m.CareerStats_InjuryMarkers = (typeof inj == "array") ? inj : [];

			local rm = ::CareerStats.Mod.Serialization.flagDeserialize("CareerStats_RingMarkers", [], null, this.m.Flags);
			this.m.CareerStats_RingMarkers = (typeof rm == "array") ? rm : [];

			local rsc = ::CareerStats.Mod.Serialization.flagDeserialize("CareerStats_RingSeenCount", [0], null, this.m.Flags);
			this.m.CareerStats_RingSeenCount = (typeof rsc == "array" && rsc.len() > 0 && typeof rsc[0] == "integer") ? rsc[0] : 0;

			local rss = ::CareerStats.Mod.Serialization.flagDeserialize("CareerStats_RingSeenSigs", {}, null, this.m.Flags);
			this.m.CareerStats_RingSeenSigs = (typeof rss == "table") ? rss : {};

			local hist = this.m.CareerStats_StrengthHistory_V2;
			this.m.CareerStats_LastStrengthDayV2 = hist.len() > 0 ? hist[hist.len() - 1].day : -5;
		}
		catch (e)
		{
			this.m.CareerStats_StrengthHistory_V2 = [];
			this.m.CareerStats_DeathMarkers = [];
			this.m.CareerStats_InjuryMarkers = [];
			this.m.CareerStats_RingMarkers = [];
			this.m.CareerStats_RingSeenCount = 0;
			this.m.CareerStats_RingSeenSigs = {};
			this.m.CareerStats_LastStrengthDayV2 = -5;
		}
		return ret;
	};
});

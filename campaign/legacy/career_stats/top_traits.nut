// Dynamic Top-3 brother rank trait controller (Resolve +5 / +3 / +2 after Day 50 & 10 battles in Top 3).

::CareerStats.TOP_TRAIT_MIN_DAY      <- 50;
::CareerStats.TOP_TRAIT_HOLD_BATTLES <- 10;
::CareerStats.TOP_TRAIT_ID           <- "trait.legacy_top";
::CareerStats.TOP_TRAIT_SCRIPT       <- "scripts/skills/traits/legacy_top_trait";
::CareerStats.TOP_TRAIT_RANK_FLAG    <- "LegacyTopRank";
::CareerStats.TOP_TRAIT_HELD_FLAG    <- "LegacyTopHeld";

::CareerStats.MH.hook("scripts/statistics/statistics_manager", function(q)
{
	q.m.CareerStats_TopTraitState <- [];

	q.create = @(__original) function()
	{
		__original();
		this.m.CareerStats_TopTraitState = [];
	};

	q.onSerialize = @(__original) function( _out )
	{
		try
		{
			::CareerStats.Mod.Serialization.flagSerialize(
				"CareerStats_TopTraitState", this.m.CareerStats_TopTraitState, this.m.Flags);
		}
		catch (e) {}
		return __original(_out);
	};

	q.onDeserialize = @(__original) function( _in )
	{
		local ret = __original(_in);
		try
		{
			local s = ::CareerStats.Mod.Serialization.flagDeserialize(
				"CareerStats_TopTraitState", [], null, this.m.Flags);
			this.m.CareerStats_TopTraitState = (typeof s == "array") ? s : [];
		}
		catch (e)
		{
			this.m.CareerStats_TopTraitState = [];
		}
		return ret;
	};
});

::CareerStats.topTraitGetState <- function( _id )
{
	foreach (s in ::World.Statistics.m.CareerStats_TopTraitState)
		if (s.id == _id) return s;
	local ns = { id = _id, held = 0, rank = 0 };
	::World.Statistics.m.CareerStats_TopTraitState.push(ns);
	return ns;
};

::CareerStats.topTraitHas <- function( _bro )
{
	try { return _bro.getSkills().hasSkill(::CareerStats.TOP_TRAIT_ID); }
	catch (e) { return false; }
};

::CareerStats.topTraitRemove <- function( _bro )
{
	try
	{
		if (_bro.getFlags().has(::CareerStats.TOP_TRAIT_RANK_FLAG))
			_bro.getFlags().remove(::CareerStats.TOP_TRAIT_RANK_FLAG);
	}
	catch (e) {}
	try
	{
		local sk = _bro.getSkills();
		if (sk.hasSkill(::CareerStats.TOP_TRAIT_ID))
			sk.removeByID(::CareerStats.TOP_TRAIT_ID);
	}
	catch (e) {}
};

::CareerStats.topTraitApply <- function( _bro, _rank )
{
	try { _bro.getFlags().set(::CareerStats.TOP_TRAIT_RANK_FLAG, _rank); } catch (e) {}
	try
	{
		local sk = _bro.getSkills();
		local cur = sk.getSkillByID(::CareerStats.TOP_TRAIT_ID);
		if (cur != null)
		{
			local curRank = -1;
			try { curRank = cur._rank(); } catch (e) {}
			if (curRank == _rank)
			{
				try { cur.setRank(_rank); } catch (e) {}
				return;
			}
			sk.removeByID(::CareerStats.TOP_TRAIT_ID);
		}
		local t = ::new(::CareerStats.TOP_TRAIT_SCRIPT);
		if ("setRank" in t) t.setRank(_rank);
		sk.add(t);
	}
	catch (e) {}
};

::CareerStats.computeTop3 <- function()
{
	local stat = (::World != null) ? ::World.Statistics : null;
	local entries = [];

	local livingNames = {};
	try
	{
		foreach (bro in ::World.getPlayerRoster().getAll())
		{
			if (bro == null) continue;
			try { if (bro.isNull()) continue; } catch (e) {}
			try { livingNames[bro.getName()] <- true; } catch (e) {}
		}
	}
	catch (e) {}

	try
	{
		if (stat != null && ("Fallen" in stat.m))
		{
			foreach (f in stat.m.Fallen)
			{
				if (f == null || (("Name" in f) && (f.Name in livingNames))) continue;
				local rating = 0.0, dodge = 0.0;
				try
				{
					if ("CareerStats_Stats" in f && f.CareerStats_Stats != null)
					{
						rating = f.CareerStats_Stats.getSmoothedRating();
						dodge = f.CareerStats_Stats.getSmoothedDodge();
					}
				}
				catch (e) {}
				entries.push({
					id = null, alive = false,
					level   = ("Level" in f) ? f.Level : 0,
					rating  = rating, dodge = dodge,
					battles = ("Battles" in f) ? f.Battles : 0,
					kills   = ("Kills" in f) ? f.Kills : 0
				});
			}
		}
	}
	catch (e) {}

	try
	{
		if (stat != null && ("Legacy" in stat.m))
		{
			foreach (l in stat.m.Legacy)
			{
				if (l == null) continue;
				local rating = 0.0, dodge = 0.0;
				try
				{
					if ("CareerStats_Stats" in l && l.CareerStats_Stats != null)
					{
						rating = l.CareerStats_Stats.getSmoothedRating();
						dodge = l.CareerStats_Stats.getSmoothedDodge();
					}
				}
				catch (e) {}
				entries.push({
					id = null, alive = false,
					level   = ("Level" in l) ? l.Level : 0,
					rating  = rating, dodge = dodge,
					battles = ("Battles" in l) ? l.Battles : 0,
					kills   = ("Kills" in l) ? l.Kills : 0
				});
			}
		}
	}
	catch (e) {}

	try
	{
		foreach (bro in ::World.getPlayerRoster().getAll())
		{
			if (bro == null) continue;
			try { if (bro.isNull()) continue; } catch (e) {}
			if (!("CareerStats_Stats" in bro.m) || bro.m.CareerStats_Stats == null) continue;
			local st = bro.m.CareerStats_Stats;
			local id = null;
			try { id = bro.getID(); } catch (e) {}
			if (id == null) continue;
			entries.push({
				id = id, alive = true,
				level   = bro.getLevel(),
				rating  = st.getSmoothedRating(),
				dodge   = st.getSmoothedDodge(),
				battles = st.m.Stats.Battles,
				kills   = st.m.Stats.Kills
			});
		}
	}
	catch (e) {}

	local filtered = [];
	foreach (e in entries) if (e.level > 1) filtered.push(e);

	local RANKMAX = ("RANK_POINTS_MAX" in ::CareerStats) ? ::CareerStats.RANK_POINTS_MAX : 100;

	local byDmg = clone filtered;
	byDmg.sort(function( a, b ) {
		if (b.rating != a.rating) return b.rating > a.rating ? 1 : -1;
		if (b.battles != a.battles) return b.battles <=> a.battles;
		return b.kills <=> a.kills;
	});
	for (local i = 0; i < byDmg.len(); i++)
	{
		local p = RANKMAX - (i + 1);
		byDmg[i].dmgPoints <- (p > 0 ? p : 0);
	}

	local byDodge = clone filtered;
	byDodge.sort(function( a, b ) {
		if (b.dodge != a.dodge) return b.dodge > a.dodge ? 1 : -1;
		if (b.battles != a.battles) return b.battles <=> a.battles;
		return b.kills <=> a.kills;
	});
	for (local i = 0; i < byDodge.len(); i++)
	{
		local p = RANKMAX - (i + 1);
		byDodge[i].dodgePoints <- (p > 0 ? p : 0);
	}

	foreach (e in filtered) e.combined <- e.dmgPoints + e.dodgePoints;

	filtered.sort(function( a, b ) {
		if (b.combined != a.combined) return b.combined <=> a.combined;
		if (b.rating != a.rating) return b.rating > a.rating ? 1 : -1;
		if (b.battles != a.battles) return b.battles <=> a.battles;
		return b.kills <=> a.kills;
	});

	local lastRank = 0;
	local lastScore = -2147483647;
	for (local i = 0; i < filtered.len(); i++)
	{
		local sc = filtered[i].combined;
		if (sc != lastScore) { lastRank = i + 1; lastScore = sc; }
		filtered[i].rank <- lastRank;
	}

	local map = {};
	foreach (e in filtered)
	{
		if (e.rank > 3) break;
		if (e.alive && e.id != null && e.combined > 0) map[e.id] <- e.rank;
	}
	return map;
};

::CareerStats.topBroName <- function( _rank )
{
	try
	{
		local top = ::CareerStats.computeTop3();
		local wantId = null;
		foreach (id, rk in top)
			if (rk == _rank) { wantId = id; break; }
		if (wantId == null) return null;
		foreach (bro in ::World.getPlayerRoster().getAll())
		{
			if (bro == null) continue;
			try { if (bro.isNull()) continue; } catch (e) {}
			if (bro.getID() == wantId) return bro.getNameOnly();
		}
	}
	catch (e) {}
	return null;
};

::CareerStats.updateTopTraits <- function( _advance )
{
	try
	{
		if (::World == null || ::World.Statistics == null) return;
		if (!("CareerStats_TopTraitState" in ::World.Statistics.m)) return;

		local day = 0;
		try { day = ::World.getTime().Days; } catch (e) {}
		if (day < ::CareerStats.TOP_TRAIT_MIN_DAY) return;

		local top = ::CareerStats.computeTop3();
		local hold = ::CareerStats.TOP_TRAIT_HOLD_BATTLES;
		local badgeEnabled = !("Legacy" in ::getroottable()) || ::Legacy.getSetting("Legacy_TopRankBadge", true);

		local livingById = {};
		foreach (bro in ::World.getPlayerRoster().getAll())
		{
			if (bro == null) continue;
			try { if (bro.isNull()) continue; } catch (e) {}
			local id = null;
			try { id = bro.getID(); } catch (e) {}
			if (id == null) continue;
			livingById[id] <- true;

			local topRank = (id in top) ? top[id] : 0;
			local state = ::CareerStats.topTraitGetState(id);
			local flags = bro.getFlags();

			if (flags.has(::CareerStats.TOP_TRAIT_HELD_FLAG))
				state.held = flags.getAsInt(::CareerStats.TOP_TRAIT_HELD_FLAG);
			else if (state.held == 0 && ::CareerStats.topTraitHas(bro))
				state.held = hold;

			if (_advance)
			{
				if (topRank > 0) state.held += 1;
				else state.held = 0;
			}
			flags.set(::CareerStats.TOP_TRAIT_HELD_FLAG, state.held);

			local desired = (badgeEnabled && topRank > 0 && state.held >= hold) ? topRank : 0;
			if (desired > 0)
			{
				::CareerStats.topTraitApply(bro, desired);
				state.rank = desired;
			}
			else
			{
				if (state.rank > 0 || ::CareerStats.topTraitHas(bro))
					::CareerStats.topTraitRemove(bro);
				state.rank = 0;
			}
		}

		local arr = ::World.Statistics.m.CareerStats_TopTraitState;
		for (local i = arr.len() - 1; i >= 0; --i)
			if (!(arr[i].id in livingById)) arr.remove(i);
	}
	catch (e) {}
};

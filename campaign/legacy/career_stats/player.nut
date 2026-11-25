// Player hooks for Career Stats (Modern Hooks + save-bloat fix for unhired recruits).

::CareerStats.MH.hook("scripts/entity/tactical/player", function(q)
{
	q.m.CareerStats_Stats <- null;

	q.create = @(__original) function()
	{
		__original();
		this.m.CareerStats_Stats = ::new("scripts/mods/career_stats/career_stats");
		this.m.CareerStats_Stats.setPlayer(this);
	};

	q.CareerStats_updateCombatStats <- function()
	{
		if (this.m.CareerStats_Stats == null) return;
		local st = this.m.CareerStats_Stats.m.Stats;
		// Real HP damage (capped to target HP, no overkill) is accumulated per hit in actor.nut.
		st.DamageReceivedArmor += this.m.CombatStats.DamageReceivedArmor;
		st.DamageDealtArmor    += this.m.CombatStats.DamageDealtArmor;
		st.Kills               += this.m.CombatStats.Kills;
		st.MaxKillsInBattle     = ::Math.max(st.MaxKillsInBattle, this.m.CombatStats.Kills);
		++st.Battles;
	};

	q.onBeforeCombatResult = @(__original) function()
	{
		local ret = __original();
		this.CareerStats_updateCombatStats();
		if (this.m.CareerStats_Stats != null && this.m.CareerStats_Stats.m.LevelHistory.len() == 0)
		{
			try { this.m.CareerStats_Stats.recordLevelUp(::World.getTime().Days, this.getLevel()); }
			catch (e) {}
		}
		return ret;
	};

	q.updateLevel = @(__original) function()
	{
		local oldLevel = this.getLevel();
		local ret = __original();
		local newLevel = this.getLevel();
		if (newLevel > oldLevel && this.m.CareerStats_Stats != null)
		{
			try { this.m.CareerStats_Stats.recordLevelUp(::World.getTime().Days, newLevel); }
			catch (e) {}
		}
		return ret;
	};

	q.getRosterTooltip = @(__original) function()
	{
		local ret = __original();
		if (this.m.CareerStats_Stats != null)
			this.m.CareerStats_Stats.extendTooltip(ret, 6);
		return ret;
	};

	q.onDeath = @(__original) function( _killer, _skill, _tile, _fatalityType )
	{
		local lvl = 0;
		local nm = "";
		local bid = null;
		local guest = true;
		try
		{
			lvl = this.getLevel();
			nm = this.getName();
			bid = this.getID();
			guest = this.isGuest();
		}
		catch (e) {}

		local ret = __original(_killer, _skill, _tile, _fatalityType);

		if (!guest)
		{
			try
			{
				if (this.m.CareerStats_Stats != null)
					this.m.CareerStats_Stats.clearRanks();
				local roster = ::Tactical.getCasualtyRoster().getAll();
				if (roster != null && roster.len() > 0)
					roster[roster.len() - 1].m.CareerStats_Stats = this.m.CareerStats_Stats;
			}
			catch (e) {}
		}

		try
		{
			if (!this.m.IsGuest && !::Tactical.State.isScenarioMode()
				&& _fatalityType != ::Const.FatalityType.Unconscious
				&& ((_skill != null && _killer != null)
					|| _fatalityType == ::Const.FatalityType.Devoured
					|| _fatalityType == ::Const.FatalityType.Kraken))
			{
				this.CareerStats_updateCombatStats();
			}
		}
		catch (e) {}

		// Record pending death marker for Party Strength chart (validated after battle for Nine Lives).
		try
		{
			if (lvl >= 2 && !guest && ::World != null && ::World.Statistics != null
				&& ("CareerStats_DeathMarkers" in ::World.Statistics.m))
			{
				::World.Statistics.m.CareerStats_DeathMarkers.push({
					day = ::World.getTime().Days,
					name = nm,
					level = lvl,
					id = bid,
					pending = true
				});
			}
		}
		catch (e) {}

		return ret;
	};

	q.onSerialize = @(__original) function( _out )
	{
		if (this.m.CareerStats_Stats != null && this.m.CareerStats_Stats.hasData())
		{
			this.m.CareerStats_Stats.onSerialize(
				::CareerStats.Mod.Serialization.getSerializationEmulator("CareerStats", this.getFlags())
			);
		}
		else
		{
			// Scrub stale CareerStats flags left by older mod_Legacy on zero-stat unhired recruits.
			try
			{
				local flags = this.getFlags();
				local stale = [];
				foreach (k, _v in flags.m)
				{
					if (typeof k == "string" && k.find("mod_career_stats.") != null && k.find("CareerStats") != null)
						stale.push(k);
				}
				foreach (k in stale) flags.remove(k);
			}
			catch (e) {}
		}
		return __original(_out);
	};

	q.onDeserialize = @(__original) function( _in )
	{
		local ret = __original(_in);
		if (this.m.CareerStats_Stats == null)
		{
			this.m.CareerStats_Stats = ::new("scripts/mods/career_stats/career_stats");
			this.m.CareerStats_Stats.setPlayer(this);
		}
		if (::CareerStats.Mod.Serialization.isSavedVersionAtLeast("0.1.0", _in.getMetaData()))
		{
			this.m.CareerStats_Stats.onDeserialize(
				::CareerStats.Mod.Serialization.getDeserializationEmulator("CareerStats", this.getFlags())
			);
		}
		return ret;
	};
});

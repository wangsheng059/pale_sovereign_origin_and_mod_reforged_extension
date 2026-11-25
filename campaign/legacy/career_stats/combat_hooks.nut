// Consolidated lightweight combat, state, and event hooks for Career Stats.

// 1. Track active attacker/target around skill.onUse for attack-log accuracy attribution.
::CareerStats.MH.hook("scripts/skills/skill", function(q)
{
	q.onUse = @(__original) function( _user, _targetTile )
	{
		::CareerStats.ActiveUser = _user;
		::CareerStats.ActiveTarget = (_targetTile != null && _targetTile.IsOccupiedByActor) ? _targetTile.getEntity() : null;
		local ret = __original(_user, _targetTile);
		::CareerStats.ActiveUser = null;
		::CareerStats.ActiveTarget = null;
		return ret;
	};
});

// 2. Track headshots, total hits, and single-attack max damage (fixes missing assignment on MaxDamageHitpoints).
::CareerStats.MH.hook("scripts/skills/special/stats_collector", function(q)
{
	q.onTargetHit = @(__original) function( _skill, _targetEntity, _bodyPart, _damageInflictedHitpoints, _damageInflictedArmor )
	{
		local ret = __original(_skill, _targetEntity, _bodyPart, _damageInflictedHitpoints, _damageInflictedArmor);
		try
		{
			local container = this.getContainer();
			local actor = container != null ? container.getActor() : null;
			if (actor != null && ("CareerStats_Stats" in actor.m) && actor.m.CareerStats_Stats != null)
			{
				local st = actor.m.CareerStats_Stats.m.Stats;
				if (_damageInflictedArmor + _damageInflictedHitpoints > st.MaxDamageAttackArmor + st.MaxDamageAttackHitpoints)
				{
					st.MaxDamageAttackArmor = _damageInflictedArmor;
					st.MaxDamageAttackHitpoints = _damageInflictedHitpoints;
				}
				if (_damageInflictedArmor > st.MaxDamageArmor)
					st.MaxDamageArmor = _damageInflictedArmor;
				if (_damageInflictedHitpoints > st.MaxDamageHitpoints)
					st.MaxDamageHitpoints = _damageInflictedHitpoints;
				if (_bodyPart == ::Const.BodyPart.Head)
					++st.NumHeadHits;
				++st.NumHits;
			}
		}
		catch (e) {}
		return ret;
	};
});

// 3. Track Nine Lives activations and survivals (with null and field guards).
::CareerStats.MH.hook("scripts/skills/perks/perk_nine_lives", function(q)
{
	q.m.cs_Died <- false;

	local function getStats( _skill )
	{
		try
		{
			local c = _skill.getContainer();
			if (c == null) return null;
			local actor = c.getActor();
			if (actor != null && ("CareerStats_Stats" in actor.m))
				return actor.m.CareerStats_Stats;
		}
		catch (e) {}
		return null;
	}

	q.setSpent = @(__original) function( _f )
	{
		local wasSpent = this.m.IsSpent;
		__original(_f);
		if (!wasSpent && this.m.IsSpent)
		{
			local cs = getStats(this);
			if (cs != null) cs.onNineLivesUse();
		}
	};

	q.onDeath = @(__original) function( _fatalityType )
	{
		if (getStats(this) != null) this.m.cs_Died = true;
		return __original(_fatalityType);
	};

	q.onCombatStarted = @(__original) function()
	{
		this.m.cs_Died = false;
		return __original();
	};

	q.onCombatFinished = @(__original) function()
	{
		local cs = getStats(this);
		local died = false;
		try { died = this.m.cs_Died; } catch (e) {}
		if (this.m.IsSpent && cs != null && !died)
			cs.onNineLivesSave();
		return __original();
	};
});

// 4. Extend roster tooltips for tactical casualty stubs.
::CareerStats.MH.hook("scripts/entity/tactical/player_corpse_stub", function(q)
{
	q.m.CareerStats_Stats <- null;

	q.getRosterTooltip = @(__original) function()
	{
		local ret = __original();
		if (this.m.CareerStats_Stats != null)
			this.m.CareerStats_Stats.extendTooltip(ret, 6);
		return ret;
	};
});

// 5. Post-combat rank evaluation and top-3 trait progression.
::CareerStats.MH.hook("scripts/states/tactical_state", function(q)
{
	q.gatherBrothers = @(__original) function( _isVictory )
	{
		local ret = __original(_isVictory);
		::CareerStats.evaluateRanks();
		try
		{
			if ("updateTopTraits" in ::CareerStats)
				::CareerStats.updateTopTraits(true);
		}
		catch (e) {}
		return ret;
	};
});

// 6. World state load / new-campaign lifecycle guards + deferred finance history attach.
::CareerStats.MH.hook("scripts/states/world_state", function(q)
{
	q.onBeforeDeserialize = @(__original) function( _in )
	{
		::CareerStats.IsLoading = true;
		return __original(_in);
	};

	q.onDeserialize = @(__original) function( _in )
	{
		local ret = __original(_in);
		::CareerStats.IsLoading = false;
		try
		{
			if ("_PendingFinanceHistory" in ::CareerStats
				&& ::World != null && ("Assets" in ::World) && ::World.Assets != null)
			{
				::World.Assets.m.CareerStats_FinanceHistory = ::CareerStats._PendingFinanceHistory;
				delete ::CareerStats._PendingFinanceHistory;
			}
		}
		catch (e) {}
		::CareerStats.evaluateRanks();

		// Remove any obsolete legacy_grave_location entities deserialized from pre-refactor saves.
		try
		{
			if (::World != null && ("EntityManager" in ::World) && ::World.EntityManager != null)
			{
				local toRemove = [];
				foreach (loc in ::World.EntityManager.getLocations())
				{
					if (loc != null && loc.getTypeID() == "location.legacy_grave" && loc.isAlive())
						toRemove.push(loc);
				}
				foreach (loc in toRemove) loc.die();
			}
		}
		catch (e) {}

		return ret;
	};

	q.startNewCampaign = @(__original) function()
	{
		::CareerStats.IsLoading = true;
		local ret = __original();
		::CareerStats.IsLoading = false;
		::CareerStats.evaluateRanks();
		return ret;
	};
});

// 7. Tag deserting brothers before roster.remove fires.
::CareerStats.MH.hook("scripts/events/events/desertion_event", function(q)
{
	q.setDeserter = @(__original) function( _d )
	{
		::CareerStats.PendingDeparture = "Deserted";
		return __original(_d);
	};
});

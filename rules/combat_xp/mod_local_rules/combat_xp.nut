// Limit the large-company bonus to scalable battle XP.
::BGP.CombatXP <- {
	State = null,
	Deployed = 0,

	function clear()
	{
		this.State = null;
		this.Deployed = 0;
	},

	function record( _manager )
	{
		if (::Tactical.State == null || ::Tactical.State.isScenarioMode())
			return;

		local roster = {};
		foreach (brother in ::World.getPlayerRoster().getAll())
			roster[brother.getID()] <- true;

		foreach (actor in _manager.getInstancesOfFaction(::Const.Faction.Player))
		{
			if (actor.isPlacedOnMap() && actor.getID() in roster)
				this.Deployed++;
		}
		this.State = ::MSU.asWeakTableRef(::Tactical.State);
	},

	function apply( _xp, _scale )
	{
		if (!::BGP.getSetting("BGP_LargeCompanyXP", true))
			return _xp;
		if (_scale && _xp > 0 && this.Deployed > 12
			&& this.State != null && !::MSU.isNull(this.State)
			&& ::Tactical.isActive() && ::MSU.isEqual(this.State, ::Tactical.State))
			return _xp * (this.Deployed / 12.0);
		return _xp;
	}
};

::BGP.HooksMod.hook("scripts/entity/tactical/tactical_entity_manager", function(q)
{
	q.spawn = @(__original) function( _properties )
	{
		::BGP.CombatXP.clear();
		local ret = __original(_properties);
		::BGP.CombatXP.record(this);
		return ret;
	};
});

::BGP.HooksMod.hook("scripts/states/tactical_state", function(q)
{
	q.onBattleEnded = @(__original) function(...)
	{
		local args = [this];
		args.extend(vargv);
		local ret = __original.acall(args);
		::BGP.CombatXP.clear();
		return ret;
	};
});

::BGP.HooksMod.hook("scripts/entity/tactical/player", function(q)
{
	q.addXP = @(__original) function( _xp, _scale = true )
	{
		return __original(::BGP.CombatXP.apply(_xp, _scale), _scale);
	};
});

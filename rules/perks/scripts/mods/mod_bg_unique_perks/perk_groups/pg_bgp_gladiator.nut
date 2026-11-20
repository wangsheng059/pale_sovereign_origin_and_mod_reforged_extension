this.pg_bgp_gladiator <- ::inherit(::DynamicPerks.Class.PerkGroup, {
	m = {},
	function create()
	{
		this.m.ID = "pg.bgp_gladiator";
		this.m.Name = "斗技场";
		this.m.Description = "角斗士专属特技组。";
		this.m.Icon = "ui/perk_groups/bgp_gladiator.png";
		this.m.Tree = [
			[],
			["perk.rf_vigorous_assault"],
			["perk.bgp_crowd_favorite"],
			["perk.rf_the_rush_of_battle"],
			[],
			["perk.rf_second_wind"],
			["perk.bgp_arena_veteran"]
		];
	}

	function getSelfMultiplier( _perkTree )
	{
		return 0;
	}
});

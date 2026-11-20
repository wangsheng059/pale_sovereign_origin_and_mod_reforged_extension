this.pg_bgp_knight <- ::inherit(::DynamicPerks.Class.PerkGroup, {
	m = {},
	function create()
	{
		this.m.ID = "pg.bgp_knight";
		this.m.Name = "骑士";
		this.m.Description = "流浪骑士专属特技组。";
		this.m.Icon = "ui/perk_groups/bgp_knight.png";
		this.m.Tree = [
			["perk.rf_menacing"],
			[],
			["perk.bgp_iron_juggernaut"],
			[],
			["perk.rf_vanquisher"],
			["perk.bgp_armor_breaker"],
			["perk.bgp_devastating_blow"]
		];
	}

	function getSelfMultiplier( _perkTree )
	{
		return 0;
	}
});

this.pg_bgp_beastmaster <- ::inherit(::DynamicPerks.Class.PerkGroup, {
	m = {},
	function create()
	{
		this.m.ID = "pg.bgp_beastmaster";
		this.m.Name = "驯兽";
		this.m.Description = "驯兽师专属特技组。";
		this.m.Icon = "ui/perk_groups/bgp_beastmaster.png";
		this.m.Tree = [
			["perk.bgp_pack_leader"],
			["perk.rf_strength_in_numbers"],
			["perk.bgp_hunting_fever"],
			[],
			["perk.bgp_feint"],
			["perk.bgp_shared_hatred"],
			["perk.bgp_hunting_hour"]
		];
	}

	function getSelfMultiplier( _perkTree )
	{
		return 0;
	}
});

this.pg_bgp_assassin <- ::inherit(::DynamicPerks.Class.PerkGroup, {
	m = {},
	function create()
	{
		this.m.ID = "pg.bgp_assassin";
		this.m.Name = "暗杀";
		this.m.Description = "刺客专属特技组。";
		this.m.Icon = "ui/perk_groups/bgp_assassin.png";
		this.m.Tree = [
			["perk.nine_lives"],
			["perk.rf_cheap_trick"],
			["perk.bgp_one_strike"],
			["perk.rf_ghostlike"],
			[],
			[],
			["perk.bgp_vanish"]
		];
	}

	function getSelfMultiplier( _perkTree )
	{
		return 0;
	}

	// 沿用被替换掉的重铸“恶棍”组的倾向：必出匕首和轻甲
	function getPerkGroupMultiplier( _groupID, _perkTree )
	{
		switch (_groupID)
		{
			case "pg.rf_dagger":
			case "pg.rf_light_armor":
				return -1;
		}
	}
});

this.pg_bgp_oathtaker <- ::inherit(::DynamicPerks.Class.PerkGroup, {
	m = {},
	function create()
	{
		this.m.ID = "pg.bgp_oathtaker";
		this.m.Name = "誓约";
		this.m.Description = "老执誓者专属特技组。";
		this.m.Icon = "ui/perk_groups/bgp_oathtaker.png";
		this.m.Tree = [
			["perk.rf_survival_instinct"],
			[],
			["perk.fortified_mind"],
			["perk.bgp_ascetic_discipline"],
			["perk.rf_vengeful_spite"],
			[],
			["perk.bgp_undying_saint"]
		];
	}

	function getSelfMultiplier( _perkTree )
	{
		return 0;
	}

	// 沿用被替换掉的重铸“士兵”组的倾向
	function getPerkGroupMultiplier( _groupID, _perkTree )
	{
		switch (_groupID)
		{
			case "pg.rf_trained":
			case "pg.special.rf_professional":
				return -1;
			case "pg.special.rf_back_to_basics":
				return 2.5;
		}
	}
});

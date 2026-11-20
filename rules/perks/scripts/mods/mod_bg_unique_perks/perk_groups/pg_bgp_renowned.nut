this.pg_bgp_renowned <- ::inherit(::DynamicPerks.Class.PerkGroup, {
	m = {},
	function create()
	{
		this.m.ID = "pg.bgp_renowned";
		this.m.Name = "成名剑师";
		this.m.Description = "成名剑师专属特技组。";
		this.m.Icon = "ui/perk_groups/bgp_renowned.png";
		this.m.Tree = [
			["perk.rf_exploit_opening"],
			[],
			["perk.bgp_graceful_evasion"],
			[],
			["perk.rf_rebuke", "perk.rf_pattern_recognition"],
			[],
			["perk.bgp_sword_saint"]
		];
	}

	function getSelfMultiplier( _perkTree )
	{
		return 0;
	}

	// 沿用重铸“士兵”特技组的倾向（被本组替换掉了）
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

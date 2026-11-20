this.pg_bgp_chosen <- ::inherit(::DynamicPerks.Class.PerkGroup, {
	m = {},
	function create()
	{
		this.m.ID = "pg.bgp_chosen";
		this.m.Name = "神选";
		this.m.Description = "神选者专属特技组。";
		this.m.Icon = "ui/perk_groups/bgp_chosen.png";
		this.m.Tree = [
			[],
			["perk.rf_bestial_vigor"],
			["perk.bgp_blood_sacrifice"],
			[],
			["perk.rf_savage_strength"],
			["perk.rf_feral_rage"],
			["perk.bgp_gods_gaze"]
		];
	}

	function getSelfMultiplier( _perkTree )
	{
		return 0;
	}

	// 和重铸“野性”特技组相同：不出远程、盾、领袖等文明类特技组
	function getPerkGroupMultiplier( _groupID, _perkTree )
	{
		switch (_groupID)
		{
			case "pg.special.rf_leadership":
			case "pg.rf_tactician":
			case "pg.rf_trained":
			case "pg.rf_bow":
			case "pg.rf_crossbow":
			case "pg.rf_dagger":
			case "pg.rf_ranged":
			case "pg.rf_shield":
			case "pg.special.rf_back_to_basics":
			case "pg.special.rf_discovered_talent":
			case "pg.special.rf_gifted":
			case "pg.special.rf_student":
				return 0;
			case "pg.rf_spear":
				return 0.8;
			case "pg.rf_sword":
				return 0.9;
		}
	}
});

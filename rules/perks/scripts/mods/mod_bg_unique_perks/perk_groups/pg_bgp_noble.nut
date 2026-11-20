this.pg_bgp_noble <- ::inherit(::DynamicPerks.Class.PerkGroup, {
	m = {},
	function create()
	{
		this.m.ID = "pg.bgp_noble";
		this.m.Name = "统帅";
		this.m.Description = "统帅专属特技组。";
		this.m.Icon = "ui/perk_groups/bgp_noble.png";
		this.m.Tree = [
			["perk.rf_family_pride"],
			["perk.rally_the_troops"],
			["perk.bgp_discerning"],
			["perk.bgp_iron_orders"],
			["perk.bgp_flaws_to_fangs"],
			["perk.bgp_reward_punish", "perk.bgp_abyssal_resonance"],
			["perk.bgp_art_of_war", "perk.bgp_one_flesh", "perk.bgp_bestow"]
		];
	}

	function getSelfMultiplier( _perkTree )
	{
		return 0;
	}

	// 沿用重铸“贵族”特技组的倾向（被本组替换掉了）
	function getPerkGroupMultiplier( _groupID, _perkTree )
	{
		switch (_groupID)
		{
			case "pg.rf_tactician":
				return 2;
			case "pg.rf_trained":
				return 1.5;
		}
	}
});

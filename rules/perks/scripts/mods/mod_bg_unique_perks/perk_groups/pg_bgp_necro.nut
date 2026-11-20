this.pg_bgp_necro <- ::inherit(::DynamicPerks.Class.PerkGroup, {
	m = {},
	function create()
	{
		this.m.ID = "pg.bgp_necro";
		this.m.Name = "死灵法师";
		this.m.Description = "死灵法师专属特技组。";
		this.m.Icon = "ui/perk_groups/bgp_necro.png";
		this.m.Tree = [
			["perk.bgp_necro_arts"],
			["perk.bgp_necro_possess"],
			["perk.bgp_necro_regeneration"],
			["perk.bgp_necro_mastery", "perk.bgp_necro_mind_meld"],
			["perk.bgp_necro_blood_sucking"],
			["perk.bgp_necro_infusion", "perk.bgp_necro_flesh_of_iron"],
			["perk.bgp_corpse_explosion"]
		];
	}

	function getSelfMultiplier( _perkTree )
	{
		return 0;
	}
});

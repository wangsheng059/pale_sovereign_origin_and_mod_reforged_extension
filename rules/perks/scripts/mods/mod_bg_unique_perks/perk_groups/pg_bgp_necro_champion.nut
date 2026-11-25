// 1.6.0 死灵法师专属组之一：亡灵冠军（强化单个亡灵，尤其是死灵宠物，以及死灵法师自身）
// 和“亡灵天灾”互斥（特技层面，见 perk_defs_4.nut 的 verifyPrerequisites）；死灵精通两组共用。第 1 层留给以后的新特技。
this.pg_bgp_necro_champion <- ::inherit(::DynamicPerks.Class.PerkGroup, {
	m = {},
	function create()
	{
		this.m.ID = "pg.bgp_necro_champion";
		this.m.Name = "亡灵冠军";
		this.m.Description = "亡灵法师专属特技组：强化单个亡灵（尤其是死灵宠物）和亡灵法师自身。与“亡灵天灾”互斥。";
		this.m.Icon = "ui/perk_groups/bgp_necro_champion.png";
		this.m.Tree = [
			[],
			["perk.bgp_necro_possess"],
			["perk.bgp_necro_flesh_reforge"],
			["perk.bgp_necro_mastery"],
			["perk.bgp_necro_mind_meld"],
			["perk.bgp_necro_infusion"],
			["perk.bgp_necro_undying_champion", "perk.bgp_necro_grandmaster"]
		];
	}

	function getSelfMultiplier( _perkTree )
	{
		return 0;
	}
});

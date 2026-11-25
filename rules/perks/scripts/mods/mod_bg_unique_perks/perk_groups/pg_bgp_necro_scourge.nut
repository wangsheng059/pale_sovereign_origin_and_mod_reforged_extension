// 1.6.0 死灵法师专属组之一：亡灵天灾（强化复活亡灵的能力，偏群体数量）
// 1.6.1 第 5 层嗜血者换成腐毒蝇群（嗜血者特技保留，只给老角色）。
// 和“亡灵冠军”互斥（特技层面，见 perk_defs_4.nut 的 verifyPrerequisites）；死灵精通两组共用。第 1 层留给以后的新特技。
this.pg_bgp_necro_scourge <- ::inherit(::DynamicPerks.Class.PerkGroup, {
	m = {},
	function create()
	{
		this.m.ID = "pg.bgp_necro_scourge";
		this.m.Name = "亡灵天灾";
		this.m.Description = "亡灵法师专属特技组：强化复活亡灵的能力，偏向群体数量。与“亡灵冠军”互斥。";
		this.m.Icon = "ui/perk_groups/bgp_necro_scourge.png";
		this.m.Tree = [
			[],
			["perk.bgp_necro_flesh_of_iron"],
			["perk.bgp_necro_regeneration"],
			["perk.bgp_necro_mastery"],
			["perk.bgp_necro_fly_swarm"],
			["perk.bgp_necro_curse_of_ages"],
			["perk.bgp_corpse_explosion", "perk.bgp_necro_grandmaster"]
		];
	}

	function getSelfMultiplier( _perkTree )
	{
		return 0;
	}
});

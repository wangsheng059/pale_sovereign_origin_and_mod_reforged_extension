// 不死再生：复活的单位每回合开始时回复 10 生命（在死灵仆从效果里处理）
this.perk_bgp_necro_regeneration <- ::inherit("scripts/skills/skill", {
	m = {},
	function create()
	{
		this.m.ID = "perk.bgp_necro_regeneration";
		this.m.Name = ::BGP.PerkNames.NecroRegeneration;
		this.m.Description = ::BGP.PerkDescriptions.NecroRegeneration;
		this.m.Icon = "ui/perks/perk_bgp_necro_regeneration.png";
		this.m.Type = ::Const.SkillType.Perk;
		this.m.Order = ::Const.SkillOrder.Perk;
	}
});

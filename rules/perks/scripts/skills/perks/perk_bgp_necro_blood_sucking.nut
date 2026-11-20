// 嗜血者：复活的单位获得原版吸血鬼的吸血能力（在死灵仆从效果里处理）
this.perk_bgp_necro_blood_sucking <- ::inherit("scripts/skills/skill", {
	m = {},
	function create()
	{
		this.m.ID = "perk.bgp_necro_blood_sucking";
		this.m.Name = ::BGP.PerkNames.NecroBloodSucking;
		this.m.Description = ::BGP.PerkDescriptions.NecroBloodSucking;
		this.m.Icon = "ui/perks/perk_bgp_necro_blood_sucking.png";
		this.m.Type = ::Const.SkillType.Perk;
		this.m.Order = ::Const.SkillOrder.Perk;
	}
});

// 钢铁之躯：复活时护甲恢复 30%；同时有不死再生时每回合再恢复 7%（在死灵仆从效果里处理）
this.perk_bgp_necro_flesh_of_iron <- ::inherit("scripts/skills/skill", {
	m = {},
	function create()
	{
		this.m.ID = "perk.bgp_necro_flesh_of_iron";
		this.m.Name = ::BGP.PerkNames.NecroFleshOfIron;
		this.m.Description = ::BGP.PerkDescriptions.NecroFleshOfIron;
		this.m.Icon = "ui/perks/perk_bgp_necro_flesh_of_iron.png";
		this.m.Type = ::Const.SkillType.Perk;
		this.m.Order = ::Const.SkillOrder.Perk;
	}
});

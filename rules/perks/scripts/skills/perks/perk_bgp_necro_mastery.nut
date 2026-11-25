// 死灵精通：本组主动技能（复活死者、支配亡灵、死灵灌注、尸爆等）-1 行动点、疲劳 -25%（在各技能的 onAfterUpdate 里处理）
this.perk_bgp_necro_mastery <- ::inherit("scripts/skills/skill", {
	m = {},
	function create()
	{
		this.m.ID = "perk.bgp_necro_mastery";
		this.m.Name = ::BGP.PerkNames.NecroMastery;
		this.m.Description = ::BGP.PerkDescriptions.NecroMastery;
		this.m.Icon = "ui/perks/perk_bgp_necro_mastery.png";
		this.m.Type = ::Const.SkillType.Perk;
		this.m.Order = ::Const.SkillOrder.Perk;
	}
});

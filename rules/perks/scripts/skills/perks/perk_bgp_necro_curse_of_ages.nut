// 1.6.0 亡灵天灾 6 层：岁月诅咒 —— 解锁“岁月诅咒”主动技能
this.perk_bgp_necro_curse_of_ages <- ::inherit("scripts/skills/skill", {
	m = {},
	function create()
	{
		this.m.ID = "perk.bgp_necro_curse_of_ages";
		this.m.Name = ::BGP.PerkNames.NecroCurseOfAges;
		this.m.Description = ::BGP.PerkDescriptions.NecroCurseOfAges;
		this.m.Icon = "ui/perks/perk_bgp_necro_curse_of_ages.png";
		this.m.Type = ::Const.SkillType.Perk;
		this.m.Order = ::Const.SkillOrder.Perk;
	}

	function onAdded()
	{
		if (!this.getContainer().hasSkill("actives.bgp_necro_curse_of_ages"))
			this.getContainer().add(::new("scripts/skills/actives/bgp_necro_curse_of_ages_skill"));
	}

	function onRemoved()
	{
		this.getContainer().removeByID("actives.bgp_necro_curse_of_ages");
	}
});

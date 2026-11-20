// 识骨相人：解锁主动技能“识骨相人”
this.perk_bgp_discerning <- ::inherit("scripts/skills/skill", {
	m = {},
	function create()
	{
		this.m.ID = "perk.bgp_discerning";
		this.m.Name = ::BGP.PerkNames.Discerning;
		this.m.Description = ::BGP.PerkDescriptions.Discerning;
		this.m.Icon = "ui/perks/perk_bgp_discerning.png";
		this.m.Type = ::Const.SkillType.Perk;
		this.m.Order = ::Const.SkillOrder.Perk;
	}

	function onAdded()
	{
		if (!this.getContainer().hasSkill("actives.bgp_discerning"))
			this.getContainer().add(::new("scripts/skills/actives/bgp_discerning_skill"));
	}

	function onRemoved()
	{
		this.getContainer().removeByID("actives.bgp_discerning");
	}
});

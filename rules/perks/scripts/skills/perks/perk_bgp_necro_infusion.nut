// 死灵灌注：解锁“死灵灌注”主动技能
this.perk_bgp_necro_infusion <- ::inherit("scripts/skills/skill", {
	m = {},
	function create()
	{
		this.m.ID = "perk.bgp_necro_infusion";
		this.m.Name = ::BGP.PerkNames.NecroInfusion;
		this.m.Description = ::BGP.PerkDescriptions.NecroInfusion;
		this.m.Icon = "ui/perks/perk_bgp_necro_infusion.png";
		this.m.Type = ::Const.SkillType.Perk;
		this.m.Order = ::Const.SkillOrder.Perk;
	}

	function onAdded()
	{
		if (!this.getContainer().hasSkill("actives.bgp_necro_infusion"))
			this.getContainer().add(::new("scripts/skills/actives/bgp_necro_infusion_skill"));
	}

	function onRemoved()
	{
		this.getContainer().removeByID("actives.bgp_necro_infusion");
	}
});

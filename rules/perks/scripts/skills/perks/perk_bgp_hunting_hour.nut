this.perk_bgp_hunting_hour <- ::inherit("scripts/skills/skill", {
	m = {},
	function create()
	{
		this.m.ID = "perk.bgp_hunting_hour";
		this.m.Name = ::BGP.PerkNames.HuntingHour;
		this.m.Description = ::BGP.PerkDescriptions.HuntingHour;
		this.m.Icon = "ui/perks/perk_bgp_hunting_hour.png";
		this.m.Type = ::Const.SkillType.Perk;
		this.m.Order = ::Const.SkillOrder.Perk;
	}

	function onAdded()
	{
		if (!this.getContainer().hasSkill("actives.bgp_hunting_hour"))
			this.getContainer().add(::new("scripts/skills/actives/bgp_hunting_hour_skill"));
	}

	function onRemoved()
	{
		this.getContainer().removeByID("actives.bgp_hunting_hour");
	}
});

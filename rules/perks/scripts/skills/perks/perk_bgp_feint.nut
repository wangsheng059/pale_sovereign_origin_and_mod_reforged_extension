this.perk_bgp_feint <- ::inherit("scripts/skills/skill", {
	m = {},
	function create()
	{
		this.m.ID = "perk.bgp_feint";
		this.m.Name = ::BGP.PerkNames.Feint;
		this.m.Description = ::BGP.PerkDescriptions.Feint;
		this.m.Icon = "ui/perks/perk_bgp_feint.png";
		this.m.Type = ::Const.SkillType.Perk;
		this.m.Order = ::Const.SkillOrder.Perk;
	}

	function onAdded()
	{
		if (!this.getContainer().hasSkill("actives.bgp_feint"))
			this.getContainer().add(::new("scripts/skills/actives/bgp_feint_skill"));
	}

	function onRemoved()
	{
		this.getContainer().removeByID("actives.bgp_feint");
	}
});

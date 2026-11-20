this.perk_bgp_vanish <- ::inherit("scripts/skills/skill", {
	m = {},
	function create()
	{
		this.m.ID = "perk.bgp_vanish";
		this.m.Name = ::BGP.PerkNames.Vanish;
		this.m.Description = ::BGP.PerkDescriptions.Vanish;
		this.m.Icon = "ui/perks/perk_bgp_vanish.png";
		this.m.Type = ::Const.SkillType.Perk;
		this.m.Order = ::Const.SkillOrder.Perk;
	}

	function onTargetKilled( _targetEntity, _skill )
	{
		local actor = this.getContainer().getActor();
		if (_targetEntity == null || _targetEntity.isAlliedWith(actor))
			return;

		local fx = this.getContainer().getSkillByID("effects.bgp_vanish");
		if (fx == null)
			this.getContainer().add(::new("scripts/skills/effects/bgp_vanish_effect"));
		else
			fx.refresh();
		::BGP.log(actor, "隐没于阴影之中");
	}
});

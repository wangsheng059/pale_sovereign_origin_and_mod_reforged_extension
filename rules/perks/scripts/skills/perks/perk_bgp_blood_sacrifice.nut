this.perk_bgp_blood_sacrifice <- ::inherit("scripts/skills/skill", {
	m = {
		Stacks = 0,
		DamagePerStack = 0.15
	},
	function create()
	{
		this.m.ID = "perk.bgp_blood_sacrifice";
		this.m.Name = ::BGP.PerkNames.BloodSacrifice;
		this.m.Description = ::BGP.PerkDescriptions.BloodSacrifice;
		this.m.Icon = "ui/perks/perk_bgp_blood_sacrifice.png";
		this.m.Type = ::Const.SkillType.Perk | ::Const.SkillType.StatusEffect;
		this.m.Order = ::Const.SkillOrder.Perk;
	}

	function isHidden()
	{
		return this.m.Stacks == 0;
	}

	function getName()
	{
		return this.m.Stacks > 1 ? this.m.Name + " (x" + this.m.Stacks + ")" : this.m.Name;
	}

	function getDescription()
	{
		return "每一条性命，都是献给诸神的祭品。";
	}

	function getTooltip()
	{
		local ret = this.skill.getTooltip();
		ret.push({
			id = 10,
			type = "text",
			icon = "ui/icons/regular_damage.png",
			text = "造成的伤害 " + ::MSU.Text.colorizeMult(1.0 + this.m.Stacks * this.m.DamagePerStack)
		});
		return ret;
	}

	function onUpdate( _properties )
	{
		if (this.m.Stacks > 0)
			_properties.DamageTotalMult *= 1.0 + this.m.Stacks * this.m.DamagePerStack;
	}

	function onTargetKilled( _targetEntity, _skill )
	{
		local actor = this.getContainer().getActor();
		if (_targetEntity == null || _targetEntity.isAlliedWith(actor))
			return;

		this.m.Stacks++;
		::BGP.log(actor, "献上血祭，伤害提高到 " + ::MSU.Text.colorizeMult(1.0 + this.m.Stacks * this.m.DamagePerStack));
	}

	function onCombatStarted()
	{
		this.m.Stacks = 0;
	}

	function onCombatFinished()
	{
		this.skill.onCombatFinished();
		this.m.Stacks = 0;
	}
});

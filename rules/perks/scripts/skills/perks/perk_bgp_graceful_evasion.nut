this.perk_bgp_graceful_evasion <- ::inherit("scripts/skills/skill", {
	m = {
		Stacks = 0,
		FatigueRecovered = 3,
		InitiativePerStack = 5
	},
	function create()
	{
		this.m.ID = "perk.bgp_graceful_evasion";
		this.m.Name = ::BGP.PerkNames.GracefulEvasion;
		this.m.Description = ::BGP.PerkDescriptions.GracefulEvasion;
		this.m.Icon = "ui/perks/perk_bgp_graceful_evasion.png";
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
		return "对手的每一次落空，都让你更加从容。";
	}

	function getTooltip()
	{
		local ret = this.skill.getTooltip();
		ret.push({
			id = 10,
			type = "text",
			icon = "ui/icons/initiative.png",
			text = "主动值 " + ::MSU.Text.colorPositive("+" + (this.m.Stacks * this.m.InitiativePerStack))
		});
		return ret;
	}

	function onMissed( _attacker, _skill )
	{
		if (_skill == null || !_skill.isAttack())
			return;
		if (_attacker != null && _attacker.isAlliedWith(this.getContainer().getActor()))
			return;

		local actor = this.getContainer().getActor();
		::BGP.reduceFatigue(actor, this.m.FatigueRecovered);
		this.m.Stacks++;
		actor.setDirty(true);
	}

	function onUpdate( _properties )
	{
		_properties.Initiative += this.m.Stacks * this.m.InitiativePerStack;
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

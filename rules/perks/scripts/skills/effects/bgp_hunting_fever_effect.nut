this.bgp_hunting_fever_effect <- ::inherit("scripts/skills/skill", {
	m = {
		Stacks = 0,
		MaxStacks = 3,
		DamagePerStack = 0.05,
		InitiativePerStack = 15
	},
	function create()
	{
		this.m.ID = "effects.bgp_hunting_fever";
		this.m.Name = ::BGP.PerkNames.HuntingFever;
		this.m.Icon = "ui/perks/perk_bgp_hunting_fever.png";
		this.m.Type = ::Const.SkillType.StatusEffect;
		this.m.Order = ::Const.SkillOrder.Perk;
		this.m.IsActive = false;
		this.m.IsRemovedAfterBattle = true;
		this.m.IsSerialized = false;
	}

	function getName()
	{
		return this.m.Stacks > 1 ? this.m.Name + " (x" + this.m.Stacks + ")" : this.m.Name;
	}

	function getDescription()
	{
		return "血腥味让兽群越发狂热。";
	}

	function getTooltip()
	{
		local ret = this.skill.getTooltip();
		ret.extend([
			{ id = 10, type = "text", icon = "ui/icons/regular_damage.png", text = "伤害 " + ::MSU.Text.colorizeMult(1.0 + this.m.Stacks * this.m.DamagePerStack) },
			{ id = 11, type = "text", icon = "ui/icons/initiative.png", text = "主动值 " + ::MSU.Text.colorPositive("+" + (this.m.Stacks * this.m.InitiativePerStack)) }
		]);
		return ret;
	}

	function addStack()
	{
		if (this.m.Stacks >= this.m.MaxStacks)
			return;
		this.m.Stacks++;
		this.getContainer().update();
	}

	function onUpdate( _properties )
	{
		_properties.DamageTotalMult *= 1.0 + this.m.Stacks * this.m.DamagePerStack;
		_properties.Initiative += this.m.Stacks * this.m.InitiativePerStack;
	}
});

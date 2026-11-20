this.bgp_shared_hatred_effect <- ::inherit("scripts/skills/skill", {
	m = {
		Stacks = 0,
		MaxStacks = 3,
		DamagePerStack = 0.08
	},
	function create()
	{
		this.m.ID = "effects.bgp_shared_hatred";
		this.m.Name = "同仇";
		this.m.Icon = "ui/perks/perk_bgp_shared_hatred.png";
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
		return "驯兽师与宠物同仇敌忾。";
	}

	function getTooltip()
	{
		local ret = this.skill.getTooltip();
		ret.push({ id = 10, type = "text", icon = "ui/icons/regular_damage.png", text = "伤害 " + ::MSU.Text.colorizeMult(1.0 + this.m.Stacks * this.m.DamagePerStack) });
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
	}
});

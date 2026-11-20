// 军令如山：持续第 1、2 回合（第 2 回合结束时移除）
this.bgp_iron_orders_effect <- ::inherit("scripts/skills/skill", {
	m = {
		Initiative = 25,
		Skill = 5,
		AppliedRound = 0
	},
	function create()
	{
		this.m.ID = "effects.bgp_iron_orders";
		this.m.Name = "军令";
		this.m.Icon = "ui/perks/perk_bgp_iron_orders.png";
		this.m.Type = ::Const.SkillType.StatusEffect;
		this.m.Order = ::Const.SkillOrder.Perk;
		this.m.IsActive = false;
		this.m.IsRemovedAfterBattle = true;
		this.m.IsSerialized = false;
	}

	function getDescription()
	{
		return "军令既出，不容迟疑。持续到第 2 回合结束。";
	}

	function getTooltip()
	{
		local ret = this.skill.getTooltip();
		ret.extend([
			{ id = 10, type = "text", icon = "ui/icons/initiative.png", text = "主动值 " + ::MSU.Text.colorPositive("+" + this.m.Initiative) },
			{ id = 11, type = "text", icon = "ui/icons/melee_skill.png", text = "近战技能 " + ::MSU.Text.colorPositive("+" + this.m.Skill) },
			{ id = 12, type = "text", icon = "ui/icons/ranged_skill.png", text = "远程技能 " + ::MSU.Text.colorPositive("+" + this.m.Skill) }
		]);
		return ret;
	}

	function onAdded()
	{
		this.m.AppliedRound = ::Math.max(1, ::BGP.getRound());
	}

	function onUpdate( _properties )
	{
		_properties.Initiative += this.m.Initiative;
		_properties.MeleeSkill += this.m.Skill;
		_properties.RangedSkill += this.m.Skill;
	}

	function onTurnEnd()
	{
		if (::BGP.getRound() > this.m.AppliedRound)
			this.removeSelf();
	}
});

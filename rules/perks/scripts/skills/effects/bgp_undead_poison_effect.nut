// 1.5.2 尸毒（死灵宠物特质“中毒”施加）：行动点 -2、造成的伤害 -15%，持续 2 回合（目标自己的回合结束时减 1）
this.bgp_undead_poison_effect <- ::inherit("scripts/skills/skill", {
	m = {
		TurnsLeft = 2
	},
	function create()
	{
		this.m.ID = "effects.bgp_undead_poison";
		this.m.Name = "尸毒";
		this.m.Description = "尸毒在血管里蔓延，四肢发沉，出手无力。";
		this.m.Icon = "ui/perks/bgp_quirk_plague.png";
		this.m.IconMini = "status_effect_54_mini";
		this.m.Overlay = "status_effect_54";
		this.m.Type = ::Const.SkillType.StatusEffect;
		this.m.IsActive = false;
		this.m.IsStacking = false;
		this.m.IsRemovedAfterBattle = true;
		this.m.IsSerialized = false;
	}

	function getTooltip()
	{
		return [
			{ id = 1, type = "title", text = this.getName() },
			{ id = 2, type = "description", text = this.getDescription() },
			{ id = 10, type = "text", icon = "ui/icons/action_points.png", text = ::MSU.Text.colorNegative("-2") + " 行动点" },
			{ id = 11, type = "text", icon = "ui/icons/regular_damage.png", text = "造成的伤害 " + ::MSU.Text.colorNegative("-15%") },
			{ id = 12, type = "text", icon = "ui/icons/special.png", text = "还剩 " + this.m.TurnsLeft + " 回合" }
		];
	}

	function onUpdate( _properties )
	{
		_properties.ActionPoints -= 2;
		_properties.DamageTotalMult *= 0.85;
	}

	function onTurnEnd()
	{
		this.m.TurnsLeft -= 1;
		if (this.m.TurnsLeft <= 0)
			this.removeSelf();
	}
});

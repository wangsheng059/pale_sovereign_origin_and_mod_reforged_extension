// 冥府活力：行动点 +4、主动值 +75、移动 AP 消耗 -1，持续自身 2 个回合（亡灵法术大师 3 个回合）
this.bgp_necro_infusion_effect <- ::inherit("scripts/skills/skill", {
	m = {
		TurnsLeft = 2,
		Bonus = 4,
		InitBonus = 75
	},
	function create()
	{
		this.m.ID = "effects.bgp_necro_infusion";
		this.m.Name = "冥府活力";
		this.m.Description = "冥府的阴冷死气涌动在这具躯体中，令它动作迅猛、步履如风。";
		this.m.Icon = "ui/perks/perk_bgp_necro_infusion.png";
		this.m.IconMini = "";
		this.m.Type = ::Const.SkillType.StatusEffect;
		this.m.Order = ::Const.SkillOrder.Last;
		this.m.IsActive = false;
		this.m.IsStacking = false;
		this.m.IsRemovedAfterBattle = true;
		this.m.IsSerialized = false;
	}

	function refresh( _turns = 2 )
	{
		this.m.TurnsLeft = _turns;
	}

	function getTooltip()
	{
		local ret = this.skill.getTooltip();
		ret.push({ id = 10, type = "text", icon = "ui/icons/action_points.png", text = "行动点数 " + ::MSU.Text.colorPositive("+" + this.m.Bonus) });
		ret.push({ id = 11, type = "text", icon = "ui/icons/initiative.png", text = "主动值 " + ::MSU.Text.colorPositive("+" + this.m.InitBonus) });
		ret.push({ id = 12, type = "text", icon = "ui/icons/special.png", text = "移动时行动点消耗 " + ::MSU.Text.colorPositive("-1") + "（最少 1）" });
		ret.push({ id = 13, type = "text", icon = "ui/icons/special.png", text = "还剩 " + this.m.TurnsLeft + " 个回合" });
		return ret;
	}

	function onUpdate( _properties )
	{
		_properties.ActionPoints += this.m.Bonus;
		_properties.Initiative += this.m.InitBonus;
	}

	function onAfterUpdate( _properties )
	{
		_properties.MovementAPCostAdditional -= 1;
	}

	function onTurnEnd()
	{
		this.m.TurnsLeft--;
		if (this.m.TurnsLeft <= 0)
			this.removeSelf();
	}
});

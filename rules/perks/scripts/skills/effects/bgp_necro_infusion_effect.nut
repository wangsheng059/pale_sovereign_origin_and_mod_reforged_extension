// 死灵灌注：行动点上限 +4，持续自身 2 个回合（每个回合结束时减 1）
this.bgp_necro_infusion_effect <- ::inherit("scripts/skills/skill", {
	m = {
		TurnsLeft = 2,
		Bonus = 4
	},
	function create()
	{
		this.m.ID = "effects.bgp_necro_infusion";
		this.m.Name = "死灵灌注";
		this.m.Description = "死灵法术灌入这具躯体，让它动得比生前更快。";
		this.m.Icon = "ui/perks/perk_bgp_necro_infusion.png";
		this.m.IconMini = "";
		this.m.Type = ::Const.SkillType.StatusEffect;
		this.m.Order = ::Const.SkillOrder.Last;
		this.m.IsActive = false;
		this.m.IsStacking = false;
		this.m.IsRemovedAfterBattle = true;
		this.m.IsSerialized = false;
	}

	function refresh()
	{
		this.m.TurnsLeft = 2;
	}

	function getTooltip()
	{
		local ret = this.skill.getTooltip();
		ret.push({ id = 10, type = "text", icon = "ui/icons/action_points.png", text = "行动点数 " + ::MSU.Text.colorPositive("+" + this.m.Bonus) });
		ret.push({ id = 11, type = "text", icon = "ui/icons/special.png", text = "还剩 " + this.m.TurnsLeft + " 个回合" });
		return ret;
	}

	function onUpdate( _properties )
	{
		_properties.ActionPoints += this.m.Bonus;
	}

	function onTurnEnd()
	{
		this.m.TurnsLeft--;
		if (this.m.TurnsLeft <= 0)
			this.removeSelf();
	}
});

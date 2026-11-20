// 声东击西：被换位的野兽获得的防御姿态，持续到它下一次回合结束
this.bgp_guard_stance_effect <- ::inherit("scripts/skills/skill", {
	m = {
		MeleeDefense = 15
	},
	function create()
	{
		this.m.ID = "effects.bgp_guard_stance";
		this.m.Name = "防御姿态";
		this.m.Icon = "ui/perks/perk_bgp_feint.png";
		this.m.Type = ::Const.SkillType.StatusEffect;
		this.m.Order = ::Const.SkillOrder.Perk;
		this.m.IsActive = false;
		this.m.IsRemovedAfterBattle = true;
		this.m.IsSerialized = false;
	}

	function getDescription()
	{
		return "这只野兽摆出了防御姿态，持续到它下一次回合结束。";
	}

	function getTooltip()
	{
		local ret = this.skill.getTooltip();
		ret.push({ id = 10, type = "text", icon = "ui/icons/melee_defense.png", text = "近战防御 " + ::MSU.Text.colorPositive("+" + this.m.MeleeDefense) });
		return ret;
	}

	function onUpdate( _properties )
	{
		_properties.MeleeDefense += this.m.MeleeDefense;
	}

	function onTurnEnd()
	{
		this.removeSelf();
	}
});

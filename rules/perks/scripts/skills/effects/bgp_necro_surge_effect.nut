// End-of-round combat surge granted to friendly undead within 4 tiles when a
// Necromancy Grandmaster casts a necromancy spell (max 1 trigger/round, non-stacking).
this.bgp_necro_surge_effect <- ::inherit("scripts/skills/skill", {
	m = {},
	function create()
	{
		this.m.ID = "effects.bgp_necro_surge";
		this.m.Name = "死灵余波";
		this.m.Description = "亡灵法术大师施法时逸散的魂火短暂强化了这名亡灵的战技。";
		this.m.Icon = "ui/perks/perk_bgp_necro_grandmaster.png";
		this.m.IconMini = "";
		this.m.Type = ::Const.SkillType.StatusEffect;
		this.m.Order = ::Const.SkillOrder.Last;
		this.m.IsActive = false;
		this.m.IsStacking = false;
		this.m.IsRemovedAfterBattle = true;
		this.m.IsSerialized = false;
	}

	function getTooltip()
	{
		local ret = this.skill.getTooltip();
		ret.push({ id = 10, type = "text", icon = "ui/icons/melee_skill.png", text = ::MSU.Text.colorPositive("+5") + " 近战技能、" + ::MSU.Text.colorPositive("+5") + " 远程技能（持续至本轮结束，不叠加）" });
		return ret;
	}

	function onUpdate( _properties )
	{
		_properties.MeleeSkill += 5;
		_properties.RangedSkill += 5;
	}

	function onNewRound()
	{
		this.removeSelf();
	}
});

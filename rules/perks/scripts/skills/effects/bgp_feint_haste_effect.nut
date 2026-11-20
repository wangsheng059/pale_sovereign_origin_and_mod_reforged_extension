// 声东击西：驯兽师获得的主动值加成，持续到他下一回合结束（影响下一轮的行动顺序）
this.bgp_feint_haste_effect <- ::inherit("scripts/skills/skill", {
	m = {
		Initiative = 30,
		AppliedRound = 0
	},
	function create()
	{
		this.m.ID = "effects.bgp_feint_haste";
		this.m.Name = ::BGP.PerkNames.Feint;
		this.m.Icon = "ui/perks/perk_bgp_feint.png";
		this.m.Type = ::Const.SkillType.StatusEffect;
		this.m.Order = ::Const.SkillOrder.Perk;
		this.m.IsActive = false;
		this.m.IsRemovedAfterBattle = true;
		this.m.IsSerialized = false;
	}

	function getDescription()
	{
		return "声东击西之后，抢先一步行动。持续到下一回合结束。";
	}

	function getTooltip()
	{
		local ret = this.skill.getTooltip();
		ret.push({ id = 10, type = "text", icon = "ui/icons/initiative.png", text = "主动值 " + ::MSU.Text.colorPositive("+" + this.m.Initiative) });
		return ret;
	}

	function onAdded()
	{
		this.m.AppliedRound = ::BGP.getRound();
	}

	function onRefresh()
	{
		this.m.AppliedRound = ::BGP.getRound();
	}

	function onUpdate( _properties )
	{
		_properties.Initiative += this.m.Initiative;
	}

	function onTurnEnd()
	{
		if (::BGP.getRound() > this.m.AppliedRound)
			this.removeSelf();
	}
});

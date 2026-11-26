// 狩猎时刻：持续本回合和下一回合；主动值 +50，士气锁定为自信（onUpdate 里士气检定决心 +1000）
this.bgp_hunting_hour_effect <- ::inherit("scripts/skills/skill", {
	m = {
		Initiative = 50,
		AppliedRound = 0
	},
	function create()
	{
		this.m.ID = "effects.bgp_hunting_hour";
		this.m.Name = "狂猎时刻";
		this.m.Icon = "ui/perks/perk_bgp_hunting_hour.png";
		this.m.Type = ::Const.SkillType.StatusEffect;
		this.m.Order = ::Const.SkillOrder.Perk;
		this.m.IsActive = false;
		this.m.IsRemovedAfterBattle = true;
		this.m.IsSerialized = false;
	}

	function getDescription()
	{
		return "猎号响起，狩猎开始了！持续本回合和下一回合。";
	}

	function getTooltip()
	{
		local ret = this.skill.getTooltip();
		ret.extend([
			{ id = 10, type = "text", icon = "ui/icons/initiative.png", text = "主动值 " + ::MSU.Text.colorPositive("+" + this.m.Initiative) },
			{ id = 11, type = "text", icon = "ui/icons/bravery.png", text = "士气锁定为自信，不会下降" }
		]);
		return ret;
	}

	function setConfident()
	{
		try
		{
			local actor = this.getContainer().getActor();
			if (actor.getMoraleState() != ::Const.MoraleState.Ignore && actor.getMoraleState() != ::Const.MoraleState.Confident)
				actor.setMoraleState(::Const.MoraleState.Confident);
		}
		catch (e)
		{
		}
	}

	function onAdded()
	{
		this.m.AppliedRound = ::BGP.getRound();
		this.setConfident();
	}

	function onRefresh()
	{
		this.m.AppliedRound = ::BGP.getRound();
		this.setConfident();
	}

	function onTurnStart()
	{
		this.setConfident();
	}

	function onUpdate( _properties )
	{
		_properties.Initiative += this.m.Initiative;
		// 士气锁定：所有类型的士气检定决心 +1000，负向检定必定通过
		try
		{
			for (local i = 0; i < _properties.MoraleCheckBravery.len(); i++)
				_properties.MoraleCheckBravery[i] += 1000;
		}
		catch (e)
		{
		}
	}

	function onTurnEnd()
	{
		if (::BGP.getRound() > this.m.AppliedRound)
			this.removeSelf();
	}
});

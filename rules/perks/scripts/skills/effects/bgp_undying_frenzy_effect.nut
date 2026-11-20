// 不死狂热：本回合和下一回合不受任何生命值伤害、不会受伤，也不会死
this.bgp_undying_frenzy_effect <- ::inherit("scripts/skills/skill", {
	m = {
		AppliedRound = 0,
		OldIsAbleToDie = true
	},
	function create()
	{
		this.m.ID = "effects.bgp_undying_frenzy";
		this.m.Name = "不死狂热";
		this.m.Icon = "ui/perks/perk_bgp_undying_saint.png";
		this.m.Type = ::Const.SkillType.StatusEffect;
		this.m.Order = ::Const.SkillOrder.Perk;
		this.m.IsActive = false;
		this.m.IsRemovedAfterBattle = true;
		this.m.IsSerialized = false;
	}

	function getDescription()
	{
		return "誓言未竟，此身不灭。持续本回合和下一回合。";
	}

	function getTooltip()
	{
		local ret = this.skill.getTooltip();
		ret.extend([
			{ id = 10, type = "text", icon = "ui/icons/health.png", text = "不受任何生命值伤害" },
			{ id = 11, type = "text", icon = "ui/icons/special.png", text = "不会受伤" }
		]);
		return ret;
	}

	function onAdded()
	{
		this.m.AppliedRound = ::BGP.getRound();
		local actor = this.getContainer().getActor();
		try
		{
			this.m.OldIsAbleToDie = actor.m.IsAbleToDie;
			actor.m.IsAbleToDie = false;
		}
		catch (e)
		{
		}
	}

	function onRemoved()
	{
		try
		{
			this.getContainer().getActor().m.IsAbleToDie = this.m.OldIsAbleToDie;
		}
		catch (e)
		{
		}
	}

	function onUpdate( _properties )
	{
		_properties.IsAffectedByInjuries = false;
		_properties.IsAffectedByFreshInjuries = false;
	}

	function onBeforeDamageReceived( _attacker, _skill, _hitInfo, _properties )
	{
		_properties.DamageReceivedRegularMult *= 0.0;
		_properties.DamageReceivedDirectMult *= 0.0;
	}

	function onTurnEnd()
	{
		if (::BGP.getRound() > this.m.AppliedRound)
			this.removeSelf();
	}
});

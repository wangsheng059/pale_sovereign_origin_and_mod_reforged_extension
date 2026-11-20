this.perk_bgp_reward_punish <- ::inherit("scripts/skills/skill", {
	m = {
		Radius = 4,
		FatigueRecovered = 8
	},
	function create()
	{
		this.m.ID = "perk.bgp_reward_punish";
		this.m.Name = ::BGP.PerkNames.RewardPunish;
		this.m.Description = ::BGP.PerkDescriptions.RewardPunish;
		this.m.Icon = "ui/perks/perk_bgp_reward_punish.png";
		this.m.Type = ::Const.SkillType.Perk;
		this.m.Order = ::Const.SkillOrder.Perk;
	}

	function onOtherActorDeath( _killer, _victim, _skill, _deathTile, _corpseTile, _fatalityType )
	{
		local actor = this.getContainer().getActor();
		if (!::BGP.isValid(actor) || !::BGP.isValid(_killer) || _victim == null)
			return;
		try
		{
			if (_killer.getFaction() != ::Const.Faction.Player || _victim.isAlliedWith(actor))
				return;
			if (::BGP.distance(_killer, actor) > this.m.Radius)
				return;

			::BGP.reduceFatigue(_killer, this.m.FatigueRecovered);
			if (_killer.getMoraleState() != ::Const.MoraleState.Ignore)
				_killer.checkMorale(1, 15);
			_killer.setDirty(true);
		}
		catch (e)
		{
		}
	}
});

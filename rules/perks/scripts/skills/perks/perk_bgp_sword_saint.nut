this.perk_bgp_sword_saint <- ::inherit("scripts/skills/skill", {
	m = {
		InjuriesBefore = null,   // 目标 ID → 命中前的伤势数量
		LowMoraleDamageMult = 1.2,
		FearRadius = 2,
		FearDifficulty = -10
	},
	function create()
	{
		this.m.ID = "perk.bgp_sword_saint";
		this.m.Name = ::BGP.PerkNames.SwordSaint;
		this.m.Description = ::BGP.PerkDescriptions.SwordSaint;
		this.m.Icon = "ui/perks/perk_bgp_sword_saint.png";
		this.m.Type = ::Const.SkillType.Perk;
		this.m.Order = ::Const.SkillOrder.Perk;
		this.m.InjuriesBefore = {};
	}

	// 盾牌提供的近战防御：无视；盾墙额外的那份按一半算（即再补回一半）
	function getShieldCompensation( _target )
	{
		try
		{
			local shield = _target.getItems().getItemAtSlot(::Const.ItemSlot.Offhand);
			if (shield == null || !shield.isItemType(::Const.Items.ItemType.Shield))
				return 0;

			local def = shield.getMeleeDefense();
			if (def <= 0)
				return 0;

			local ret = def;
			if (_target.getSkills().hasSkill("effects.shieldwall"))
				ret += ::Math.floor(def * 0.5);
			return ret;
		}
		catch (e)
		{
			return 0;
		}
	}

	function isLowMorale( _target )
	{
		try
		{
			local state = _target.getMoraleState();
			return state != ::Const.MoraleState.Ignore && state <= ::Const.MoraleState.Wavering;
		}
		catch (e)
		{
			return false;
		}
	}

	function onAnySkillUsed( _skill, _targetEntity, _properties )
	{
		if (_targetEntity == null || _skill == null || !_skill.isAttack())
			return;

		if (!_skill.isRanged() && ::BGP.isSwordSkill(_skill))
			_properties.MeleeSkill += this.getShieldCompensation(_targetEntity);

		if (this.isLowMorale(_targetEntity))
			_properties.DamageTotalMult *= this.m.LowMoraleDamageMult;
	}

	function onBeforeTargetHit( _skill, _targetEntity, _hitInfo )
	{
		if (_targetEntity == null)
			return;
		this.m.InjuriesBefore[_targetEntity.getID()] <- ::BGP.countInjuries(_targetEntity);
	}

	function onTargetHit( _skill, _targetEntity, _bodyPart, _damageInflictedHitpoints, _damageInflictedArmor )
	{
		if (_targetEntity == null)
			return;

		local id = _targetEntity.getID();
		if (!(id in this.m.InjuriesBefore))
			return;
		local before = this.m.InjuriesBefore[id];
		delete this.m.InjuriesBefore[id];

		if (!_targetEntity.isAlive() || _targetEntity.isDying())
			return;   // 击杀由 onTargetKilled 处理

		if (::BGP.countInjuries(_targetEntity) > before)
			this.spreadFear();
	}

	function onTargetKilled( _targetEntity, _skill )
	{
		if (_targetEntity == null || _targetEntity.isAlliedWith(this.getContainer().getActor()))
			return;
		this.spreadFear();
	}

	function spreadFear()
	{
		local actor = this.getContainer().getActor();
		if (!::BGP.isValid(actor))
			return;

		foreach (a in ::BGP.getAllActors())
		{
			if (!::BGP.isValid(a) || a.isAlliedWith(actor))
				continue;
			if (::BGP.distance(a, actor) > this.m.FearRadius)
				continue;
			try
			{
				if (a.getMoraleState() == ::Const.MoraleState.Ignore || a.getMoraleState() == ::Const.MoraleState.Fleeing)
					continue;
				a.checkMorale(-1, this.m.FearDifficulty);
			}
			catch (e)
			{
			}
		}
	}

	function onCombatFinished()
	{
		this.skill.onCombatFinished();
		this.m.InjuriesBefore = {};
	}
});

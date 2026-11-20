this.perk_bgp_one_strike <- ::inherit("scripts/skills/skill", {
	m = {
		Attacked = null,          // 已经攻击过的目标 ID（命中或落空都算）
		FirstStrikeMult = 0.3,
		NotActedMult = 0.2
	},
	function create()
	{
		this.m.ID = "perk.bgp_one_strike";
		this.m.Name = ::BGP.PerkNames.OneStrike;
		this.m.Description = ::BGP.PerkDescriptions.OneStrike;
		this.m.Icon = "ui/perks/perk_bgp_one_strike.png";
		this.m.Type = ::Const.SkillType.Perk;
		this.m.Order = ::Const.SkillOrder.Perk;
		this.m.Attacked = {};
	}

	function getBonus( _targetEntity )
	{
		if (_targetEntity == null || (_targetEntity.getID() in this.m.Attacked))
			return 0.0;

		local bonus = this.m.FirstStrikeMult;
		try
		{
			if (!_targetEntity.isTurnDone())
				bonus += this.m.NotActedMult;
		}
		catch (e)
		{
		}
		return bonus;
	}

	function onAnySkillUsed( _skill, _targetEntity, _properties )
	{
		if (_skill == null || !_skill.isAttack() || _targetEntity == null)
			return;
		local bonus = this.getBonus(_targetEntity);
		if (bonus > 0)
			_properties.DamageTotalMult *= 1.0 + bonus;
	}

	function markAttacked( _targetEntity )
	{
		if (_targetEntity != null)
			this.m.Attacked[_targetEntity.getID()] <- true;
	}

	function onTargetHit( _skill, _targetEntity, _bodyPart, _damageInflictedHitpoints, _damageInflictedArmor )
	{
		if (_skill != null && _skill.isAttack())
			this.markAttacked(_targetEntity);
	}

	function onTargetMissed( _skill, _targetEntity )
	{
		if (_skill != null && _skill.isAttack())
			this.markAttacked(_targetEntity);
	}

	function onCombatStarted()
	{
		this.m.Attacked = {};
	}

	function onCombatFinished()
	{
		this.skill.onCombatFinished();
		this.m.Attacked = {};
	}
});

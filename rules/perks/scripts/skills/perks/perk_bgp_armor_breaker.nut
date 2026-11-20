this.perk_bgp_armor_breaker <- ::inherit("scripts/skills/skill", {
	m = {
		ArmorDamageMult = 1.2,
		MoraleDifficulty = -20,
		ArmorBefore = null   // 目标 ID → [头盔耐久, 身甲耐久]
	},
	function create()
	{
		this.m.ID = "perk.bgp_armor_breaker";
		this.m.Name = ::BGP.PerkNames.ArmorBreaker;
		this.m.Description = ::BGP.PerkDescriptions.ArmorBreaker;
		this.m.Icon = "ui/perks/perk_bgp_armor_breaker.png";
		this.m.Type = ::Const.SkillType.Perk;
		this.m.Order = ::Const.SkillOrder.Perk;
		this.m.ArmorBefore = {};
	}

	// 双手斧、双手锤、双手钉头锤、双手剑
	function isHeavyTwoHander()
	{
		local w = this.getContainer().getActor().getMainhandItem();
		if (w == null)
			return false;
		try
		{
			if (!w.isItemType(::Const.Items.ItemType.TwoHanded) || !w.isItemType(::Const.Items.ItemType.MeleeWeapon))
				return false;
			return w.isWeaponType(::Const.Items.WeaponType.Axe) || w.isWeaponType(::Const.Items.WeaponType.Hammer)
				|| w.isWeaponType(::Const.Items.WeaponType.Mace) || w.isWeaponType(::Const.Items.WeaponType.Sword);
		}
		catch (e)
		{
			return false;
		}
	}

	function onAnySkillUsed( _skill, _targetEntity, _properties )
	{
		if (_skill != null && _skill.isAttack() && !_skill.isRanged() && this.isHeavyTwoHander())
			_properties.DamageArmorMult *= this.m.ArmorDamageMult;
	}

	function getCondition( _actor, _slot )
	{
		try
		{
			local item = _actor.getItems().getItemAtSlot(_slot);
			return item == null ? 0 : item.getCondition();
		}
		catch (e)
		{
			return 0;
		}
	}

	function onBeforeTargetHit( _skill, _targetEntity, _hitInfo )
	{
		if (_targetEntity == null)
			return;
		this.m.ArmorBefore[_targetEntity.getID()] <- [
			this.getCondition(_targetEntity, ::Const.ItemSlot.Head),
			this.getCondition(_targetEntity, ::Const.ItemSlot.Body)
		];
	}

	function onTargetHit( _skill, _targetEntity, _bodyPart, _damageInflictedHitpoints, _damageInflictedArmor )
	{
		if (_targetEntity == null)
			return;
		local id = _targetEntity.getID();
		if (!(id in this.m.ArmorBefore))
			return;
		local before = this.m.ArmorBefore[id];
		delete this.m.ArmorBefore[id];

		if (!_targetEntity.isAlive() || _targetEntity.isDying())
			return;

		local broken = (before[0] > 0 && this.getCondition(_targetEntity, ::Const.ItemSlot.Head) <= 0)
			|| (before[1] > 0 && this.getCondition(_targetEntity, ::Const.ItemSlot.Body) <= 0);
		if (!broken)
			return;

		try
		{
			if (_targetEntity.getMoraleState() != ::Const.MoraleState.Ignore)
			{
				::BGP.log(_targetEntity, "的护甲被打碎了");
				_targetEntity.checkMorale(-1, this.m.MoraleDifficulty);
			}
		}
		catch (e)
		{
		}
	}

	function onCombatFinished()
	{
		this.skill.onCombatFinished();
		this.m.ArmorBefore = {};
	}
});

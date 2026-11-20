this.perk_bgp_iron_juggernaut <- ::inherit("scripts/skills/skill", {
	m = {
		// 直线冲锋记录
		LastTile = null,
		Dir = null,
		Steps = 0,
		IsStraight = true,
		IsCharged = false,      // 已经直线移动 >= 2 格，下一次近战攻击生效
		IsChargeAttack = false, // 正在执行的这次攻击就是冲锋攻击
		ChargeDamageRatio = 0.15,
		StaggerChance = 50
	},
	function create()
	{
		this.m.ID = "perk.bgp_iron_juggernaut";
		this.m.Name = ::BGP.PerkNames.IronJuggernaut;
		this.m.Description = ::BGP.PerkDescriptions.IronJuggernaut;
		this.m.Icon = "ui/perks/perk_bgp_iron_juggernaut.png";
		this.m.Type = ::Const.SkillType.Perk | ::Const.SkillType.StatusEffect;
		this.m.Order = ::Const.SkillOrder.Perk;
	}

	function isHidden()
	{
		return !this.m.IsCharged;
	}

	function getDescription()
	{
		return "沿直线冲锋，下一次近战攻击会更重。";
	}

	function getTooltip()
	{
		local ret = this.skill.getTooltip();
		ret.push({ id = 10, type = "text", icon = "ui/icons/regular_damage.png", text = "下一次近战攻击附加 " + ::MSU.Text.colorPositive(this.getChargeDamage()) + " 点固定伤害，命中时 " + ::MSU.Text.colorPositive(this.m.StaggerChance + "%") + " 概率使目标踉跄" });
		return ret;
	}

	function getArmorPieces()
	{
		local ret = [];
		local items = this.getContainer().getActor().getItems();
		foreach (slot in [::Const.ItemSlot.Head, ::Const.ItemSlot.Body])
		{
			local item = items.getItemAtSlot(slot);
			if (item != null)
				ret.push(item);
		}
		return ret;
	}

	function getArmorDurability()
	{
		local total = 0;
		foreach (item in this.getArmorPieces())
		{
			try { total += item.getCondition(); } catch (e) {}
		}
		return total;
	}

	function getChargeDamage()
	{
		local penalty = 0;
		foreach (item in this.getArmorPieces())
		{
			try { penalty += ::Math.abs(item.getStaminaModifier()); } catch (e) {}
		}
		return ::Math.floor(penalty * this.m.ChargeDamageRatio);
	}

	function onUpdate( _properties )
	{
		local n = ::Math.floor(this.getArmorDurability() / 100);
		_properties.Bravery += 3 * n;
		_properties.RangedDefense += 2 * n;
		_properties.IsImmuneToKnockBackAndGrab = true;
	}

	// ---- 直线移动判定 ----
	function onMovementStarted( _tile, _numTiles )
	{
		this.m.LastTile = _tile;
		this.m.Dir = null;
		this.m.Steps = 0;
		this.m.IsStraight = true;
		this.m.IsCharged = false;
	}

	function onMovementStep( _tile, _levelDifference )
	{
		try
		{
			if (this.m.LastTile != null)
			{
				local dir = this.m.LastTile.getDirectionTo(_tile);
				if (this.m.Dir == null)
					this.m.Dir = dir;
				else if (dir != this.m.Dir)
					this.m.IsStraight = false;
			}
		}
		catch (e)
		{
			this.m.IsStraight = false;
		}
		this.m.LastTile = _tile;
		this.m.Steps++;
	}

	function onMovementFinished( _tile )
	{
		this.m.IsCharged = this.m.IsStraight && this.m.Steps >= 2;
		this.m.LastTile = null;
		if (this.m.IsCharged)
			::BGP.log(this.getContainer().getActor(), "完成了冲锋");
	}

	// ---- 冲锋攻击 ----
	function isMeleeAttack( _skill )
	{
		return _skill != null && _skill.isAttack() && !_skill.isRanged();
	}

	function onBeforeAnySkillExecuted( _skill, _targetTile, _targetEntity, _forFree )
	{
		if (this.m.IsCharged && this.isMeleeAttack(_skill))
		{
			this.m.IsCharged = false;
			this.m.IsChargeAttack = true;
		}
	}

	function onAnySkillUsed( _skill, _targetEntity, _properties )
	{
		if ((this.m.IsCharged || this.m.IsChargeAttack) && this.isMeleeAttack(_skill))
		{
			local dmg = this.getChargeDamage();
			_properties.DamageRegularMin += dmg;
			_properties.DamageRegularMax += dmg;
		}
	}

	function onTargetHit( _skill, _targetEntity, _bodyPart, _damageInflictedHitpoints, _damageInflictedArmor )
	{
		if (!this.m.IsChargeAttack || _targetEntity == null || !_targetEntity.isAlive() || _targetEntity.isDying())
			return;
		if (::Math.rand(1, 100) <= this.m.StaggerChance)
		{
			_targetEntity.getSkills().add(::new("scripts/skills/effects/staggered_effect"));
			::BGP.log(_targetEntity, "被冲锋撞得踉跄");
		}
	}

	function onAnySkillExecuted( _skill, _targetTile, _targetEntity, _forFree )
	{
		this.m.IsChargeAttack = false;
	}

	function onTurnEnd()
	{
		this.m.IsCharged = false;
		this.m.IsChargeAttack = false;
	}

	function onCombatFinished()
	{
		this.skill.onCombatFinished();
		this.m.IsCharged = false;
		this.m.IsChargeAttack = false;
		this.m.LastTile = null;
	}
});

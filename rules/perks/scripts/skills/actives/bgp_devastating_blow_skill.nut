// 毁灭一击（单体）。扇形版本 bgp_devastating_sweep_skill 继承本类，只把 IsSweep 设为 true。
this.bgp_devastating_blow_skill <- ::inherit("scripts/skills/skill", {
	m = {
		IsSweep = false,
		DamageMult = 1.4,
		DirectAdd = 0.3,
		HeadshotBonus = 35,
		IsExecuting = false
	},
	function create()
	{
		this.m.ID = "actives.bgp_devastating_blow";
		this.m.Name = "毁灭一击";
		this.m.Description = "举起双手武器蓄力劈下，重创单个目标，并用震荡波把它和身后的敌人震退。";
		this.m.KilledString = "劈碎";
		this.m.Icon = "skills/bgp_devastating_blow_skill.png";
		this.m.IconDisabled = "skills/bgp_devastating_blow_skill_sw.png";
		this.m.Overlay = "rf_command_skill";
		this.m.SoundOnUse = [
			"sounds/combat/shatter_01.wav",
			"sounds/combat/shatter_02.wav",
			"sounds/combat/shatter_03.wav"
		];
		this.m.SoundOnHit = [
			"sounds/combat/round_swing_hit_01.wav",
			"sounds/combat/round_swing_hit_02.wav",
			"sounds/combat/round_swing_hit_03.wav"
		];
		this.m.Type = ::Const.SkillType.Active;
		this.m.Order = ::Const.SkillOrder.OffensiveTargeted;
		this.m.IsSerialized = false;
		this.m.IsActive = true;
		this.m.IsTargeted = true;
		this.m.IsStacking = false;
		this.m.IsAttack = true;
		this.m.IsIgnoredAsAOO = true;
		this.m.IsWeaponSkill = true;
		this.m.InjuriesOnBody = ::Const.Injury.CuttingBody;
		this.m.InjuriesOnHead = ::Const.Injury.CuttingHead;
		this.m.HitChanceBonus = 0;
		this.m.DirectDamageMult = 0.3;
		this.m.ActionPointCost = 6;
		this.m.FatigueCost = 35;
		this.m.MinRange = 1;
		this.m.MaxRange = 1;
		this.m.ChanceDecapitate = 50;
		this.m.ChanceDisembowel = 33;
		this.m.ChanceSmash = 50;
	}

	function getPerk()
	{
		return this.getContainer().getSkillByID("perk.bgp_devastating_blow");
	}

	function getWeapon()
	{
		local w = this.getContainer().getActor().getMainhandItem();
		if (w == null)
			return null;
		try
		{
			if (w.isItemType(::Const.Items.ItemType.TwoHanded) && w.isItemType(::Const.Items.ItemType.MeleeWeapon))
				return w;
		}
		catch (e)
		{
		}
		return null;
	}

	function getTooltip()
	{
		local ret = this.getDefaultTooltip();
		ret.extend([
			{ id = 10, type = "text", icon = "ui/icons/regular_damage.png", text = "总伤害 " + ::MSU.Text.colorPositive("+40%") + "，穿甲伤害比例 " + ::MSU.Text.colorPositive("+30%") + "，命中头部几率 " + ::MSU.Text.colorPositive("+35%") },
			{ id = 11, type = "text", icon = "ui/icons/special.png", text = "震荡波：无论是否命中，主目标和它身后 1 格内的敌人被震退 1 格，并随机陷入眩晕或踉跄（免疫眩晕的改为踉跄）" },
			{ id = 12, type = "text", icon = "ui/icons/special.png", text = "需要双手近战武器；和另一种毁灭技能共用冷却，每 3 回合可用一次（间隔 2 回合）" }
		]);
		if (this.m.IsSweep)
			ret.push({ id = 13, type = "text", icon = "ui/icons/special.png", text = "扇形攻击：同时攻击目标和它两侧与你相邻的敌人（不伤友军）" });

		local perk = this.getPerk();
		if (perk != null && perk.isOnCooldown())
			ret.push({ id = 20, type = "text", icon = "ui/tooltips/warning.png", text = ::MSU.Text.colorNegative("冷却中，还需等待 " + perk.getCooldownLeft() + " 回合（含本回合）") });
		if (this.getWeapon() == null)
			ret.push({ id = 21, type = "text", icon = "ui/tooltips/warning.png", text = ::MSU.Text.colorNegative("需要装备双手近战武器") });
		return ret;
	}

	function isUsable()
	{
		local perk = this.getPerk();
		if (perk == null || perk.isOnCooldown() || this.getWeapon() == null)
			return false;
		return this.skill.isUsable();
	}

	function onAfterUpdate( _properties )
	{
		// 按武器类型取穿甲比例和伤势类型
		local w = this.getWeapon();
		if (w == null)
			return;
		try
		{
			if (w.isWeaponType(::Const.Items.WeaponType.Hammer) || w.isWeaponType(::Const.Items.WeaponType.Mace))
			{
				this.m.DirectDamageMult = 0.5;
				this.m.InjuriesOnBody = ::Const.Injury.BluntBody;
				this.m.InjuriesOnHead = ::Const.Injury.BluntHead;
			}
			else if (w.isWeaponType(::Const.Items.WeaponType.Axe))
			{
				this.m.DirectDamageMult = 0.4;
				this.m.InjuriesOnBody = ::Const.Injury.CuttingBody;
				this.m.InjuriesOnHead = ::Const.Injury.CuttingHead;
			}
			else if (w.isWeaponType(::Const.Items.WeaponType.Sword))
			{
				this.m.DirectDamageMult = 0.25;
				this.m.InjuriesOnBody = ::Const.Injury.CuttingBody;
				this.m.InjuriesOnHead = ::Const.Injury.CuttingHead;
			}
			else
			{
				this.m.DirectDamageMult = 0.3;
			}
		}
		catch (e)
		{
		}
	}

	function onVerifyTarget( _originTile, _targetTile )
	{
		if (!this.skill.onVerifyTarget(_originTile, _targetTile))
			return false;
		local t = _targetTile.getEntity();
		return t != null && !t.isAlliedWith(this.getContainer().getActor());
	}

	function onAnySkillUsed( _skill, _targetEntity, _properties )
	{
		if (_skill != this)
			return;
		_properties.DamageTotalMult *= this.m.DamageMult;
		_properties.DamageDirectAdd += this.m.DirectAdd;
		_properties.HitChance[::Const.BodyPart.Head] += this.m.HeadshotBonus;
	}

	// 和目标相邻、也和自己相邻的两侧格子（扇形）
	function getSweepTiles( _user, _targetTile )
	{
		local ret = [];
		local own = _user.getTile();
		local dir = own.getDirectionTo(_targetTile);
		foreach (d in [dir == 0 ? 5 : dir - 1, dir == 5 ? 0 : dir + 1])
		{
			if (!own.hasNextTile(d))
				continue;
			local t = own.getNextTile(d);
			if (t.IsOccupiedByActor && ::Math.abs(t.Level - own.Level) <= 1)
			{
				local e = t.getEntity();
				if (e != null && e.isAttackable() && !e.isAlliedWith(_user))
					ret.push(t);
			}
		}
		return ret;
	}

	// 主目标身后 1 格内的格子（远离自己的三个方向）
	function getBehindTiles( _user, _targetTile )
	{
		local ret = [];
		local dir = _user.getTile().getDirectionTo(_targetTile);
		foreach (d in [dir, dir == 0 ? 5 : dir - 1, dir == 5 ? 0 : dir + 1])
		{
			if (_targetTile.hasNextTile(d))
				ret.push(_targetTile.getNextTile(d));
		}
		return ret;
	}

	function findTileToKnockBackTo( _fromTile, _targetTile )
	{
		local dir = _fromTile.getDirectionTo(_targetTile);
		foreach (d in [dir, dir == 0 ? 5 : dir - 1, dir == 5 ? 0 : dir + 1])
		{
			if (!_targetTile.hasNextTile(d))
				continue;
			local t = _targetTile.getNextTile(d);
			if (t.IsEmpty && t.Level - _targetTile.Level <= 1)
				return t;
		}
		return null;
	}

	function shock( _user, _entity, _fromTile )
	{
		if (_entity == null || !_entity.isAlive() || _entity.isDying() || _entity.isAlliedWith(_user))
			return;

		local tile = _entity.getTile();
		if (!_entity.getCurrentProperties().IsImmuneToKnockBackAndGrab && !_entity.getCurrentProperties().IsRooted)
		{
			local to = this.findTileToKnockBackTo(_fromTile, tile);
			if (to != null)
			{
				local skills = _entity.getSkills();
				skills.removeByID("effects.shieldwall");
				skills.removeByID("effects.spearwall");
				skills.removeByID("effects.riposte");
				_entity.setCurrentMovementType(::Const.Tactical.MovementType.Involuntary);
				::Tactical.getNavigator().teleport(_entity, to, null, null, true);
			}
		}

		local stun = ::Math.rand(1, 2) == 1 && !_entity.getCurrentProperties().IsImmuneToStun;
		if (stun)
		{
			_entity.getSkills().add(::new("scripts/skills/effects/stunned_effect"));
			::BGP.log(_entity, "被震荡波震晕了");
		}
		else
		{
			_entity.getSkills().add(::new("scripts/skills/effects/staggered_effect"));
			::BGP.log(_entity, "被震荡波震得踉跄");
		}
	}

	function onUse( _user, _targetTile )
	{
		local perk = this.getPerk();
		if (perk != null)
			perk.setUsed();

		local userTile = _user.getTile();
		local sweepTiles = this.m.IsSweep ? this.getSweepTiles(_user, _targetTile) : [];

		this.spawnAttackEffect(_targetTile, ::Const.Tactical.AttackEffectChop);
		local target = _targetTile.getEntity();
		local ret = this.attackEntity(_user, target);

		foreach (t in sweepTiles)
		{
			if (!_user.isAlive() || _user.isDying())
				break;
			if (t.IsOccupiedByActor)
				ret = this.attackEntity(_user, t.getEntity()) || ret;
		}

		if (!_user.isAlive() || _user.isDying())
			return ret;

		// 震荡波：先震身后的，再震主目标，主目标才有空格可退
		foreach (t in this.getBehindTiles(_user, _targetTile))
		{
			if (t.IsOccupiedByActor)
				this.shock(_user, t.getEntity(), userTile);
		}
		if (_targetTile.IsOccupiedByActor)
			this.shock(_user, _targetTile.getEntity(), userTile);

		return ret;
	}
});

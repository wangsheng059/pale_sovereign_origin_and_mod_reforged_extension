// 1.4.0 死灵法师用到的钩子

// 尸体记录（复活和尸爆要知道尸体生前是什么、最大生命、剩余护甲）
::BGP.HooksMod.hook("scripts/entity/tactical/actor", function(q)
{
	q.kill = @(__original) function( _killer = null, _skill = null, _fatalityType = ::Const.FatalityType.None, _silent = false )
	{
		local info = null;
		local tile = null;
		try
		{
			if (this.isAlive() && !this.isDying() && this.isPlacedOnMap())
			{
				tile = this.getTile();
				info = ::BGP.Necro.beforeKill(this);
				// 1.6.0 不灭冠军的主人死亡：倒下等待唤回的宠物禁卫随之失去
				if (::BGP.Champion.hasPerk(this))
					::BGP.Champion.onOwnerDeath(this);
			}
		}
		catch (e)
		{
			info = null;
		}

		local ret = __original(_killer, _skill, _fatalityType, _silent);

		if (info != null)
		{
			try { ::BGP.Necro.afterKill(this, tile, info); } catch (e) {}
		}
		return ret;
	}
});

// MV 说明：所有单位死亡时都通过 generateCorpse 生成尸体表（子类各自覆盖），所以用 hookTree
::BGP.HooksMod.hookTree("scripts/entity/tactical/actor", function(q)
{
	q.generateCorpse = @(__original) function( _tile, _fatalityType, _killer )
	{
		local ret = __original(_tile, _fatalityType, _killer);
		try { ::BGP.Necro.onGenerateCorpse(this, ret); } catch (e) {}
		return ret;
	}
});

// 支配亡灵：支配中的效果不在战斗结束时移除的话，下一场开局不能再支配（mod_necro 的修正）
::BGP.HooksMod.hook("scripts/skills/effects/possessing_undead_effect", function(q)
{
	q.create = @(__original) function()
	{
		__original();
		this.m.IsRemovedAfterBattle = true;
	}
});


// 1.6.2 支配亡灵（本 mod 死灵法师施放的）按施放时的 W（决心 − 20，见 necro.nut）：近战技能 +W/5，受到伤害 -(W/4 - 5)%（0~30%），
// 替换原版 / 重铸的 +15 和 -25%；行动点 12、近防 / 远防 +10、主动 +50 不变。敌方死灵法师的支配不受影响（BGP_Will 为 null）。
::BGP.HooksMod.hook("scripts/skills/effects/possessed_undead_effect", function(q)
{
	q.m.BGP_Will <- null;

	q.onUpdate = @(__original) function( _properties )
	{
		if (this.m.BGP_Will == null)
			return __original(_properties);
		local ms = _properties.MeleeSkill;
		local snap = ::BGP.Necro.snapKeys(_properties, ::BGP.Necro.DamageMultKeys);
		__original(_properties);
		_properties.MeleeSkill = ms + ::BGP.Necro.WillScale.PossessMeleeSkill(this.m.BGP_Will);
		::BGP.Necro.rescaleKeys(_properties, snap, 1.0 - ::BGP.Necro.WillScale.PossessReduction(this.m.BGP_Will) / 100.0);
	}

	q.onBeforeDamageReceived = @(__original) function( _attacker, _skill, _hitInfo, _properties )
	{
		if (this.m.BGP_Will == null)
			return __original(_attacker, _skill, _hitInfo, _properties);
		local mult = 1.0 - ::BGP.Necro.WillScale.PossessReduction(this.m.BGP_Will) / 100.0;
		local snapP = ::BGP.Necro.snapKeys(_properties, ::BGP.Necro.DamageMultKeys);
		local snapH = ::BGP.Necro.snapKeys(_hitInfo, ["DamageRegular", "DamageArmor", "DamageDirect"]);
		__original(_attacker, _skill, _hitInfo, _properties);
		::BGP.Necro.rescaleKeys(_properties, snapP, mult);
		::BGP.Necro.rescaleKeys(_hitInfo, snapH, mult);
	}

	q.getTooltip = @(__original) function()
	{
		local ret = __original();
		if (this.m.BGP_Will == null)
			return ret;
		local w = this.m.BGP_Will;
		foreach (row in ret)
		{
			if (!("id" in row))
				continue;
			if (row.id == 11)
				row.text = ::MSU.Text.colorPositive("+" + ::BGP.Necro.WillScale.PossessMeleeSkill(w)) + " 近战技能（W = 施放者决心 − " + ::BGP.Necro.WillOffset + " = " + w + "）";
			else if (row.id == 16)
				row.text = "受到的所有伤害降低 " + ::MSU.Text.colorPositive(::Math.round(::BGP.Necro.WillScale.PossessReduction(w)) + "%") + "（W = 施放者决心 − " + ::BGP.Necro.WillOffset + " = " + w + "）";
		}
		return ret;
	}
});

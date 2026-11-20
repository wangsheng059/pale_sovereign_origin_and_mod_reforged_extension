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


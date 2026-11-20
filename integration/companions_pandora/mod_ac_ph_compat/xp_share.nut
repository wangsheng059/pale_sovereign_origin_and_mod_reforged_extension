// 1.2.3 宠物击杀经验补全（重铸）
// 重铸按伤害比例分经验：兄弟造成的那份 20% 给出手者、80% 全队平分；
// 宠物（PlayerAnimals）造成的那份只有 80% 全队平分，20% 丢失。
// 这里在重铸记录伤害之后，把有主人的宠物造成的伤害改记到主人名下（Player 阵营），
// 于是主人按出手者拿 20%，其余 80% 照旧全队平分。掉落判定把两个阵营加在一起算，不受影响。
// 主人识别：配件兄弟宠物 / 原版战犬 → m.Item 所在的兄弟；德鲁伊召唤兽、配件兄弟复活的亡灵 → 召唤时写入的旗标。

::AC_PH_Compat.OwnerFlag <- "AC_PH_OwnerID";

::AC_PH_Compat.isValidOwner <- function( _a )
{
	if (_a == null)
		return false;
	if (_a instanceof ::WeakTableRef && _a.isNull())
		return false;
	try
	{
		return _a.isAlive() && _a.getFaction() == ::Const.Faction.Player;
	}
	catch (e)
	{
		return false;
	}
}

::AC_PH_Compat.getPetOwner <- function( _attacker )
{
	if (_attacker == null || _attacker.getFaction() != ::Const.Faction.PlayerAnimals)
		return null;

	local owner = null;

	try
	{
		local flags = _attacker.getFlags();
		if (flags.has(::AC_PH_Compat.OwnerFlag))
			owner = ::Tactical.getEntityByID(flags.get(::AC_PH_Compat.OwnerFlag));
	}
	catch (e)
	{
		owner = null;
	}

	if (!::AC_PH_Compat.isValidOwner(owner))
	{
		owner = null;
		try
		{
			local item = _attacker.m.Item;
			if (item != null && !(item instanceof ::WeakTableRef && item.isNull()))
			{
				local c = item.getContainer();
				if (c != null)
					owner = c.getActor();
			}
		}
		catch (e)
		{
			owner = null;
		}
	}

	return ::AC_PH_Compat.isValidOwner(owner) ? owner : null;
}

::AC_PH_Compat.moveDamageToOwner <- function( _t, _petID, _ownerID, _amount )
{
	local paf = ::Const.Faction.PlayerAnimals;
	local pf = ::Const.Faction.Player;

	local animals = _t[paf];
	animals[_petID] -= _amount;
	animals.Total -= _amount;
	if (animals[_petID] <= 0.001)
		delete animals[_petID];
	// 宠物阵营没有剩余伤害时删掉整个条目，免得重铸给每个兄弟再发 1 点保底经验
	if (animals.Total <= 0.001)
		delete _t[paf];

	if (!(pf in _t))
		_t[pf] <- { Total = 0.0 };
	if (!(_ownerID in _t[pf]))
		_t[pf][_ownerID] <- 0.0;
	_t[pf].Total += _amount;
	_t[pf][_ownerID] += _amount;
}

::AC_PH_Compat.HooksMod.hook("scripts/skills/skill_container", function(q)
{
	q.onDamageReceived = @(__original) function( _attacker, _damageHitpoints, _damageArmor )
	{
		local owner = null;
		local t = null;
		local petID = null;
		local before = 0.0;
		local paf = ::Const.Faction.PlayerAnimals;

		try
		{
			owner = ::AC_PH_Compat.getPetOwner(_attacker);
			if (owner != null)
			{
				t = this.getActor().m.RF_DamageReceived;
				petID = _attacker.getID();
				if (paf in t && petID in t[paf])
					before = t[paf][petID];
			}
		}
		catch (e)
		{
			owner = null;
		}

		local ret = __original(_attacker, _damageHitpoints, _damageArmor);

		if (owner != null && t != null)
		{
			try
			{
				if (paf in t && petID in t[paf])
				{
					local added = t[paf][petID] - before;
					if (added > 0)
						::AC_PH_Compat.moveDamageToOwner(t, petID, owner.getID(), added);
				}
			}
			catch (e)
			{
				::logError("mod_ac_ph_compat: 宠物伤害归属失败: " + e);
			}
		}

		return ret;
	}
});

// 配件兄弟复活的亡灵：记下施法的兄弟
::AC_PH_Compat.HooksMod.hook("scripts/companions/onequip/companions_raise", function(q)
{
	q.spawnUndead = @(__original) function( _user, _tile )
	{
		local ret = __original(_user, _tile);
		try
		{
			if (_tile.IsOccupiedByActor)
			{
				local ent = _tile.getEntity();
				if (ent != null && ent.getFaction() == ::Const.Faction.PlayerAnimals)
					ent.getFlags().set(::AC_PH_Compat.OwnerFlag, _user.getID());
			}
		}
		catch (e)
		{
			::logError("mod_ac_ph_compat: 记录亡灵主人失败: " + e);
		}
		return ret;
	}
});

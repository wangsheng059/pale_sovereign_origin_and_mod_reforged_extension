// ---------- 1. 驯服冠军：给驯服得到的宠物加上对应的冠军特质 ----------
::AC_PH_Compat.HooksMod.hook("scripts/companions/player/companions_tame", function(q)
{
	q.onUse = @(__original) function( _user, _targetTile )
	{
		local target = _targetTile.getEntity();
		local key = null;

		try
		{
			if (target != null)
				key = ::AC_PH_Compat.getChampionKey(target);
		}
		catch (e) { key = null; }

		local ret = __original(_user, _targetTile);

		if (key == null)
			return ret;

		// 驯服成功时配件兄弟会把目标标记为死亡并移出地图，同时把宠物装备到饰品栏。
		local tamed = false;
		try { tamed = !target.isAlive(); } catch (e) { tamed = false; }

		if (!tamed)
			return ret;

		try
		{
			local acc = this.getContainer().getActor().getItems().getItemAtSlot(::Const.ItemSlot.Accessory);

			if (acc != null && acc.getType() != null)
			{
				local script = ::AC_PH_Compat.getChampionQuirkScript(key);

				if (acc.m.Quirks.find(script) == null)
					acc.m.Quirks.push(script);

				::logInfo("mod_ac_ph_compat: 驯服冠军 " + key + "，已加上冠军特质");
			}
		}
		catch (e)
		{
			::logError("mod_ac_ph_compat: 给驯服的冠军加特质失败: " + e);
		}

		return ret;
	}
});

// ---------- 2. 恐惧战狼接入配件兄弟 ----------
// 配件兄弟的 accessory_foundation 已经把这个物品的方法整套换成宠物逻辑，
// 但它不认识恐惧战狼，种类一直是 null。这里在创建时补上种类。
::AC_PH_Compat.HooksMod.hook("scripts/items/accessory/ph_dreadwolf_item", function(q)
{
	q.create = @(__original) function()
	{
		__original();

		if ("Dreadwolf" in ::Const.Companions.TypeList)
			this.setType(::Const.Companions.TypeList.Dreadwolf);
	}
});

// ---------- 3. 制作恐惧战狼时继承原宠物 ----------
::AC_PH_Compat.isCompanionItem <- function( _item )
{
	if (_item == null)
		return false;

	try { return ::isKindOf(_item, "accessory") && _item.getType() != null && _item.getLevel() >= 1; }
	catch (e) { return false; }
}

// 把 _src 宠物的名字、等级、经验、成长属性、后天特质转到新做出来的恐惧战狼 _dst 上。
::AC_PH_Compat.transferCompanion <- function( _src, _dst )
{
	local lib = ::Const.Companions.Library;
	local oldDef = lib[_src.getType()];
	local newDef = lib[_dst.getType()];

	local attrs = {};
	foreach (key, value in newDef.BasicAttributes)
	{
		local growth = 0;
		if (key in _src.m.Attributes && key in oldDef.BasicAttributes)
			growth = _src.m.Attributes[key] - oldDef.BasicAttributes[key];

		attrs[key] <- value + growth;
	}
	_dst.m.Attributes = attrs;

	local quirks = [];
	foreach (quirk in newDef.BasicQuirks)
	{
		if (quirks.find(quirk) == null)
			quirks.push(quirk);
	}
	foreach (quirk in _src.m.Quirks)
	{
		// 原种类自带的特质不继承（例如战犬自带的开路先锋、铁额），后天学会的都保留
		if (oldDef.BasicQuirks.find(quirk) != null)
			continue;

		if (quirks.find(quirk) == null)
			quirks.push(quirk);
	}
	_dst.m.Quirks = quirks;

	_dst.m.Level = _src.m.Level;
	_dst.m.XP = _src.m.XP;
	_dst.m.Wounds = 0;
	_dst.m.Name = _src.m.Name;
	_dst.updateCompanion();
}

::AC_PH_Compat.HooksMod.hook("scripts/crafting/blueprint", function(q)
{
	q.craft = @(__original) function()
	{
		if (this.m.ID.find("blueprint.ph_dreadwolf_") != 0)
			return __original();

		local stash = ::World.Assets.getStash();
		local before = [];
		foreach (item in stash.getItems())
		{
			if (item != null)
				before.push(item);
		}

		local ret = __original();

		try
		{
			local after = stash.getItems();
			local src = null;
			local dst = null;

			foreach (item in before)
			{
				if (src == null && after.find(item) == null && ::AC_PH_Compat.isCompanionItem(item))
					src = item;
			}

			foreach (item in after)
			{
				if (dst == null && item != null && before.find(item) == null && ::isKindOf(item, "ph_dreadwolf_item"))
					dst = item;
			}

			if (src != null && dst != null && ::AC_PH_Compat.isCompanionItem(dst))
			{
				::AC_PH_Compat.transferCompanion(src, dst);
				::logInfo("mod_ac_ph_compat: 恐惧战狼继承了 " + src.m.Name + "（等级 " + dst.m.Level + "）");
			}
		}
		catch (e)
		{
			::logError("mod_ac_ph_compat: 恐惧战狼继承宠物数据失败: " + e);
		}

		return ret;
	}
});

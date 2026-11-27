// 1.6.0 亡灵勇士：不灭勇士（永恒禁卫、下一回合自动复活）和血肉重铸用到的公用逻辑
//
// 永恒禁卫：
//   战斗开始时死灵法师有“不灭勇士”且饰品栏没有死灵宠物：在身旁召唤“墓穴王禁卫”（本 mod 类 bgp_eternal_guard，
//   继承复活类“受缚古代仪仗兵”，即重铸 rf_skeleton_heavy_elite 的面板，武器换成双手巨斧）。
//   饰品栏是死灵宠物：放出时直接成为永恒禁卫，全属性（8 项基础属性）+10%。
//   禁卫阵亡时残骸记下主人（尸体表 BGP_Guard），不能被复活死者或敌方吞食消耗（仍可被尸爆/血肉重铸摧毁）；
//   只要主人在场上存活，下一回合主人行动开始时禁卫自动原地复活（若残骸格被敌人占据则将其挤开，无法挤开或被友军占据则在相邻空格复活），
//   生命和头甲、身甲恢复到 15% + W/5 %（W = 复活时主人的当前决心 - 20，最多 50%）。
//   宠物禁卫阵亡时不收回配件（配件仍指向倒下的宠物，配件兄弟就不会在主人死亡时再自动放出）；
//   主人在战斗中死亡时，倒下的宠物禁卫随之失去（配件被收走，同配件兄弟宠物阵亡）；
//   主人活到战斗结束时，倒下的宠物禁卫保留，配件伤势记为 50%。

::BGP.Champion <- {
	PerkID = "perk.bgp_necro_undying_champion",
	GuardScript = "scripts/entity/tactical/bgp_undead/bgp_eternal_guard",
	GuardWeapon = "scripts/items/weapons/greataxe",
	GuardName = "墓穴王禁卫",
	PetBonus = 1.1,
	ReviveHitpointsPct = 0.5,
	ReviveArmorPct = 0.5,
	PendingRevives = {},
	GearSlots = [
		::Const.ItemSlot.Mainhand,
		::Const.ItemSlot.Offhand,
		::Const.ItemSlot.Head,
		::Const.ItemSlot.Body,
		::Const.ItemSlot.Ammo
	]
};

::BGP.Champion.hasPerk <- function( _actor )
{
	try { return _actor != null && _actor.getSkills().hasSkill(::BGP.Champion.PerkID); } catch (e) {}
	return false;
}

::BGP.Champion.isGuard <- function( _e )
{
	try { return _e.getFlags().has("bgp_eternal_guard"); } catch (e) {}
	return false;
}

::BGP.Champion.getOwnerID <- function( _e )
{
	try { return _e.getFlags().get("bgp_guard_owner"); } catch (e) {}
	return null;
}

::BGP.Champion.markGuard <- function( _e, _owner )
{
	try
	{
		if (!_e.getFlags().has("bgp_eternal_guard"))
			_e.getFlags().add("bgp_eternal_guard");
		_e.getFlags().set("bgp_guard_owner", _owner.getID());
	}
	catch (e)
	{
		::logError("mod_bg_unique_perks: 永恒禁卫标记失败: " + e);
	}
}

::BGP.Champion.isAliveActor <- function( _a )
{
	try { return _a != null && _a.isAlive() && !_a.isDying(); } catch (e) {}
	return false;
}

// 宠物的主人 = 配件所在的物品栏的主人
::BGP.Champion.getPetOwner <- function( _pet )
{
	try
	{
		local item = _pet.m.Item;
		if (::MSU.isNull(item))
			return null;
		local c = item.getContainer();
		if (c == null)
			return null;
		return c.getActor();
	}
	catch (e)
	{
	}
	return null;
}

::BGP.Champion.hasPetEquipped <- function( _actor )
{
	if (!::BGP.HasAC)
		return false;
	try { return ::BGP.NecroPet.isOwnItem(_actor.getItems().getItemAtSlot(::Const.ItemSlot.Accessory)); } catch (e) {}
	return false;
}

::BGP.Champion.findGuard <- function( _owner )
{
	try
	{
		foreach (e in ::Tactical.Entities.getInstancesOfFaction(::Const.Faction.PlayerAnimals))
		{
			if (::BGP.Champion.isAliveActor(e) && ::BGP.Champion.isGuard(e) && ::BGP.Champion.getOwnerID(e) == _owner.getID())
				return e;
		}
	}
	catch (e)
	{
	}
	return null;
}

::BGP.Champion.findSpawnTile <- function( _tile )
{
	local ring = [];
	for (local i = 0; i < 6; i++)
	{
		if (!_tile.hasNextTile(i))
			continue;
		local t = _tile.getNextTile(i);
		if (t.IsEmpty)
			return t;
		ring.push(t);
	}
	foreach (r in ring)
	{
		for (local i = 0; i < 6; i++)
		{
			if (!r.hasNextTile(i))
				continue;
			local t = r.getNextTile(i);
			if (t.IsEmpty)
				return t;
		}
	}
	return null;
}

// ---------------------------------------------------------------------------
// 装备（召唤禁卫复活时要原样换回来）
// ---------------------------------------------------------------------------
::BGP.Champion.captureGear <- function( _e )
{
	local ret = "";
	local items = _e.getItems();
	foreach (slot in ::BGP.Champion.GearSlots)
	{
		local it = null;
		try { it = items.getItemAtSlot(slot); } catch (e) { it = null; }
		if (it == null || typeof it == "integer")
			continue;
		try { ret += (ret.len() == 0 ? "" : ";") + ::IO.scriptFilenameByHash(it.ClassNameHash); } catch (e) {}
	}
	return ret;
}

::BGP.Champion.applyGear <- function( _e, _gear )
{
	if (_gear == null || _gear == "")
		return false;
	foreach (script in split(_gear, ";"))
	{
		try { _e.getItems().equip(::new(script)); } catch (e) { ::logWarning("mod_bg_unique_perks: 永恒禁卫装备生成失败（" + script + "）: " + e); }
	}
	return true;
}

::BGP.Champion.equipGuardWeapon <- function( _e )
{
	local items = _e.getItems();
	foreach (slot in [::Const.ItemSlot.Mainhand, ::Const.ItemSlot.Offhand])
	{
		try
		{
			local it = items.getItemAtSlot(slot);
			if (it != null && typeof it != "integer")
				items.unequip(it);
		}
		catch (e)
		{
		}
	}
	try { items.equip(::new(::BGP.Champion.GuardWeapon)); } catch (e) { ::logError("mod_bg_unique_perks: 永恒禁卫武器生成失败: " + e); }
}

::BGP.Champion.setArmorPct <- function( _e, _pct )
{
	local b = null;
	try { b = _e.getBaseProperties(); } catch (e) { b = null; }
	foreach (pair in [
		[::Const.ItemSlot.Head, ::Const.BodyPart.Head],
		[::Const.ItemSlot.Body, ::Const.BodyPart.Body]
	])
	{
		try
		{
			local piece = _e.getItems().getItemAtSlot(pair[0]);
			if (piece != null && typeof piece != "integer" && piece.getArmorMax() > 0)
			{
				piece.setArmor(::Math.max(1, ::Math.floor(piece.getArmorMax() * _pct)));
			}
			else if (b != null && b.ArmorMax[pair[1]] > 0)
			{
				b.Armor[pair[1]] = ::Math.max(1, ::Math.floor(b.ArmorMax[pair[1]] * _pct));
			}
		}
		catch (e)
		{
		}
	}
}

// ---------------------------------------------------------------------------
// 召唤
// ---------------------------------------------------------------------------
::BGP.Champion.setupSummoned <- function( _owner, _e, _gear )
{
	try { _e.setFaction(::Const.Faction.PlayerAnimals); } catch (err) {}
	if (!::BGP.Champion.applyGear(_e, _gear))
	{
		try { _e.assignRandomEquipment(); } catch (err) {}
		::BGP.Champion.equipGuardWeapon(_e);
	}
	::BGP.Necro.markGearNoLoot(_e);
	try { _e.m.Name = ::BGP.Champion.GuardName; } catch (err) {}
	::BGP.Necro.copySocket(_owner, _e);
	::BGP.Necro.markMinion(_owner, _e);
	::BGP.Champion.markGuard(_e, _owner);
}

::BGP.Champion.summon <- function( _owner )
{
	local tile = ::BGP.Champion.findSpawnTile(_owner.getTile());
	if (tile == null)
		return false;
	local e = ::Tactical.spawnEntity(::BGP.Champion.GuardScript, tile.Coords.X, tile.Coords.Y);
	if (e == null)
		return false;
	::BGP.Champion.setupSummoned(_owner, e, null);
	try { e.riseFromGround(); } catch (err) {}
	try { e.getSkills().update(); } catch (err) {}
	try { e.setDirty(true); } catch (err) {}
	if (!_owner.isHiddenToPlayer())
		::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(_owner) + "唤来了" + ::Const.UI.getColorizedEntityName(e) + "（不灭勇士）");
	return true;
}

// 死灵宠物放出时（NecroPet.applyScaling 里调用）：主人有不灭冠军就晋升为永恒禁卫
::BGP.Champion.promotePet <- function( _pet, _owner )
{
	if (!::BGP.Champion.hasPerk(_owner))
		return;
	try
	{
		local b = _pet.m.BaseProperties;
		foreach (k in ["Hitpoints", "Stamina", "Bravery", "Initiative", "MeleeSkill", "RangedSkill", "MeleeDefense", "RangedDefense"])
			b[k] = ::Math.round(b[k] * ::BGP.Champion.PetBonus);
		_pet.m.CurrentProperties = clone b;
		_pet.m.Hitpoints = b.Hitpoints;
	}
	catch (e)
	{
		::logError("mod_bg_unique_perks: 永恒禁卫加成失败: " + e);
	}
	::BGP.Champion.markGuard(_pet, _owner);
}

// 宠物禁卫阵亡时要不要保留配件（NecroPet.releaseItem 里调用）
::BGP.Champion.shouldKeepPet <- function( _pet )
{
	if (!::BGP.Champion.isGuard(_pet))
		return false;
	local owner = ::BGP.Champion.getPetOwner(_pet);
	if (!::BGP.Champion.isAliveActor(owner) || !::BGP.Champion.hasPerk(owner))
		return false;
	return ::BGP.Champion.getOwnerID(_pet) == owner.getID();
}

// ---------------------------------------------------------------------------
// 残骸与下一回合自动复活
// ---------------------------------------------------------------------------
::BGP.Champion.clearPending <- function( _ownerID = null )
{
	if (_ownerID == null)
	{
		::BGP.Champion.PendingRevives = {};
		return;
	}
	if (_ownerID in ::BGP.Champion.PendingRevives)
		delete ::BGP.Champion.PendingRevives[_ownerID];
}

::BGP.Champion.buildGuardData <- function( _actor )
{
	local item = null;
	try { item = _actor.m.Item; } catch (e) { item = null; }
	local data = {
		OwnerID = ::BGP.Champion.getOwnerID(_actor),
		IsPet = item != null,
		Item = item,
		Script = "",
		Gear = ""
	};
	try { data.Script = ::IO.scriptFilenameByHash(_actor.ClassNameHash); } catch (e) {}
	if (!data.IsPet)
		data.Gear = ::BGP.Champion.captureGear(_actor);
	return data;
}

::BGP.Champion.tagGuardCorpse <- function( _actor, _corpse, _tile = null )
{
	if (_corpse == null || !::BGP.Champion.isGuard(_actor))
		return;
	local data = ::BGP.Champion.buildGuardData(_actor);
	_corpse.BGP_Guard <- data;
	try { _corpse.IsResurrectable = false; } catch (e) {}
	try { _corpse.IsConsumable = false; } catch (e) {}
	local tile = _tile;
	if (tile == null)
	{
		try { if (_actor.isPlacedOnMap()) tile = _actor.getTile(); } catch (e) { tile = null; }
	}
	if (data.OwnerID != null && tile != null)
	{
		::BGP.Champion.PendingRevives[data.OwnerID] <- {
			OwnerID = data.OwnerID,
			Tile = tile,
			DeathRound = ::Time.getRound(),
			Data = data,
			HasCorpse = true,
			InProgress = false
		};
	}
}

// Reconcile the actual corpse tile after actor.kill() completes (handles cases where the death tile already had a corpse).
::BGP.Champion.onGuardAfterKill <- function( _actor, _tile )
{
	if (!::BGP.Champion.isGuard(_actor) || _tile == null)
		return;
	local ownerID = ::BGP.Champion.getOwnerID(_actor);
	if (ownerID == null)
		return;
	local corpseTile = ::BGP.Champion.findGuardCorpseTile(ownerID, _tile);
	if (ownerID in ::BGP.Champion.PendingRevives)
	{
		local pending = ::BGP.Champion.PendingRevives[ownerID];
		if (corpseTile != null)
		{
			pending.Tile = corpseTile;
			pending.HasCorpse = true;
		}
		else
		{
			pending.Tile = _tile;
			pending.HasCorpse = false;
		}
	}
	else
	{
		local data = ::BGP.Champion.buildGuardData(_actor);
		::BGP.Champion.PendingRevives[ownerID] <- {
			OwnerID = ownerID,
			Tile = corpseTile != null ? corpseTile : _tile,
			DeathRound = ::Time.getRound(),
			Data = data,
			HasCorpse = corpseTile != null,
			InProgress = false
		};
	}
}

::BGP.Champion.getGuardCorpse <- function( _user, _tile )
{
	local corpse = ::BGP.Necro.getCorpse(_tile);
	if (!::BGP.Necro.isGuardCorpse(corpse))
		return null;
	if (corpse.BGP_Guard.OwnerID != _user.getID())
		return null;
	return corpse;
}

::BGP.Champion.findGuardCorpseTile <- function( _ownerID, _centerTile )
{
	if (_centerTile == null || _ownerID == null)
		return null;
	local tiles = [_centerTile];
	for (local i = 0; i < 6; i++)
	{
		if (_centerTile.hasNextTile(i))
			tiles.push(_centerTile.getNextTile(i));
	}
	foreach (t in tiles)
	{
		local c = ::BGP.Necro.getCorpse(t);
		if (::BGP.Necro.isGuardCorpse(c) && c.BGP_Guard.OwnerID == _ownerID)
			return t;
	}
	return null;
}

::BGP.Champion.getPetItemFromData <- function( _user, _data )
{
	try
	{
		local item = _data.Item;
		if (::MSU.isNull(item))
			return null;
		local c = item.getContainer();
		if (c == null || c.getActor() == null || c.getActor().getID() != _user.getID())
			return null;
		if (!item.m.BGP_GuardDown)
			return null;
		return item;
	}
	catch (e)
	{
	}
	return null;
}

::BGP.Champion.getPetItem <- function( _user, _corpse )
{
	if (_corpse == null || !("BGP_Guard" in _corpse))
		return null;
	return ::BGP.Champion.getPetItemFromData(_user, _corpse.BGP_Guard);
}

::BGP.Champion.isMultiTileActor <- function( _actor )
{
	foreach (cls in ["lindwurm", "lindwurm_tail", "kraken", "kraken_tentacle"])
	{
		try { if (::isKindOf(_actor, cls)) return true; } catch (e) {}
	}
	return false;
}

::BGP.Champion.isPushableEnemy <- function( _owner, _actor )
{
	if (!::BGP.Champion.isAliveActor(_actor) || !_actor.isPlacedOnMap() || _actor.isAlliedWith(_owner))
		return false;
	if (::BGP.Champion.isMultiTileActor(_actor))
		return false;
	try
	{
		if (_actor.getCurrentProperties().IsRooted)
			return false;
	}
	catch (e)
	{
	}
	return true;
}

// Pick the best adjacent empty tile to shove an occupying enemy onto (prefer walkable height diff <= 1 and farther from owner).
::BGP.Champion.findPushTile <- function( _corpseTile, _owner )
{
	local ownerTile = null;
	try { if (_owner != null && _owner.isPlacedOnMap()) ownerTile = _owner.getTile(); } catch (e) { ownerTile = null; }
	local bestWalkable = null;
	local bestWalkDist = -1;
	local bestAny = null;
	local bestAnyDist = -1;
	for (local d = 0; d < 6; d++)
	{
		if (!_corpseTile.hasNextTile(d))
			continue;
		local nt = _corpseTile.getNextTile(d);
		if (!nt.IsEmpty)
			continue;
		local dist = ownerTile != null ? nt.getDistanceTo(ownerTile) : 0;
		if (::Math.abs(nt.Level - _corpseTile.Level) <= 1)
		{
			if (bestWalkable == null || dist > bestWalkDist)
			{
				bestWalkable = nt;
				bestWalkDist = dist;
			}
		}
		else if (bestAny == null || dist > bestAnyDist)
		{
			bestAny = nt;
			bestAnyDist = dist;
		}
	}
	return bestWalkable != null ? bestWalkable : bestAny;
}

::BGP.Champion.canRevive <- function( _user, _tile )
{
	if (!_tile.IsEmpty)
		return false;
	local corpse = ::BGP.Champion.getGuardCorpse(_user, _tile);
	if (corpse == null)
		return false;
	if (corpse.BGP_Guard.IsPet)
		return ::BGP.Champion.getPetItem(_user, corpse) != null;
	return corpse.BGP_Guard.Script != "";
}

::BGP.Champion.reviveFromData <- function( _user, _corpseTile, _spawnTile, _data, _hasCorpse )
{
	if (_user == null || _spawnTile == null || !_spawnTile.IsEmpty || _data == null)
		return null;
	local x = _spawnTile.Coords.X;
	local y = _spawnTile.Coords.Y;
	local e = null;

	if (_data.IsPet)
	{
		local item = ::BGP.Champion.getPetItemFromData(_user, _data);
		if (item == null)
			return null;
		if (_hasCorpse && _corpseTile != null && ::BGP.Champion.getGuardCorpse(_user, _corpseTile) != null)
			::BGP.Necro.removeCorpse(_corpseTile);
		// Same companion release flow as Accessory Companions (companions_unleash).
		e = ::Tactical.spawnEntity(item.getScript(), x, y);
		if (e == null)
			return null;
		e.setItem(item);
		e.setName(item.m.Name);
		e.setVariant(item.getVariant());
		e.setFaction(::Const.Faction.PlayerAnimals);
		e.applyCompanionScaling();
		item.m.BGP_GuardDown = false;
		item.setEntity(e);
		try
		{
			if (!::World.getTime().IsDaytime)
				e.getSkills().add(::new("scripts/skills/special/night_effect"));
		}
		catch (err)
		{
		}
	}
	else
	{
		if (_data.Script == "")
			return null;
		if (_hasCorpse && _corpseTile != null && ::BGP.Champion.getGuardCorpse(_user, _corpseTile) != null)
			::BGP.Necro.removeCorpse(_corpseTile);
		e = ::Tactical.spawnEntity(_data.Script, x, y);
		if (e == null)
			return null;
		::BGP.Champion.setupSummoned(_user, e, _data.Gear);
	}

	local pct = ::BGP.Necro.WillScale.RevivePct(::BGP.Necro.getWill(_user));
	::BGP.Necro.restoreArmorPct(e, 1.0);
	::BGP.Champion.setArmorPct(e, pct);
	try { e.setHitpoints(::Math.max(1, ::Math.floor(e.getHitpointsMax() * pct))); } catch (err) {}
	try { e.riseFromGround(); } catch (err) {}
	try { e.getSkills().update(); } catch (err) {}
	try { e.setDirty(true); } catch (err) {}
	return e;
}

::BGP.Champion.revive <- function( _user, _tile )
{
	local corpse = ::BGP.Champion.getGuardCorpse(_user, _tile);
	if (corpse == null)
		return null;
	return ::BGP.Champion.reviveFromData(_user, _tile, _tile, corpse.BGP_Guard, true);
}

::BGP.Champion.finishAutoRevive <- function( _tag )
{
	local owner = null;
	try { owner = ::MSU.isNull(_tag.Owner) ? null : _tag.Owner.get(); } catch (e) { owner = null; }
	if (_tag.LockedBusy && owner != null)
	{
		try { owner.getSkills().setBusy(false); } catch (e) {}
		_tag.LockedBusy = false;
	}
	if (!::Tactical.isActive() || owner == null || !::BGP.Champion.isAliveActor(owner) || !owner.isPlacedOnMap() || !::BGP.Champion.hasPerk(owner))
	{
		::BGP.Champion.clearPending(_tag.OwnerID);
		return null;
	}

	local corpseTile = _tag.CorpseTile;
	if (_tag.HasCorpse)
	{
		corpseTile = ::BGP.Champion.findGuardCorpseTile(_tag.OwnerID, corpseTile);
		if (corpseTile == null)
		{
			::BGP.Champion.clearPending(_tag.OwnerID);
			return null;
		}
	}

	local spawnTile = _tag.SpawnTile;
	if (spawnTile == null || !spawnTile.IsEmpty)
		spawnTile = corpseTile != null && corpseTile.IsEmpty ? corpseTile : ::BGP.Champion.findSpawnTile(corpseTile != null ? corpseTile : owner.getTile());
	if (spawnTile == null || !spawnTile.IsEmpty)
	{
		// Every nearby tile is occupied; keep pending so next turn retries.
		if (_tag.OwnerID in ::BGP.Champion.PendingRevives)
			::BGP.Champion.PendingRevives[_tag.OwnerID].InProgress = false;
		return null;
	}

	::BGP.Champion.clearPending(_tag.OwnerID);
	if (spawnTile.IsVisibleForPlayer)
	{
		try
		{
			foreach (p in ::Const.Tactical.RaiseUndeadParticles)
				::Tactical.spawnParticleEffect(true, p.Brushes, spawnTile, p.Delay, p.Quantity, p.LifeTimeQuantity, p.SpawnRate, p.Stages);
		}
		catch (e)
		{
		}
		try
		{
			if ("PaleSovereign" in ::getroottable() && "playBattleArt" in ::PaleSovereign && ::PaleSovereign.Battle != null)
				::PaleSovereign.playBattleArt("command", spawnTile);
		}
		catch (e)
		{
		}
	}

	local e = null;
	try
	{
		e = ::BGP.Champion.reviveFromData(owner, corpseTile, spawnTile, _tag.Data, _tag.HasCorpse);
	}
	catch (err)
	{
		::logError("mod_bg_unique_perks: 永恒禁卫自动复活失败: " + err);
		e = null;
	}
	if (e != null && !owner.isHiddenToPlayer())
		::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(e) + "重新站了起来（不灭勇士）");
	return e;
}

::BGP.Champion.onShoveDone <- function( _pushedEntity, _tag )
{
	::BGP.Champion.finishAutoRevive(_tag);
}

// Automatically revive the fallen Eternal Guard at the start of the owner's turn on the next round.
::BGP.Champion.tryAutoRevive <- function( _owner )
{
	if (!::BGP.isInBattle() || !::BGP.Champion.isAliveActor(_owner) || !_owner.isPlacedOnMap() || !::BGP.Champion.hasPerk(_owner))
		return false;
	local ownerID = _owner.getID();
	if (!(ownerID in ::BGP.Champion.PendingRevives))
		return false;
	local pending = ::BGP.Champion.PendingRevives[ownerID];
	if (pending.InProgress)
		return false;
	if (::Time.getRound() <= pending.DeathRound)
		return false;

	local corpseTile = pending.Tile;
	local data = pending.Data;
	if (pending.HasCorpse)
	{
		corpseTile = ::BGP.Champion.findGuardCorpseTile(ownerID, corpseTile);
		if (corpseTile == null)
		{
			// Corpse was destroyed (e.g. Corpse Explosion / Flesh Reforge).
			::BGP.Champion.clearPending(ownerID);
			return false;
		}
		pending.Tile = corpseTile;
		local c = ::BGP.Necro.getCorpse(corpseTile);
		if (c != null && "BGP_Guard" in c)
			data = c.BGP_Guard;
	}

	if (data.IsPet && ::BGP.Champion.getPetItemFromData(_owner, data) == null)
	{
		::BGP.Champion.clearPending(ownerID);
		return false;
	}
	if (!data.IsPet && data.Script == "")
	{
		::BGP.Champion.clearPending(ownerID);
		return false;
	}

	local tag = {
		OwnerID = ownerID,
		Owner = ::MSU.asWeakTableRef(_owner),
		CorpseTile = corpseTile,
		SpawnTile = null,
		Data = data,
		HasCorpse = pending.HasCorpse,
		LockedBusy = false
	};

	if (corpseTile.IsEmpty)
	{
		tag.SpawnTile = corpseTile;
		return ::BGP.Champion.finishAutoRevive(tag) != null;
	}

	// If an enemy is standing on the corpse tile, shove them onto an adjacent empty tile first.
	local occ = corpseTile.IsOccupiedByActor ? corpseTile.getEntity() : null;
	if (occ != null && ::BGP.Champion.isPushableEnemy(_owner, occ))
	{
		local pushTile = ::BGP.Champion.findPushTile(corpseTile, _owner);
		if (pushTile != null)
		{
			pending.InProgress = true;
			try
			{
				local skills = occ.getSkills();
				skills.removeByID("effects.shieldwall");
				skills.removeByID("effects.spearwall");
				skills.removeByID("effects.riposte");
				occ.setCurrentMovementType(::Const.Tactical.MovementType.Involuntary);
				if (!occ.isHiddenToPlayer())
					::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(occ) + "被重生的永恒禁卫挤开了");
				_owner.getSkills().setBusy(true);
				tag.LockedBusy = true;
				::Tactical.getNavigator().teleport(occ, pushTile, ::BGP.Champion.onShoveDone, tag, true);
				return true;
			}
			catch (e)
			{
				::logError("mod_bg_unique_perks: 永恒禁卫复活挤开敌人失败: " + e);
				if (tag.LockedBusy)
				{
					try { _owner.getSkills().setBusy(false); } catch (e2) {}
					tag.LockedBusy = false;
				}
				pending.InProgress = false;
			}
		}
	}

	// Fallback when occupied by an ally or unpushable/surrounded enemy: revive on the nearest adjacent empty tile.
	local altTile = ::BGP.Champion.findSpawnTile(corpseTile);
	if (altTile == null)
		return false;
	tag.SpawnTile = altTile;
	return ::BGP.Champion.finishAutoRevive(tag) != null;
}

// 主人在战斗中死亡：倒下的宠物禁卫随之失去
::BGP.Champion.onOwnerDeath <- function( _owner )
{
	try { ::BGP.Champion.clearPending(_owner.getID()); } catch (e) {}
	if (!::BGP.HasAC)
		return;
	try
	{
		local acc = _owner.getItems().getItemAtSlot(::Const.ItemSlot.Accessory);
		if (!::BGP.NecroPet.isOwnItem(acc) || !acc.m.BGP_GuardDown)
			return;
		acc.m.BGP_GuardDown = false;
		acc.setEntity(null);
		_owner.getItems().unequip(acc);
		::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(_owner) + "倒下了，" + acc.m.Name + "的魂魄随之消散");
	}
	catch (e)
	{
		::logError("mod_bg_unique_perks: 主人死亡时处理永恒禁卫失败: " + e);
	}
}

// ---------------------------------------------------------------------------
// 血肉重铸
// ---------------------------------------------------------------------------
// 目标：你的亡灵（你复活的仆从、你的死灵宠物、你的永恒禁卫）
::BGP.Champion.isMyUndead <- function( _user, _e )
{
	if (!::BGP.Champion.isAliveActor(_e) || _e.getID() == _user.getID() || !_e.isAlliedWith(_user))
		return false;
	if (!_e.getFlags().has("undead"))
		return false;
	local m = ::BGP.Necro.getMaster(_e);
	return m != null && m.getID() == _user.getID();
}

::BGP.Champion.isGraftableCorpse <- function( _corpse )
{
	if (_corpse == null || ::BGP.Necro.isUnconsciousCorpse(_corpse) || ::BGP.Necro.isGuardCorpse(_corpse))
		return false;
	return true;
}

// 目标所在格和相邻 6 格里第一具能用的尸体所在的格子
::BGP.Champion.findGraftTile <- function( _tile )
{
	local tiles = [_tile];
	for (local i = 0; i < 6; i++)
	{
		if (_tile.hasNextTile(i))
			tiles.push(_tile.getNextTile(i));
	}
	foreach (t in tiles)
	{
		if (::BGP.Champion.isGraftableCorpse(::BGP.Necro.getCorpse(t)))
			return t;
	}
	return null;
}

// 返回下一次嫁接的效果脚本；两次都嫁接过返回 null
::BGP.Champion.getNextGraft <- function( _e )
{
	local s = _e.getSkills();
	if (!s.hasSkill("effects.bgp_graft_bone"))
		return "scripts/skills/effects/bgp_graft_bone_effect";
	if (!s.hasSkill("effects.bgp_graft_tendon"))
		return "scripts/skills/effects/bgp_graft_tendon_effect";
	return null;
}

// 骨刺：给近战攻击者 15 点穿刺伤害（无视护甲），稍后结算，避免在对方攻击流程中间改动它
::BGP.Champion.applyThorns <- function( _owner, _attacker, _skill, _damage )
{
	local data = { Owner = ::MSU.asWeakTableRef(_owner), Attacker = ::MSU.asWeakTableRef(_attacker), Skill = _skill, Damage = _damage };
	::Time.scheduleEvent(::TimeUnit.Virtual, 40, function( _d )
	{
		try
		{
			if (::MSU.isNull(_d.Attacker) || ::MSU.isNull(_d.Owner))
				return;
			local attacker = _d.Attacker.get();
			local owner = _d.Owner.get();
			if (!::BGP.Champion.isAliveActor(attacker) || !attacker.isPlacedOnMap() || !::BGP.Champion.isAliveActor(owner))
				return;
			local hitInfo = clone ::Const.Tactical.HitInfo;
			hitInfo.DamageRegular = _d.Damage;
			hitInfo.DamageArmor = 0.0;
			hitInfo.DamageDirect = 1.0;
			hitInfo.BodyPart = ::Const.BodyPart.Body;
			hitInfo.BodyDamageMult = 1.0;
			hitInfo.FatalityChanceMult = 1.0;
			hitInfo.Injuries = ::Const.Injury.PiercingBody;
			try { hitInfo.DamageType = ::Const.Damage.DamageType.Piercing; } catch (e) {}
			try { hitInfo.Tile = attacker.getTile(); } catch (e) {}
			if (!owner.isHiddenToPlayer())
				::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(attacker) + "被" + ::Const.UI.getColorizedEntityName(owner) + "的骨刺扎伤（" + _d.Damage + "）");
			attacker.onDamageReceived(owner, _d.Skill, hitInfo);
		}
		catch (e)
		{
			::logError("mod_bg_unique_perks: 骨刺反伤失败: " + e);
		}
	}, data);
}

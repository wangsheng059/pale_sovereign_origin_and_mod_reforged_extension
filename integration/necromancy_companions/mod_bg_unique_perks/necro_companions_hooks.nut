// 1.5.0 死灵精通 × 配件兄弟：驯服亡灵
// 配件兄弟的 resolveTameType 不知道是谁在驯服，这里在驯服技能判断目标 / 使用时记下使用者（necro_ac_library.nut 里读取）；
// 驯服成功后把配件的属性、名字改成被驯服的亡灵自己的
if (::BGP.HasAC)
{
	::LocalNecroAC.hook("scripts/companions/player/companions_tame", function(q)
	{
		q.onVerifyTarget = @(__original) function( _originTile, _targetTile )
		{
			local prev = ::BGP.NecroPet.TamingActor;
			::BGP.NecroPet.TamingActor = this.getContainer().getActor();
			local ret = false;
			try
			{
				ret = __original(_originTile, _targetTile);
			}
			catch (e)
			{
				::BGP.NecroPet.TamingActor = prev;
				throw e;
			}
			::BGP.NecroPet.TamingActor = prev;
			return ret;
		}

		q.onUse = @(__original) function( _user, _targetTile )
		{
			local actor = this.getContainer().getActor();
			local target = null;
			local before = null;
			try { target = _targetTile.getEntity(); } catch (e) { target = null; }
			try { before = actor.getItems().getItemAtSlot(::Const.ItemSlot.Accessory); } catch (e) { before = null; }

			local prev = ::BGP.NecroPet.TamingActor;
			::BGP.NecroPet.TamingActor = actor;
			local ret = false;
			try
			{
				ret = __original(_user, _targetTile);
			}
			catch (e)
			{
				::BGP.NecroPet.TamingActor = prev;
				throw e;
			}
			::BGP.NecroPet.TamingActor = prev;

			try
			{
				local acc = actor.getItems().getItemAtSlot(::Const.ItemSlot.Accessory);
				if (target != null && !target.isAlive() && acc != null && acc != before && ("getType" in acc) && ::BGP.NecroPet.isOwnType(acc.getType()))
					::BGP.NecroPet.fillFromEntity(acc, target);
			}
			catch (e)
			{
				::logError("mod_bg_unique_perks: 驯服亡灵后设置配件失败: " + e);
			}
			return ret;
		}
	});

	// 1.5.1 死灵宠物的装备记录跟着配件兄弟的名字串存档（配件兄弟的 rawHookTree 先给每个宠物配件类装上
	// serializeCompanionName / deserializeCompanionName，这里再包一层；本队列排在 mod_AC 之后注册）
	::LocalNecroAC.rawHookTree("scripts/items/accessory/accessory", function(p)
	{
		if (!("serializeCompanionName" in p) || !("deserializeCompanionName" in p))
			return;
		if ("BGP_GearApplied" in p.m)
			return;
		p.m.BGP_GearApplied <- true;
		p.m.BGP_Gear <- null;
		// 1.6.0 永恒禁卫宠物倒下、等待“不灭号令”时为 true（只在战斗中有意义，不存档）
		p.m.BGP_GuardDown <- false;

		if ("onCombatFinished" in p)
		{
			local fin = p.onCombatFinished;
			p.onCombatFinished <- function()
			{
				local down = this.m.BGP_GuardDown;
				fin.call(this);
				if (down)
				{
					// 主人活到战斗结束，倒下的永恒禁卫保留，伤势记为 50%
					this.m.BGP_GuardDown = false;
					this.m.Wounds = 50;
				}
			}
		}

		local ser = p.serializeCompanionName;
		p.serializeCompanionName <- function()
		{
			return ::BGP.NecroPet.serializeName(this, ser);
		}

		local des = p.deserializeCompanionName;
		p.deserializeCompanionName <- function( _cn )
		{
			::BGP.NecroPet.deserializeName(this, des, _cn);
		}

		// 1.5.2 死灵宠物升级时用亡灵特质池，11 级的好孩子换成死灵契约
		if ("updateLevel" in p)
		{
			local upd = p.updateLevel;
			p.updateLevel <- function()
			{
				::BGP.NecroPet.updateLevel(this, upd);
			}
		}
	});

	// 1.5.1 只有死灵法师能装备死灵宠物（和重铸老剑师起源、德鲁伊 mod 一样，在装备时拒绝）
	// 读档时原版也是用 equip 把物品放回身上，读档过程中不拦，免得 1.5.0 存档里别人身上的死灵宠物丢失
	::LocalNecroAC.hook("scripts/items/item_container", function(q)
	{
		q.equip = @(__original) function( _item )
		{
			try
			{
				if (!::BGP.NecroPet.IsLoading && _item != null && this.m.Actor != null && !::MSU.isNull(this.m.Actor) && !::BGP.NecroPet.canEquip(this.m.Actor, _item))
					return false;
			}
			catch (e)
			{
			}
			return __original(_item);
		}

		q.onDeserialize = @(__original) function( _in )
		{
			local prev = ::BGP.NecroPet.IsLoading;
			::BGP.NecroPet.IsLoading = true;
			try
			{
				__original(_in);
			}
			catch (e)
			{
				::BGP.NecroPet.IsLoading = prev;
				throw e;
			}
			::BGP.NecroPet.IsLoading = prev;
		}
	});
}

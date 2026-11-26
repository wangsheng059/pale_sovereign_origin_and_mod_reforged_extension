// 公用工具函数

::BGP.isValid <- function( _a )
{
	if (_a == null)
		return false;
	if (_a instanceof ::WeakTableRef && _a.isNull())
		return false;
	try
	{
		return _a.isAlive() && !_a.isDying() && _a.isPlacedOnMap();
	}
	catch (e)
	{
		return false;
	}
}

::BGP.distance <- function( _a, _b )
{
	try
	{
		return _a.getTile().getDistanceTo(_b.getTile());
	}
	catch (e)
	{
		return 9999;
	}
}

// 友方野兽：战团的野兽阵营（PlayerAnimals），配件兄弟宠物 / 原版战犬（有 m.Item）或者不是亡灵的单位（德鲁伊召唤兽等）。
// 配件兄弟复活的亡灵没有 m.Item 且带 undead 旗标，不算。
::BGP.isFriendlyBeast <- function( _a )
{
	if (!::BGP.isValid(_a))
		return false;
	try
	{
		if (_a.getFaction() != ::Const.Faction.PlayerAnimals)
			return false;
	}
	catch (e)
	{
		return false;
	}

	local hasItem = false;
	try { hasItem = _a.m.Item != null && !(_a.m.Item instanceof ::WeakTableRef && _a.m.Item.isNull()); } catch (e) { hasItem = false; }
	if (hasItem)
		return true;

	try { return !_a.getFlags().has("undead"); } catch (e) { return false; }
	return false;
}

::BGP.getAllActors <- function()
{
	try
	{
		return ::Tactical.Entities.getAllInstancesAsArray();
	}
	catch (e)
	{
		return [];
	}
}

::BGP.getFriendlyBeasts <- function()
{
	local ret = [];
	foreach (a in ::BGP.getAllActors())
	{
		if (::BGP.isFriendlyBeast(a))
			ret.push(a);
	}
	return ret;
}

// 场上（战团阵营、活着）带某个特技的角色
::BGP.getBrosWithSkill <- function( _id )
{
	local ret = [];
	foreach (a in ::BGP.getAllActors())
	{
		if (!::BGP.isValid(a))
			continue;
		try
		{
			if (a.getFaction() == ::Const.Faction.Player && a.getSkills().hasSkill(_id))
				ret.push(a);
		}
		catch (e)
		{
		}
	}
	return ret;
}

::BGP.isInBattle <- function()
{
	try
	{
		return ("State" in ::Tactical) && ::Tactical.State != null && ::Tactical.isActive();
	}
	catch (e)
	{
		return false;
	}
}

::BGP.getRound <- function()
{
	try
	{
		return ::Tactical.TurnSequenceBar.getCurrentRound();
	}
	catch (e)
	{
		return 0;
	}
}

::BGP.log <- function( _actor, _text )
{
	try
	{
		if (_actor != null && !_actor.isHiddenToPlayer())
			::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(_actor) + _text);
	}
	catch (e)
	{
	}
}

::BGP.reduceFatigue <- function( _actor, _amount )
{
	try
	{
		_actor.setFatigue(::Math.max(0, _actor.getFatigue() - _amount));
	}
	catch (e)
	{
	}
}

// 给场上所有友方野兽补上联动效果（兽群领袖光环、狩猎狂热计数、士气保护都在这个效果里）
::BGP.ensureBeastLinks <- function()
{
	foreach (b in ::BGP.getFriendlyBeasts())
	{
		try
		{
			if (!b.getSkills().hasSkill("effects.bgp_beast_link"))
				b.getSkills().add(::new("scripts/skills/effects/bgp_beast_link_effect"));
		}
		catch (e)
		{
			::logError("mod_bg_unique_perks: 添加野兽联动效果失败: " + e);
		}
	}
}

// 狩猎狂热：场上有带“狩猎狂热”特技的驯兽师时，驯兽师本人和所有友方野兽各叠 1 层
::BGP.triggerHuntingFever <- function()
{
	local masters = ::BGP.getBrosWithSkill("perk.bgp_hunting_fever");
	if (masters.len() == 0)
		return;

	local targets = clone masters;
	targets.extend(::BGP.getFriendlyBeasts());
	foreach (a in targets)
	{
		try
		{
			local fx = a.getSkills().getSkillByID("effects.bgp_hunting_fever");
			if (fx == null)
			{
				fx = ::new("scripts/skills/effects/bgp_hunting_fever_effect");
				a.getSkills().add(fx);
			}
			fx.addStack();
		}
		catch (e)
		{
			::logError("mod_bg_unique_perks: 狩猎狂热叠层失败: " + e);
		}
	}
}

// 战团（名册）里是否有人带某个特技；结果缓存 1 秒，薪水界面会频繁调用
::BGP.CompanyPerkCache <- {};
::BGP.companyHasPerk <- function( _id )
{
	local now = 0.0;
	try { now = ::Time.getRealTimeF(); } catch (e) { now = 0.0; }

	if (_id in ::BGP.CompanyPerkCache)
	{
		local c = ::BGP.CompanyPerkCache[_id];
		if (now - c.Time < 1.0 && now >= c.Time)
			return c.Value;
	}

	local value = false;
	try
	{
		foreach (bro in ::World.getPlayerRoster().getAll())
		{
			if (bro.getSkills().hasSkill(_id))
			{
				value = true;
				break;
			}
		}
	}
	catch (e)
	{
		value = false;
	}

	::BGP.CompanyPerkCache[_id] <- { Time = now, Value = value };
	return value;
}

::BGP.isInRoster <- function( _bro )
{
	try
	{
		local id = _bro.getID();
		foreach (b in ::World.getPlayerRoster().getAll())
		{
			if (b.getID() == id)
				return true;
		}
	}
	catch (e)
	{
	}
	return false;
}

::BGP.isSwordSkill <- function( _skill )
{
	try
	{
		local item = _skill.getItem();
		if (item == null || (item instanceof ::WeakTableRef && item.isNull()))
			return false;
		return item.isItemType(::Const.Items.ItemType.Weapon) && item.isWeaponType(::Const.Items.WeaponType.Sword);
	}
	catch (e)
	{
		return false;
	}
}

::BGP.countInjuries <- function( _actor )
{
	try
	{
		return _actor.getSkills().getAllSkillsOfType(::Const.SkillType.TemporaryInjury).len();
	}
	catch (e)
	{
		return 0;
	}
}

::BGP.countSkillByID <- function( _actor, _id )
{
	local n = 0;
	try
	{
		foreach (s in _actor.getSkills().m.Skills)
		{
			if (!s.isGarbage() && s.getID() == _id)
				n++;
		}
	}
	catch (e)
	{
		return 0;
	}
	return n;
}

// Count total bleeding stacks (handles both Reforged single-instance m.Stacks and vanilla multi-instance bleeding).
::BGP.countBleedingStacks <- function( _actor )
{
	local total = 0;
	try
	{
		foreach (s in _actor.getSkills().m.Skills)
		{
			if (!s.isGarbage() && s.getID() == "effects.bleeding")
				total += ("Stacks" in s.m && s.m.Stacks != null) ? s.m.Stacks : 1;
		}
	}
	catch (e)
	{
		return 0;
	}
	return total;
}

// “战争艺术”：贵族的主动指挥类技能
::BGP.CommandSkillIDs <- [
	"actives.rally_the_troops",
	"actives.rf_command",
	"actives.rf_hold_steady",
	"actives.rf_onslaught",
	"actives.rf_encourage",
	"actives.bgp_discerning"
];

// 宠物的主人：配件兄弟宠物 / 原版战犬的物品装在哪个兄弟身上
::BGP.getPetOwner <- function( _pet )
{
	try
	{
		local item = _pet.m.Item;
		if (item == null || (item instanceof ::WeakTableRef && item.isNull()))
			return null;
		local c = item.getContainer();
		if (c == null)
			return null;
		local owner = c.getActor();
		if (owner == null || (owner instanceof ::WeakTableRef && owner.isNull()))
			return null;
		return owner;
	}
	catch (e)
	{
		return null;
	}
}

::BGP.getOwnPets <- function( _owner )
{
	local ret = [];
	foreach (b in ::BGP.getFriendlyBeasts())
	{
		local o = ::BGP.getPetOwner(b);
		if (o != null && o.getID() == _owner.getID())
			ret.push(b);
	}
	return ret;
}

::BGP.hasOwnPetAdjacent <- function( _owner )
{
	if (!::BGP.isValid(_owner))
		return false;
	foreach (p in ::BGP.getOwnPets(_owner))
	{
		if (::BGP.distance(p, _owner) == 1)
			return true;
	}
	return false;
}

// 同仇敌忾：驯兽师本人和他自己的宠物各叠 1 层
::BGP.triggerSharedHatred <- function( _owner )
{
	if (!::BGP.isValid(_owner) || !_owner.getSkills().hasSkill("perk.bgp_shared_hatred"))
		return;

	local targets = [_owner];
	targets.extend(::BGP.getOwnPets(_owner));
	foreach (a in targets)
	{
		try
		{
			local fx = a.getSkills().getSkillByID("effects.bgp_shared_hatred");
			if (fx == null)
			{
				fx = ::new("scripts/skills/effects/bgp_shared_hatred_effect");
				a.getSkills().add(fx);
			}
			fx.addStack();
		}
		catch (e)
		{
			::logError("mod_bg_unique_perks: 同仇叠层失败: " + e);
		}
	}
}

// ---------------------------------------------------------------------------
// 1.3.0 统帅组公用
// ---------------------------------------------------------------------------

// 达库尔信徒阶位：原版六个信徒特质（1 盲信者 … 6 先知）；信徒背景但没有阶位特质为 0；不是信徒为 -1
::BGP.CultistTraits <- [
	"trait.cultist_fanatic",
	"trait.cultist_zealot",
	"trait.cultist_acolyte",
	"trait.cultist_disciple",
	"trait.cultist_chosen",
	"trait.cultist_prophet"
];

::BGP.getCultistTier <- function( _a )
{
	try
	{
		local skills = _a.getSkills();
		for (local i = ::BGP.CultistTraits.len() - 1; i >= 0; i--)
		{
			if (skills.hasSkill(::BGP.CultistTraits[i]))
				return i + 1;
		}
		local id = _a.getBackground().getID();
		if (id == "background.cultist" || id == "background.converted_cultist")
			return 0;
	}
	catch (e)
	{
	}
	return -1;
}

// 统帅身份：统帅背景加入时打上的角色标记，达库尔转化只换背景，标记保留
::BGP.isCommander <- function( _a )
{
	try { return _a.getFlags().get("bgp_commander") == true; } catch (e) { return false; }
	return false;
}

// 属性：天赋下标 → 基础属性字段、参考值（用于星级并列时比较）、属性倍率字段、名称
::BGP.AttrInfo <- [];
::BGP.initAttrInfo <- function()
{
	local A = ::Const.Attributes;
	::BGP.AttrInfo = [];
	::BGP.AttrInfo.resize(A.COUNT, null);
	::BGP.AttrInfo[A.Hitpoints] = { Field = "Hitpoints", Ref = 60.0, Mult = "HitpointsMult", Name = "生命值", Kind = 0 };
	::BGP.AttrInfo[A.Fatigue] = { Field = "Stamina", Ref = 100.0, Mult = "StaminaMult", Name = "疲劳上限", Kind = 0 };
	::BGP.AttrInfo[A.Initiative] = { Field = "Initiative", Ref = 110.0, Mult = "InitiativeMult", Name = "主动值", Kind = 1 };
	::BGP.AttrInfo[A.RangedSkill] = { Field = "RangedSkill", Ref = 50.0, Mult = "RangedSkillMult", Name = "远程技能", Kind = 1 };
	::BGP.AttrInfo[A.RangedDefense] = { Field = "RangedDefense", Ref = 10.0, Mult = "RangedDefenseMult", Name = "远程防御", Kind = 1 };
	::BGP.AttrInfo[A.MeleeSkill] = { Field = "MeleeSkill", Ref = 60.0, Mult = "MeleeSkillMult", Name = "近战技能", Kind = 2 };
	::BGP.AttrInfo[A.MeleeDefense] = { Field = "MeleeDefense", Ref = 10.0, Mult = "MeleeDefenseMult", Name = "近战防御", Kind = 2 };
	::BGP.AttrInfo[A.Bravery] = { Field = "Bravery", Ref = 45.0, Mult = "BraveryMult", Name = "决心", Kind = 2 };
}

// 天赋星级最高的属性；星级并列（或都没有星）时取基础值相对参考值最高的一项
// 返回 { Attr, Stars }，拿不到天赋时返回 null
::BGP.getTopTalent <- function( _a )
{
	try
	{
		if (::BGP.AttrInfo.len() == 0)
			::BGP.initAttrInfo();
		local talents = _a.getTalents();
		if (talents == null || talents.len() == 0)
			return null;
		local bp = _a.getBaseProperties();
		local best = -1;
		local bestStars = -1;
		local bestScore = -1.0;
		for (local i = 0; i < ::BGP.AttrInfo.len() && i < talents.len(); i++)
		{
			local info = ::BGP.AttrInfo[i];
			if (info == null)
				continue;
			local stars = talents[i];
			local score = bp[info.Field] / info.Ref;
			if (stars > bestStars || (stars == bestStars && score > bestScore))
			{
				best = i;
				bestStars = stars;
				bestScore = score;
			}
		}
		if (best < 0)
			return null;
		return { Attr = best, Stars = bestStars };
	}
	catch (e)
	{
		return null;
	}
}

// 目标盾牌提供的近战防御（盾墙额外那份按一半算），用于“无视盾牌近防”
::BGP.getShieldCompensation <- function( _target )
{
	try
	{
		local shield = _target.getItems().getItemAtSlot(::Const.ItemSlot.Offhand);
		if (shield == null || !shield.isItemType(::Const.Items.ItemType.Shield))
			return 0;
		local def = shield.getMeleeDefense();
		if (def <= 0)
			return 0;
		local ret = def;
		if (_target.getSkills().hasSkill("effects.shieldwall"))
			ret += ::Math.floor(def * 0.5);
		return ret;
	}
	catch (e)
	{
		return 0;
	}
}

::BGP.hasShield <- function( _a )
{
	try
	{
		local item = _a.getItems().getItemAtSlot(::Const.ItemSlot.Offhand);
		return item != null && item.isItemType(::Const.Items.ItemType.Shield);
	}
	catch (e)
	{
		return false;
	}
}

// 相邻 6 格的敌人 / 友军数量
::BGP.countAdjacent <- function( _a )
{
	local ret = { Enemies = 0, Allies = 0, List = [] };
	try
	{
		local tile = _a.getTile();
		for (local i = 0; i < 6; i++)
		{
			if (!tile.hasNextTile(i))
				continue;
			local t = tile.getNextTile(i);
			if (!t.IsOccupiedByActor)
				continue;
			local e = t.getEntity();
			if (!::BGP.isValid(e))
				continue;
			ret.List.push(e);
			if (e.isAlliedWith(_a))
				ret.Allies++;
			else
				ret.Enemies++;
		}
	}
	catch (e)
	{
	}
	return ret;
}

// 场上战团成员（玩家阵营的人，不含野兽）
::BGP.getCompany <- function()
{
	local ret = [];
	foreach (a in ::BGP.getAllActors())
	{
		if (!::BGP.isValid(a))
			continue;
		try
		{
			if (a.getFaction() == ::Const.Faction.Player)
				ret.push(a);
		}
		catch (e)
		{
		}
	}
	return ret;
}

// 千面归一：场上战团成员主手武器的不同类型数（空手 / 非武器算一类）
::BGP.countWeaponTypes <- function()
{
	local seen = {};
	local n = 0;
	foreach (a in ::BGP.getCompany())
	{
		local key = "none";
		try
		{
			local item = a.getItems().getItemAtSlot(::Const.ItemSlot.Mainhand);
			if (item != null && item.isItemType(::Const.Items.ItemType.Weapon))
				key = "w" + item.m.WeaponType;
		}
		catch (e)
		{
			key = "none";
		}
		if (!(key in seen))
		{
			seen[key] <- true;
			n++;
		}
	}
	return n;
}

// 统帅组的光环 / 全队效果都挂在每个战团成员的 effects.bgp_command_link 上
::BGP.ensureCommandLinks <- function()
{
	foreach (a in ::BGP.getCompany())
	{
		try
		{
			if (!a.getSkills().hasSkill("effects.bgp_command_link"))
				a.getSkills().add(::new("scripts/skills/effects/bgp_command_link_effect"));
		}
		catch (e)
		{
			::logError("mod_bg_unique_perks: 添加统帅联动效果失败: " + e);
		}
	}
}

::BGP.isActiveEntity <- function( _a )
{
	try { return ::Tactical.TurnSequenceBar.isActiveEntity(_a); } catch (e) { return false; }
	return false;
}

::BGP.restoreAP <- function( _a, _amount )
{
	try
	{
		local ap = ::Math.min(_a.getActionPointsMax(), _a.getActionPoints() + _amount);
		if (ap > _a.getActionPoints())
			_a.setActionPoints(ap);
	}
	catch (e)
	{
	}
}

::BGP.heal <- function( _a, _amount )
{
	try
	{
		if (_amount <= 0)
			return;
		_a.setHitpoints(::Math.min(_a.getHitpointsMax(), _a.getHitpoints() + _amount));
		_a.setDirty(true);
	}
	catch (e)
	{
	}
}

// 化瑕为瑜的特质 / 伤势分类
::BGP.FlawsMental <- ["trait.dumb", "injury.brain_damage", "trait.irrational"];
::BGP.FlawsCoward <- ["trait.craven", "trait.dastard", "trait.fainthearted", "trait.hesitant", "trait.insecure"];
::BGP.FlawsAsthma <- ["trait.asthmatic"];
::BGP.FlawsSight <- ["trait.short_sighted", "trait.night_blind"];
::BGP.FlawsGreed <- ["trait.greedy", "trait.impatient", "trait.bloodthirsty"];

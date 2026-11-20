// 捕奴背景扩展
// 给“人类奴隶捕获”（hsc_human_slave_capture）的背景推断规则加上其他 mod 的背景和若干重铸敌人的对应关系。
// 只往 ::HumanSlaveCapture.BackgroundRules 前面插规则，不改捕奴 mod 的文件；对应背景脚本不存在时该条规则不加。
//
// 1. 北境扩张：野蛮人神选者（原版类名 barbarian_champion，1.0.4 补上）、蛮王（barbarian_chosen）→ 神选者（barbarian_chosen_background）
// 2. 重铸：剑术大师、黑金字塔的盗贼剑圣 / 剑舞者 / 决斗者 → 成名剑师（rf_renowned_swordmaster_background）
// 3. 配件兄弟：驯犬师、驯兽人、野蛮人驯兽人 → 驯兽师（配件兄弟改造的驯犬师背景）
// 4. 重铸：传令官 → 冒险贵族；强盗男爵、元帅 → 统帅（背景专属特技 mod 的 bgp_commander_background，没装时退回冒险贵族，1.0.3）；击剑手 → 剑术大师；重装兵 → 侍从；重步兵 → 退役士兵
// 5. 背景专属特技 mod：执誓者敌人（oathbringer / firstborn / paladin）→ 老执誓者（bgp_old_oathtaker_background，1.0.1）
// 6. 旧俘虏修正（1.0.5）：装本 mod 新规则之前抓的俘虏，背景是按旧规则存的；读档和招募时按俘虏的敌人名字反查类名，
//    旧规则结果和新规则不同就换成新规则的背景（例如 1.0.4 之前抓的野蛮人神选者：野蛮人 → 神选者）。有自定义名字的冠军反查不到，不改。
// 7. 背景专属特技 mod：死灵法师 necromancer → 死灵法师（bgp_necromancer_background，1.0.6）；寻衅侍僧、大先知仍为佣兵

::HSC_BgExt <- {
	ID = "mod_hsc_bg_ext",
	Version = "1.0.6",
	Name = "捕奴背景扩展",
	BeastmasterBackground = "hsc_ac_beastmaster_background",
	ForceBeastmaster = false,
	AddedRules = [],
	BaseRules = [],
	NameToClass = null
};

::HSC_BgExt.HooksMod <- ::Hooks.register(::HSC_BgExt.ID, ::HSC_BgExt.Version, ::HSC_BgExt.Name);
::HSC_BgExt.HooksMod.require("hsc_human_slave_capture");

::HSC_BgExt.hasBackground <- function( _name )
{
	try
	{
		foreach (f in ::IO.enumerateFiles("scripts/skills/backgrounds/"))
		{
			if (f == "scripts/skills/backgrounds/" + _name)
				return true;
		}
	}
	catch (e)
	{
	}
	return false;
}

::HSC_BgExt.matchRules <- function( _rules, _className )
{
	foreach (rule in _rules)
	{
		if (_className.find(rule[0]) != null) return rule[1];
	}
	return null;
}

// EntityType 的键名（BarbarianChampion、RF_BanditBaron）转成类名（barbarian_champion、rf_bandit_baron）
::HSC_BgExt.toClassName <- function( _key )
{
	local out = "";
	local prev = 0;
	for (local i = 0; i < _key.len(); i++)
	{
		local c = _key[i];
		local isUpper = c >= 65 && c <= 90;
		local prevLowerOrDigit = (prev >= 97 && prev <= 122) || (prev >= 48 && prev <= 57);
		if (isUpper && prevLowerOrDigit) out += "_";
		out += (isUpper ? c + 32 : c).tochar();
		prev = c;
	}
	return out;
}

// 敌人显示名 -> 类名；同名对应多个类名时不收（避免改错）
::HSC_BgExt.getNameToClass <- function()
{
	if (this.NameToClass != null) return this.NameToClass;

	local map = {};
	local dup = {};
	try
	{
		foreach (key, value in ::Const.EntityType)
		{
			if (typeof value != "integer") continue;
			local name = null;
			try { name = ::Const.Strings.EntityName[value]; } catch (e) { name = null; }
			if (name == null || name == "") continue;
			local cls = this.toClassName(key);
			if (name in map)
			{
				if (map[name] != cls) dup[name] <- true;
			}
			else
			{
				map[name] <- cls;
			}
		}
	}
	catch (e)
	{
	}
	foreach (name, v in dup) delete map[name];

	this.NameToClass = map;
	return map;
}

// 返回修正后的背景；不需要改时原样返回
::HSC_BgExt.fixStaleBackground <- function( _background, _displayName )
{
	try
	{
		if (_background == null || _displayName == null || _displayName == "") return _background;
		if (this.AddedRules.len() == 0) return _background;

		local map = this.getNameToClass();
		if (!(_displayName in map)) return _background;

		local cls = map[_displayName];
		local newBg = this.matchRules(this.AddedRules, cls);
		if (newBg == null || newBg == _background) return _background;

		// 只改“按旧规则得出的结果”，玩家或其他 mod 改过的背景不动
		local oldBg = this.matchRules(this.BaseRules, cls);
		if (oldBg == null) oldBg = "sellsword_background";
		if (oldBg != _background) return _background;

		::logInfo("mod_hsc_bg_ext: 旧俘虏背景修正 " + _displayName + " (" + cls + "): " + _background + " -> " + newBg);
		return newBg;
	}
	catch (e)
	{
	}
	return _background;
}

::HSC_BgExt.HooksMod.queue([">hsc_human_slave_capture", ">mod_AC", ">mod_reforged", ">mod_local_rules"], function()
{
	// 配件兄弟的驯兽师不是单独的背景脚本：这里在新兄弟的驯犬师背景加入时改造成驯兽师（和配件兄弟在驯兽城镇招募的做法相同）
	::HSC_BgExt.HooksMod.hook("scripts/skills/backgrounds/houndmaster_background", function(q)
	{
		q.onAdded = @(__original) function()
		{
			if (::HSC_BgExt.ForceBeastmaster && this.m.IsNew && this.m.ID == "background.houndmaster")
			{
				try { this.applyBeastmasterModification(); }
				catch (e) { ::logError("mod_hsc_bg_ext: 驯兽师改造失败: " + e); }
			}
			__original();
		}
	});

	// 旧俘虏：读档时把仓库里俘虏物品的背景改成新规则的结果，提示、估价、试炼也跟着对（1.0.5）
	::HSC_BgExt.HooksMod.hook("scripts/items/misc/hsc_captive_item", function(q)
	{
		q.onDeserialize = @(__original) function( _in )
		{
			__original(_in);
			try
			{
				local fixed = ::HSC_BgExt.fixStaleBackground(this.m.HSC_Background, this.m.HSC_BackgroundName);
				if (fixed != this.m.HSC_Background)
				{
					this.m.HSC_Background = fixed;
					try { this.m.HSC_Value = ::HumanSlaveCapture.computeCaptiveValue(fixed, this.m.HSC_Level, this.m.HSC_Champion); } catch (e) {}
					this.HSC_refresh();
				}
			}
			catch (e) {}
		}
	});
});

::HSC_BgExt.HooksMod.queue([">hsc_human_slave_capture", ">mod_AC", ">mod_reforged", ">mod_local_rules"], function()
{
	local H = ::HumanSlaveCapture;
	local ext = ::HSC_BgExt;
	local candidates = [];

	// 背景专属特技 mod 的老执誓者（原版执誓者和老执誓者都不动）
	// 北境扩张的 barbarian_firstborn 不是执誓者，先占住免得被“firstborn”误匹配（1.0.4）
	candidates.push(["barbarian_firstborn", "barbarian_background"]);
	candidates.push(["oathbringer", "bgp_old_oathtaker_background"]);
	candidates.push(["firstborn", "bgp_old_oathtaker_background"]);
	candidates.push(["paladin", "bgp_old_oathtaker_background"]);

	// 背景专属特技 mod 的死灵法师（1.0.6）
	candidates.push(["necromancer", "bgp_necromancer_background"]);

	// 北境扩张
	// 原版“野蛮人神选者”的类名是 barbarian_champion；barbarian_chosen 是蛮王
	candidates.push(["barbarian_champion", "barbarian_chosen_background"]);
	candidates.push(["barbarian_chosen", "barbarian_chosen_background"]);

	// 重铸的人类敌人（类名都以 rf_ 开头；传令官侍卫保持原来的兜底背景，免得被“rf_herald”误匹配）
	candidates.push(["rf_heralds_bodyguard", "sellsword_background"]);
	// 强盗男爵、元帅：背景专属特技 mod 的“统帅”，没装时退回冒险贵族；传令官：冒险贵族
	local commander = ext.hasBackground("bgp_commander_background") ? "bgp_commander_background" : "adventurous_noble_background";
	candidates.push(["rf_bandit_baron", commander]);
	candidates.push(["rf_herald", "adventurous_noble_background"]);
	candidates.push(["rf_marshal", commander]);
	candidates.push(["rf_fencer", "swordmaster_background"]);
	candidates.push(["rf_man_at_arms", "squire_background"]);
	candidates.push(["rf_footman_heavy", "retired_soldier_background"]);

	// 成名剑师
	candidates.push(["rr_bandit_blademaster", "rf_renowned_swordmaster_background"]);
	candidates.push(["rr_bandit_blade_dancer", "rf_renowned_swordmaster_background"]);
	candidates.push(["rr_bandit_duelist", "rf_renowned_swordmaster_background"]);
	candidates.push(["swordmaster", "rf_renowned_swordmaster_background"]);

	// 配件兄弟驯兽师
	if (::Hooks.hasMod("mod_AC"))
	{
		candidates.push(["barbarian_beastmaster", ext.BeastmasterBackground]);
		candidates.push(["beastmaster", ext.BeastmasterBackground]);
		candidates.push(["houndmaster", ext.BeastmasterBackground]);
	}

	local rules = [];
	foreach (r in candidates)
	{
		if (ext.hasBackground(r[1]))
			rules.push(r);
	}

	ext.AddedRules = clone rules;
	ext.BaseRules = clone H.BackgroundRules;
	rules.extend(H.BackgroundRules);
	H.BackgroundRules = rules;

	// 驯兽师：俘虏记录里存占位背景 hsc_ac_beastmaster_background（真实脚本，供估价、试炼等用），
	// 招募成兄弟时换回驯犬师背景并改造，存档里和配件兄弟招募的驯兽师完全一样，删掉本 mod 也不影响已招募的兄弟
	local createBrother = H.createBrother;
	H.createBrother = function( _entry, _level, _extraPerkPoints )
	{
		try
		{
			local fixed = ::HSC_BgExt.fixStaleBackground(_entry.Background, _entry.BackgroundName);
			if (fixed != _entry.Background)
			{
				_entry = clone _entry;
				_entry.Background = fixed;
			}
		}
		catch (e) {}

		local isBeastmaster = false;
		try { isBeastmaster = _entry.Background == ::HSC_BgExt.BeastmasterBackground; } catch (e) {}

		if (!isBeastmaster)
			return createBrother.call(this, _entry, _level, _extraPerkPoints);

		local entry = clone _entry;
		entry.Background = "houndmaster_background";
		::HSC_BgExt.ForceBeastmaster = true;
		local bro = null;
		try
		{
			bro = createBrother.call(this, entry, _level, _extraPerkPoints);
		}
		catch (e)
		{
			::HSC_BgExt.ForceBeastmaster = false;
			throw e;
		}
		::HSC_BgExt.ForceBeastmaster = false;
		return bro;
	}

	// 英文模式下的显示名
	local getNameEN = H.getBackgroundNameEN;
	H.getBackgroundNameEN = function( _background )
	{
		if (_background == "barbarian_chosen_background") return "Chosen";
		if (_background == "rf_renowned_swordmaster_background") return "Renowned Swordmaster";
		if (_background == ::HSC_BgExt.BeastmasterBackground) return "Beastmaster";
		if (_background == "bgp_old_oathtaker_background") return "Old Oathtaker";
		if (_background == "bgp_commander_background") return "Commander";
		if (_background == "bgp_necromancer_background") return "Necromancer";
		return getNameEN.call(this, _background);
	}

	::logInfo("mod_hsc_bg_ext: 已加入 " + ext.AddedRules.len() + " 条背景规则");
});

// 冠军加成数据：照抄潘多拉的嗜好 1.2.18 各野兽 makeMiniboss 的内容
// （mod_pandoras_hobby/hooks/entity/tactical/enemies/*.nut）。
// 只依赖 mod_hardened 的技能没有收录（本整合没有装 Hardened）。
//
// 存档按 ChampionOrder 的下标写入配件兄弟的特质表，只能在末尾追加，不能改顺序。

::AC_PH_Compat.ChampionOrder <- [
	"direwolf",
	"hyena",
	"spider_venom",
	"spider_brute",
	"spider_swift",
	"serpent",
	"ghoul",
	"alp",
	"unhold",
	"unhold_bog",
	"unhold_frost",
	"schrat",
	"lindwurm"
];

::AC_PH_Compat.Champions <- {
	direwolf = {
		Label = "恐狼",
		Stats = { Bravery = 20, MeleeDefense = 5, RangedDefense = 5 },
		Armor = 50,
		Perks = [],
		OverwhelmOrFearsome = true,
		Brushes = { body = "ph_bust_direwolf_champ", head = "ph_bust_direwolf_champ_head" }
	},
	hyena = {
		Label = "鬣狗",
		Stats = { Hitpoints = 30, Bravery = 20, DamageArmorMult = 0.3 },
		Perks = [],
		OverwhelmOrFearsome = true
	},
	spider_venom = {
		Label = "剧毒蛛魔",
		Stats = { Bravery = 20, MeleeSkill = 10, Hitpoints = 20, MeleeDefense = 10, RangedDefense = 10, DamageDirectAdd = 0.1 },
		Perks = ["scripts/skills/ph_champs/ph_champ_venom", "scripts/skills/perks/perk_fast_adaption"],
		Size = 0.75,
		SpiderVariant = 420
	},
	spider_brute = {
		Label = "巨颚蛛魔",
		Stats = { Bravery = 20, ActionPoints = -2, Hitpoints = 50, MeleeSkill = 15, MeleeDefense = -10, RangedDefense = -10, DamageRegularMin = 5, DamageRegularMax = 20, Reach = 1 },
		Perks = ["scripts/skills/perks/perk_fearsome", "scripts/skills/perks/perk_fast_adaption"],
		Size = 1.0,
		SpiderVariant = 421
	},
	spider_swift = {
		Label = "迅捷蛛魔",
		Stats = { Bravery = 20, ActionPoints = 1, Hitpoints = 10, Initiative = 110 },
		Perks = ["scripts/skills/effects/dodge_effect", "scripts/skills/perks/perk_nimble", "scripts/skills/perks/perk_fast_adaption"],
		Size = 0.65,
		SpiderVariant = 422
	},
	serpent = {
		Label = "毒蛇",
		Stats = { Hitpoints = 30, Initiative = 30, RangedDefense = 5 },
		Perks = ["scripts/skills/perks/perk_anticipation", "scripts/skills/perks/perk_rf_calculated_strikes"]
	},
	ghoul = {
		Label = "食尸鬼",
		Stats = {},
		Perks = [],
		GhoulBySize = true
	},
	alp = {
		Label = "梦魇",
		Stats = { Hitpoints = 30 },
		Perks = ["scripts/skills/perks/perk_coup_de_grace"]
	},
	unhold = {
		Label = "巨人",
		Stats = { Hitpoints = 200 },
		Perks = ["scripts/skills/perks/perk_lone_wolf"]
	},
	unhold_bog = {
		Label = "沼泽巨人",
		Stats = { Hitpoints = 100 },
		Perks = ["scripts/skills/perks/perk_lone_wolf", "scripts/skills/perks/perk_rf_feral_rage"]
	},
	unhold_frost = {
		Label = "冰霜巨人",
		Stats = { Hitpoints = 100 },
		Perks = ["scripts/skills/perks/perk_lone_wolf", "scripts/skills/perks/perk_rf_feral_rage", "scripts/skills/perks/perk_rf_bully"]
	},
	schrat = {
		Label = "树人",
		Stats = { Hitpoints = 200, Initiative = -20 },
		Perks = ["scripts/skills/perks/perk_rf_strength_in_numbers", "scripts/skills/perks/perk_rf_unstoppable"]
	},
	lindwurm = {
		Label = "林德龙",
		Stats = { Hitpoints = 100, Initiative = 20 },
		Perks = ["scripts/skills/perks/perk_anticipation", "scripts/skills/perks/perk_rf_calculated_strikes"]
	}
};

::AC_PH_Compat.getChampionQuirkID <- function( _key )
{
	return "quirk.ac_ph_champion_" + _key;
}

::AC_PH_Compat.getChampionQuirkScript <- function( _key )
{
	return "scripts/companions/quirks/ac_ph_champion_" + _key;
}

// 被驯服的目标是冠军时，返回对应的冠军键；不是冠军或不支持的种类返回 null。
::AC_PH_Compat.getChampionKey <- function( _target )
{
	local isChampion = false;
	try { isChampion = _target.m.IsMiniboss == true; } catch (e) { isChampion = false; }

	if (!isChampion)
		return null;

	local et = _target.getType();
	local ETC = ::Const.EntityType;

	if (et == ETC.Direwolf) return "direwolf";
	if (et == ETC.Hyena) return "hyena";
	if (et == ETC.Serpent) return "serpent";
	if (et == ETC.Ghoul) return "ghoul";
	if (et == ETC.Alp) return "alp";
	if (et == ETC.Schrat) return "schrat";
	if (et == ETC.Lindwurm) return "lindwurm";
	if (et == ETC.Unhold || et == ETC.BarbarianUnhold) return "unhold";
	if (et == ETC.UnholdBog) return "unhold_bog";
	if (et == ETC.UnholdFrost || et == ETC.BarbarianUnholdFrost) return "unhold_frost";

	if (et == ETC.Spider)
	{
		local variant = 420;
		try
		{
			if (_target.getFlags().has("ph_variant"))
				variant = _target.getFlags().get("ph_variant");
		}
		catch (e) {}

		if (variant == 421) return "spider_brute";
		if (variant == 422) return "spider_swift";
		return "spider_venom";
	}

	return null;
}

::AC_PH_Compat.addSkillOnce <- function( _skills, _script )
{
	local s = ::new(_script);

	if (!_skills.hasSkill(s.getID()))
		_skills.add(s);
}

// 在宠物实体放出时调用（由冠军特质的 onAdded 触发）。
// 配件兄弟的 applyCompanionScaling 先用宠物属性重设基础属性，再逐个添加特质，
// 所以这里改的是本次放出的基础属性，每次放出都会重新生成，不会累加。
::AC_PH_Compat.applyChampion <- function( _actor, _key )
{
	if (!(_key in ::AC_PH_Compat.Champions))
		return;

	local d = ::AC_PH_Compat.Champions[_key];
	local b = _actor.m.BaseProperties;

	foreach (stat, value in d.Stats)
	{
		try { b[stat] += value; }
		catch (e) { ::logWarning("mod_ac_ph_compat: 冠军属性 " + stat + " 无法设置: " + e); }
	}

	if ("Armor" in d)
	{
		b.Armor[0] += d.Armor;
		b.Armor[1] += d.Armor;
		b.ArmorMax[0] += d.Armor;
		b.ArmorMax[1] += d.Armor;
	}

	// 当前生命跟着上限一起提高（此时宠物是满血状态，受伤比例由放出技能随后按上限折算）。
	_actor.m.Hitpoints = b.Hitpoints;

	local skills = _actor.getSkills();

	foreach (perk in d.Perks)
	{
		try { ::AC_PH_Compat.addSkillOnce(skills, perk); }
		catch (e) { ::logWarning("mod_ac_ph_compat: 冠军技能 " + perk + " 添加失败: " + e); }
	}

	if ("OverwhelmOrFearsome" in d)
	{
		if (skills.hasSkill("perk.overwhelm"))
			::AC_PH_Compat.addSkillOnce(skills, "scripts/skills/perks/perk_fearsome");
		else
			::AC_PH_Compat.addSkillOnce(skills, "scripts/skills/perks/perk_overwhelm");
	}

	if ("GhoulBySize" in d)
	{
		local size = 1;
		try { size = _actor.getSize(); } catch (e) {}

		if (size == 3)
		{
			::AC_PH_Compat.addSkillOnce(skills, "scripts/skills/perks/perk_fearsome");
			::AC_PH_Compat.addSkillOnce(skills, "scripts/skills/perks/perk_rf_menacing");
		}
		else
		{
			::AC_PH_Compat.addSkillOnce(skills, "scripts/skills/perks/perk_rf_battle_fervor");
		}
	}

	// 外观：冠军标记和潘多拉的冠军贴图。失败只影响外观。
	try
	{
		if (_actor.hasSprite("miniboss"))
			_actor.getSprite("miniboss").setBrush("bust_miniboss");
	}
	catch (e) {}

	if ("Brushes" in d)
	{
		foreach (sprite, brush in d.Brushes)
		{
			try
			{
				if (_actor.hasSprite(sprite))
					_actor.getSprite(sprite).setBrush(brush);
			}
			catch (e) {}
		}
	}

	if ("SpiderVariant" in d)
	{
		local v = d.SpiderVariant;
		foreach (sprite in ["legs_back", "body", "legs_front", "head"])
		{
			try
			{
				if (_actor.hasSprite(sprite))
					_actor.getSprite(sprite).setBrush("ph_bust_spider_" + sprite + "_" + v);
			}
			catch (e) {}
		}
	}

	if ("Size" in d)
	{
		try { _actor.setSize(d.Size); } catch (e) {}
	}

	try { _actor.setDirty(true); } catch (e) {}
}

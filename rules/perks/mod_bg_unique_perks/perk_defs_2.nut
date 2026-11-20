// 1.1.0 新特技：刺客、流浪骑士、老执誓者、角斗士

::BGP.PerkNames.OneStrike <- "一击毙命";
::BGP.PerkNames.Vanish <- "隐没";
::BGP.PerkNames.IronJuggernaut <- "钢铁重压";
::BGP.PerkNames.ArmorBreaker <- "破甲重击";
::BGP.PerkNames.DevastatingBlow <- "毁灭一击";
::BGP.PerkNames.CrowdFavorite <- "观众的宠儿";
::BGP.PerkNames.ArenaVeteran <- "斗技场老手";
::BGP.PerkNames.AsceticDiscipline <- "苦行戒律";
::BGP.PerkNames.UndyingSaint <- "不灭圣徒";

::BGP.PerkDescriptions.OneStrike <- ::UPD.getDescription({
	Fluff = "第一刀，就要了他的命。",
	Effects = [{
		Type = ::UPD.EffectType.Passive,
		Description = [
			"本场战斗中，对每个目标的第一次攻击伤害 " + ::MSU.Text.colorPositive("+30%") + "；目标本回合还没行动时再 " + ::MSU.Text.colorPositive("+20%") + "。",
			"第一次攻击无论命中与否都算用掉：没命中的话，之后对这个目标的攻击不再有加成。"
		]
	}]
});

::BGP.PerkDescriptions.Vanish <- ::UPD.getDescription({
	Fluff = "得手之后，人就不见了。",
	Effects = [{
		Type = ::UPD.EffectType.Passive,
		Description = [
			"击杀敌人后，直到你下一回合开始，近战防御和远程防御 " + ::MSU.Text.colorPositive("+15") + "。",
			"同时，下一次离开敌人控制区时不会受到借机攻击（用一次）。"
		]
	}]
});

::BGP.PerkDescriptions.IronJuggernaut <- ::UPD.getDescription({
	Fluff = "一身铁甲，一往无前。",
	Effects = [{
		Type = ::UPD.EffectType.Passive,
		Description = [
			"头盔与身甲当前耐久合计每有 100 点，决心 " + ::MSU.Text.colorPositive("+3") + "、远程防御 " + ::MSU.Text.colorPositive("+2") + "。",
			"免疫击退与钩拽。",
			"沿直线移动至少 2 格后，本回合的第一次近战攻击附加等于头盔和身甲疲劳惩罚合计 " + ::MSU.Text.colorPositive("15%") + " 的固定伤害，命中时 " + ::MSU.Text.colorPositive("50%") + " 概率使目标踉跄（下一回合行动顺序延后）。"
		]
	}]
});

::BGP.PerkDescriptions.ArmorBreaker <- ::UPD.getDescription({
	Fluff = "再好的甲，也挡不住这一下。",
	Effects = [{
		Type = ::UPD.EffectType.Passive,
		Description = [
			"使用双手斧、双手锤、双手钉头锤、双手剑时，对护甲造成的伤害 " + ::MSU.Text.colorPositive("+20%") + "。",
			"一击打碎敌人的头盔或身甲（耐久归零）时，该目标立刻进行一次决心 " + ::MSU.Text.colorNegative("-20") + " 的士气检定。"
		]
	}]
});

::BGP.PerkDescriptions.DevastatingBlow <- ::UPD.getDescription({
	Fluff = "举起巨刃，蓄力劈下。",
	Effects = [{
		Type = ::UPD.EffectType.Active,
		Description = [
			"解锁“毁灭一击”（单体）和“毁灭横扫”（前方扇形 3 格）两个技能，两者共用冷却：消耗 " + ::MSU.Text.colorNegative("6") + " 行动点数、" + ::MSU.Text.colorNegative("35") + " 疲劳，用后冷却 2 回合，需要装备双手近战武器。",
			"本次攻击总伤害 " + ::MSU.Text.colorPositive("+40%") + "，穿甲伤害比例 " + ::MSU.Text.colorPositive("+30%") + "，命中头部几率 " + ::MSU.Text.colorPositive("+35%") + "。",
			"震荡波：无论是否击杀，主目标和它身后 1 格内的所有敌人被震退 1 格，并随机陷入眩晕或踉跄（免疫眩晕的改为踉跄）。"
		]
	}]
});

::BGP.PerkDescriptions.CrowdFavorite <- ::UPD.getDescription({
	Fluff = "观众为你欢呼！",
	Effects = [{
		Type = ::UPD.EffectType.Passive,
		Description = [
			"每次命中或击杀敌人获得 1 层“喝彩”，最多 " + ::MSU.Text.colorPositive("5") + " 层，本场战斗有效。",
			"每层：决心 " + ::MSU.Text.colorPositive("+5") + "，每回合疲劳恢复 " + ::MSU.Text.colorPositive("+1") + "。"
		]
	}]
});

::BGP.PerkDescriptions.ArenaVeteran <- ::UPD.getDescription({
	Fluff = "被围攻？在斗技场里这叫家常便饭。",
	Effects = [{
		Type = ::UPD.EffectType.Passive,
		Description = [
			"每有一名接邻的敌人，近战防御 " + ::MSU.Text.colorPositive("+4") + "。",
			"敌人不会因为包围你而获得命中加成。"
		]
	}]
});

::BGP.PerkDescriptions.AsceticDiscipline <- ::UPD.getDescription({
	Fluff = "朴素的铠甲，坚定的信念。",
	Effects = [{
		Type = ::UPD.EffectType.Passive,
		Description = [
			"穿着护甲、且头盔和身甲都不是著名或传奇装备时，近战防御 " + ::MSU.Text.colorPositive("+5") + "、主动值 " + ::MSU.Text.colorPositive("+10") + "。",
			"决心的 " + ::MSU.Text.colorPositive("25%") + " 加到主动值上。"
		]
	}]
});

::BGP.PerkDescriptions.UndyingSaint <- ::UPD.getDescription({
	Fluff = "誓言未竟，此身不灭。",
	Effects = [{
		Type = ::UPD.EffectType.Passive,
		Description = [
			"把决心的 " + ::MSU.Text.colorPositive("15%") + " 转化为受到伤害的减免百分比（例：120 点决心减免 18%），最多减免 " + ::MSU.Text.colorPositive("80%") + "。",
			"每场战斗一次：受到致命伤害时不会死亡，保留 1 点生命值，进入持续 2 回合的“不死狂热”：不受任何生命值伤害，也不会受伤。"
		]
	}]
});

local perks2 = [];
foreach (d in [
	["OneStrike", "perk.bgp_one_strike", "perk_bgp_one_strike"],
	["Vanish", "perk.bgp_vanish", "perk_bgp_vanish"],
	["IronJuggernaut", "perk.bgp_iron_juggernaut", "perk_bgp_iron_juggernaut"],
	["ArmorBreaker", "perk.bgp_armor_breaker", "perk_bgp_armor_breaker"],
	["DevastatingBlow", "perk.bgp_devastating_blow", "perk_bgp_devastating_blow"],
	["CrowdFavorite", "perk.bgp_crowd_favorite", "perk_bgp_crowd_favorite"],
	["ArenaVeteran", "perk.bgp_arena_veteran", "perk_bgp_arena_veteran"],
	["AsceticDiscipline", "perk.bgp_ascetic_discipline", "perk_bgp_ascetic_discipline"],
	["UndyingSaint", "perk.bgp_undying_saint", "perk_bgp_undying_saint"]
])
{
	::Const.Strings.PerkName[d[0] + "_BGP"] <- ::BGP.PerkNames[d[0]];
	::Const.Strings.PerkDescription[d[0] + "_BGP"] <- ::BGP.PerkDescriptions[d[0]];
	perks2.push({
		ID = d[1],
		Script = "scripts/skills/perks/" + d[2],
		Name = ::BGP.PerkNames[d[0]],
		Tooltip = ::BGP.PerkDescriptions[d[0]],
		Icon = "ui/perks/" + d[2] + ".png",
		IconDisabled = "ui/perks/" + d[2] + "_sw.png"
	});
}
::DynamicPerks.Perks.addPerks(perks2);

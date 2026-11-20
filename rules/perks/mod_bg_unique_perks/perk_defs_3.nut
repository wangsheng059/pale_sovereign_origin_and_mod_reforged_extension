// 1.3.0 统帅组新特技：识骨相人、化瑕为瑜、深渊共鸣、千面归一、授印封将

::BGP.PerkNames.Discerning <- "识骨相人";
::BGP.PerkNames.FlawsToFangs <- "化瑕为瑜";
::BGP.PerkNames.AbyssalResonance <- "深渊共鸣";
::BGP.PerkNames.OneFlesh <- "千面归一";
::BGP.PerkNames.Bestow <- "授印封将";

::BGP.PerkDescriptions.Discerning <- ::UPD.getDescription({
	Fluff = "看一个人的骨相，就知道该把他放在哪里。",
	Effects = [{
		Type = ::UPD.EffectType.Active,
		Description = [
			"解锁“识骨相人”技能：消耗 " + ::MSU.Text.colorNegative("3") + " 行动点数、" + ::MSU.Text.colorNegative("8") + " 疲劳，目标为 4 格内的一名战团成员（不能选自己）。每场战斗最多 3 人，每人 1 次，效果持续整场战斗。",
			"按目标天赋星级最高的属性下达指令（星级并列时取基础数值相对更突出的一项）：",
			"生命 / 疲劳 → 苦行之躯：技能疲劳消耗 " + ::MSU.Text.colorPositive("-30%") + "；达库尔信徒每阶受到伤害 " + ::MSU.Text.colorPositive("-2%") + "（最多 -12%）。",
			"主动 / 远程技能 / 远程防御 → 无声巡猎：免疫控制区，穿甲伤害比例 " + ::MSU.Text.colorPositive("+15%") + "。",
			"近战技能 / 近战防御 / 决心 → 血祭处决：攻击时相邻敌人每比相邻友军多 1 名，伤害 " + ::MSU.Text.colorPositive("+8%") + "（最多 +24%）；达库尔信徒造成生命伤害的 " + ::MSU.Text.colorPositive("15%") + " 回复自身生命。"
		]
	}]
});

::BGP.PerkDescriptions.FlawsToFangs <- ::UPD.getDescription({
	Fluff = "庸人嫌弃的毛病，在统帅手里都是兵器。",
	Effects = [{
		Type = ::UPD.EffectType.Passive,
		Description = [
			"只要你在场上，全体战团成员（包括你自己）按自身的特质和伤势获得：",
			"愚笨、脑损伤、悲喜无常：士气不会降到崩溃或溃逃；精神攻击的决心检定 " + ::MSU.Text.colorPositive("+20") + "；近战攻击无视目标盾牌提供的近战防御。",
			"永久伤：每处近战伤害 " + ::MSU.Text.colorPositive("+8%") + "、决心 " + ::MSU.Text.colorPositive("+4") + "，最多 3 处。",
			"懦夫、畏缩、懦弱、犹豫、不安：本回合用过“等待”后，下一次攻击命中 " + ::MSU.Text.colorPositive("+15") + "、命中头部几率 " + ::MSU.Text.colorPositive("+15%") + "。",
			"哮喘：每回合疲劳恢复 " + ::MSU.Text.colorPositive("+3") + "。",
			"近视、夜盲：对 3 格内目标的远程伤害 " + ::MSU.Text.colorPositive("+20%") + "。",
			"贪婪、急躁、嗜血：每回合第一次击杀回复 " + ::MSU.Text.colorPositive("2") + " 行动点。"
		]
	}]
});

::BGP.PerkDescriptions.AbyssalResonance <- ::UPD.getDescription({
	Fluff = "站在统帅身边，人人都比平时强一分。",
	Effects = [{
		Type = ::UPD.EffectType.Passive,
		Description = [
			"你周围 4 格内的战团成员（包括你自己）：天赋星级最高的那项属性每颗星 " + ::MSU.Text.colorPositive("+3%") + "（最多 +9%）。",
			"4 格内的其他战团成员：决心至少为你决心的 " + ::MSU.Text.colorPositive("60%") + "，近战防御至少为你近战防御的 " + ::MSU.Text.colorPositive("50%") + "。",
			"信徒阶位低于你的成员（你是达库尔信徒时），或等级低于你的成员（你不是信徒时），决心保底提高到 " + ::MSU.Text.colorPositive("70%") + "。"
		]
	}]
});

::BGP.PerkDescriptions.OneFlesh <- ::UPD.getDescription({
	Fluff = "刀枪剑戟各有其主，千人如同一人。",
	Effects = [{
		Type = ::UPD.EffectType.Passive,
		Description = [
			"战斗开始时，统计场上战团成员主手武器的不同类型数（空手算一类），整场战斗固定：",
			"3 种以上：全体战团成员每回合第一次换武器不消耗行动点。",
			"5 种以上（苦痛转嫁）：低阶成员生命跌破 25% 或阵亡时（每人每场一次），场上 4–6 阶达库尔信徒获得 1 层“狂热”；没有 4–6 阶信徒时改为等级最高的 3 人获得（受伤者本人在其中时不触发）。狂热每层伤害 " + ::MSU.Text.colorPositive("+10%") + "，最多 2 层，本场有效；获得新层后的下一个回合行动点 " + ::MSU.Text.colorPositive("+2") + "。",
			"7 种以上（深渊同体）：回合开始时，疲劳超过上限 80% 的部分转给 4 格内疲劳比例最低的队友；每人每场一次，受到致命伤时由相邻生命过半的队友承担一半伤害，自己保留 1 点生命。"
		]
	}]
});

::BGP.PerkDescriptions.Bestow <- ::UPD.getDescription({
	Fluff = "家族战印，只授予值得托付的人。",
	Effects = [{
		Type = ::UPD.EffectType.Active,
		Description = [
			"解锁三个战印技能：0 行动点、0 疲劳，只能在第 1 回合使用，每枚每场 1 次；目标为 8 格内的一名战团成员（不能选自己，每人只能持一枚印），效果持续整场战斗。",
			"先锋印：移动消耗的疲劳 " + ::MSU.Text.colorPositive("-50%") + "；每回合第一次击杀回复 " + ::MSU.Text.colorPositive("4") + " 行动点，且下一次移动免疫控制区。代价：远程防御归零；持盾时战印失效。",
			"中军印：相邻友军受到伤害 " + ::MSU.Text.colorPositive("-20%") + "，自身受到伤害 " + ::MSU.Text.colorPositive("-10%") + "，敌人更倾向于攻击他。",
			"奇兵印：攻击本场还没攻击过他的敌人时，穿甲伤害比例 " + ::MSU.Text.colorPositive("+20%") + "，近战攻击无视目标盾牌的近战防御；击杀后直到下一回合开始，敌人不太会把他当作目标。"
		]
	}]
});

local perks3 = [];
foreach (d in [
	["Discerning", "perk.bgp_discerning", "perk_bgp_discerning"],
	["FlawsToFangs", "perk.bgp_flaws_to_fangs", "perk_bgp_flaws_to_fangs"],
	["AbyssalResonance", "perk.bgp_abyssal_resonance", "perk_bgp_abyssal_resonance"],
	["OneFlesh", "perk.bgp_one_flesh", "perk_bgp_one_flesh"],
	["Bestow", "perk.bgp_bestow", "perk_bgp_bestow"]
])
{
	::Const.Strings.PerkName[d[0] + "_BGP"] <- ::BGP.PerkNames[d[0]];
	::Const.Strings.PerkDescription[d[0] + "_BGP"] <- ::BGP.PerkDescriptions[d[0]];
	perks3.push({
		ID = d[1],
		Script = "scripts/skills/perks/" + d[2],
		Name = ::BGP.PerkNames[d[0]],
		Tooltip = ::BGP.PerkDescriptions[d[0]],
		Icon = "ui/perks/" + d[2] + ".png",
		IconDisabled = "ui/perks/" + d[2] + "_sw.png"
	});
}
::DynamicPerks.Perks.addPerks(perks3);

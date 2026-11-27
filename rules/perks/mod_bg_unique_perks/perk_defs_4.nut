// 1.4.0 死灵法师组：死灵法术、支配亡灵、不死再生、死灵精通、心灵交融、嗜血者、死灵灌注、钢铁之躯、尸爆
// 参考 Nectomancy（死灵法术 perk）1.0 和 mod_necro 0.4.0（Proper Necro），按重铸重写

::BGP.PerkNames.NecroPossess <- "支配亡灵";
::BGP.PerkNames.NecroRegeneration <- "不死再生";
::BGP.PerkNames.NecroMastery <- "亡灵法术精通";
::BGP.PerkNames.NecroMindMeld <- "心灵交融";
::BGP.PerkNames.NecroBloodSucking <- "嗜血者";
::BGP.PerkNames.NecroInfusion <- "冥府活力";
::BGP.PerkNames.NecroFleshOfIron <- "钢铁之躯";
::BGP.PerkNames.CorpseExplosion <- "尸爆";
// 1.6.0
::BGP.PerkNames.NecroFleshReforge <- "血肉重铸";
::BGP.PerkNames.NecroUndyingChampion <- "不灭勇士";
::BGP.PerkNames.NecroCurseOfAges <- "岁月诅咒";
::BGP.PerkNames.NecroFlySwarm <- "腐毒蝇群";
::BGP.PerkNames.NecroGrandmaster <- "亡灵法术大师";

::BGP.PerkDescriptions.NecroPossess <- ::UPD.getDescription({
	Fluff = "把意志灌进一具尸体，替它看，替它挥刀。",
	Effects = [{
		Type = ::UPD.EffectType.Active,
		Description = [
			"解锁“支配亡灵”技能：消耗 " + ::MSU.Text.colorNegative("3") + " 行动点数、" + ::MSU.Text.colorNegative("10") + " 疲劳，施法距离 " + ::MSU.Text.colorPositive("99") + " 格（不需要视野），目标为一名友方亡灵（僵尸、骷髅、你复活的所有单位、常驻亡灵及亡灵宠物）。",
			"被支配的亡灵直到它的回合结束：行动点上限变为 " + ::MSU.Text.colorPositive("12") + "（并立刻补满当回合行动点）、近战技能 " + ::MSU.Text.colorPositive("+W/5") + "、近战 / 远程防御 " + ::MSU.Text.colorPositive("+10") + "、主动值 " + ::MSU.Text.colorPositive("+50") + "、受到的伤害 " + ::MSU.Text.colorPositive("-(W/4 - 5)%") + "（0~30%）。",
			"同一时间只能支配 1 名亡灵；施法者受到重伤或被支配者阵亡时支配提前结束。",
			"（W = 亡灵法师当前决心 − 20，含装备和光环，施放时计算）"
		]
	}]
});

::BGP.PerkDescriptions.NecroRegeneration <- ::UPD.getDescription({
	Fluff = "尸体被唤起之后，修复也不会停。",
	Effects = [{
		Type = ::UPD.EffectType.Passive,
		Description = [
			"你的亡灵（复活的单位、亡灵宠物、永恒禁卫）每回合开始时回复 " + ::MSU.Text.colorPositive("5 + W/5") + " 点生命（W = 你的当前决心 − 20，含装备和光环）。"
		]
	}]
});

::BGP.PerkDescriptions.NecroMastery <- ::UPD.getDescription({
	Fluff = "熟能生巧，亡灵法术也一样。",
	Effects = [{
		Type = ::UPD.EffectType.Passive,
		Description = [
			"亡灵勇士、亡灵天灾两组共用（不参与两组互斥）。",
			"亡灵法师的主动技能（复活死者、支配亡灵、冥府活力、尸爆、血肉重铸、岁月诅咒）行动点消耗 " + ::MSU.Text.colorPositive("-1") + "、疲劳消耗 " + ::MSU.Text.colorPositive("-25%") + "。"
		]
	}]
});

::BGP.PerkDescriptions.NecroMindMeld <- ::UPD.getDescription({
	Fluff = "主仆之间，分不清是谁在学谁。",
	Effects = [{
		Type = ::UPD.EffectType.Passive,
		Description = [
			"你的亡灵（复活的单位、亡灵宠物、永恒禁卫）复制你身上的这些被动特技：巨像、钢头、轻灵、稳健、韧性、落单狗、闪避、预判、九命猫、坚实、生存本能。",
			"你获得装备在饰品位的亡灵宠物全属性 " + ::MSU.Text.colorPositive("10%") + " 的加成（生命、疲劳值、决心、主动值、近战技能、远程技能、近战防御、远程防御，向下取整）。"
		]
	}]
});

::BGP.PerkDescriptions.NecroBloodSucking <- ::UPD.getDescription({
	Fluff = "让它们像死灵学者那样进食。",
	Effects = [{
		Type = ::UPD.EffectType.Passive,
		Description = [
			"你的亡灵（复活的单位、亡灵宠物、永恒禁卫）获得原版吸血鬼的吸血能力：攻击造成生命伤害时回复自身生命。"
		]
	}]
});

::BGP.PerkDescriptions.NecroInfusion <- ::UPD.getDescription({
	Fluff = "冥府的寒流灌入枯骨，催它疾行如风。",
	Effects = [{
		Type = ::UPD.EffectType.Active,
		Description = [
			"解锁“冥府活力”技能：消耗 " + ::MSU.Text.colorNegative("4") + " 行动点数、" + ::MSU.Text.colorNegative("12") + " 疲劳，目标为 8 格内的一名友方亡灵。",
			"目标立刻回复 " + ::MSU.Text.colorPositive("10 + W/4") + " 点生命、减少 " + ::MSU.Text.colorPositive("10 + W/6") + " 点疲劳；在接下来的 2 个回合里，行动点数 " + ::MSU.Text.colorPositive("+4") + "（未行动的目标当回合立刻获得 +4 行动点）、主动值 " + ::MSU.Text.colorPositive("+75") + "、移动时行动点消耗 " + ::MSU.Text.colorPositive("-1") + "（最少 1）。",
			"（W = 亡灵法师当前决心 − 20，含装备和光环，施放时计算）"
		]
	}]
});

::BGP.PerkDescriptions.NecroFleshOfIron <- ::UPD.getDescription({
	Fluff = "铁也是死物。",
	Effects = [{
		Type = ::UPD.EffectType.Passive,
		Description = [
			"你复活单位时，它的头甲、身甲各恢复上限的 " + ::MSU.Text.colorPositive("10% + W/4 %") + "（W = 当时你的当前决心 − 20）；放出亡灵宠物时，改为获得等量的临时护甲（先于装备受损）。",
			"同时有“不死再生”时，这些亡灵每回合开始时头甲、身甲再各恢复 " + ::MSU.Text.colorPositive("7%") + "。"
		]
	}]
});

::BGP.PerkDescriptions.CorpseExplosion <- ::UPD.getDescription({
	Fluff = "死人身上最后一点用处。",
	Effects = [{
		Type = ::UPD.EffectType.Active,
		Description = [
			"解锁“尸爆”技能：消耗 " + ::MSU.Text.colorNegative("4") + " 行动点数、" + ::MSU.Text.colorNegative("12") + " 疲劳，施法距离 6 格，摧毁目标格上的一具尸体（含即将自行爬起的尸体与永恒禁卫残骸，摧毁后不会再爬起或复活）。",
			"对目标格和相邻 1 格内的所有敌人（不伤友军）造成钝器伤害，等于该尸体生前最大生命的 " + ::MSU.Text.colorPositive("20% + W/4 %") + "；被炸到还活着的敌人做一次士气检定，难度 " + ::MSU.Text.colorNegative("-W/5") + "。",
			"（W = 亡灵法师当前决心 − 20，含装备和光环，施放时计算）",
			"尸体死亡时身上的头甲、身甲还有剩余耐久的，额外造成劈砍伤害，等于剩余耐久总和的 " + ::MSU.Text.colorPositive("25%") + "（对护甲伤害效率 " + ::MSU.Text.colorPositive("150%") + "）。",
			"被波及的敌人陷入“踉跄”。"
		]
	}]
});

::BGP.PerkDescriptions.NecroFleshReforge <- ::UPD.getDescription({
	Fluff = "骨头不够就再接一根，筋不够就再缠一条。",
	Effects = [{
		Type = ::UPD.EffectType.Active,
		Description = [
			"解锁“血肉重铸”技能：消耗 " + ::MSU.Text.colorNegative("4") + " 行动点数、" + ::MSU.Text.colorNegative("15") + " 疲劳，施法距离 5 格，目标为你的亡灵（你复活的单位、你的亡灵宠物、永恒禁卫）。",
			"摧毁目标所在格或相邻 1 格内的一具尸体（含即将自行爬起的尸体与永恒禁卫残骸），把它的骨骼和肌腱嫁接到目标身上；每个单位每场战斗最多嫁接 2 次。",
			"第 1 次 骨刺外甲：获得 " + ::MSU.Text.colorPositive("40 + W/2") + " 点独立骨甲（先于护甲吸收伤害）；骨甲没碎时，每次被近战攻击对攻击者造成 " + ::MSU.Text.colorPositive("5 + W/4") + " 点穿刺伤害（无视护甲）。",
			"第 2 次 畸变肌腱：行动点上限 " + ::MSU.Text.colorPositive("+2") + "，每格移动行动点 " + ::MSU.Text.colorPositive("-1") + "（最少 1），所有攻击命中头部几率 " + ::MSU.Text.colorPositive("+15%") + "。",
			"（W = 亡灵法师当前决心 − 20，含装备和光环，施放时计算）"
		]
	}]
});

::BGP.PerkDescriptions.NecroUndyingChampion <- ::UPD.getDescription({
	Fluff = "只要主人还站着，禁卫就不会真正倒下。",
	Effects = [{
		Type = ::UPD.EffectType.Passive,
		Description = [
			"永恒禁卫：战斗开始时饰品栏没有亡灵宠物，就在身旁召唤一尊持双手巨斧的“墓穴王禁卫”（古代仪仗兵面板）；饰品栏有亡灵宠物，它放出时直接成为永恒禁卫，全属性 " + ::MSU.Text.colorPositive("+10%") + "。",
			"不灭复生：只要你在场上存活，永恒禁卫阵亡后会在下一回合自动原地复活（若残骸格被敌人踩住会将其挤开，无法挤开或被友军占据则在相邻空格复活），生命和头甲、身甲耐久各恢复到 " + ::MSU.Text.colorPositive("15% + W/5 %") + "（最多 " + ::MSU.Text.colorPositive("50%") + "；W = 复活时你的当前决心 − 20）。",
			"不死恐怖：只要你还活着，永恒禁卫倒下后残骸不会被复活死者或敌方吞食消耗；你仍可对其施放尸爆或血肉重铸（残骸摧毁后本场无法再自动复活）。",
			"你在战斗中死亡时，倒下的宠物禁卫随之失去；你活到战斗结束时它保留，伤势记为 50%。"
		]
	}]
});

::BGP.PerkDescriptions.NecroCurseOfAges <- ::UPD.getDescription({
	Fluff = "一眨眼，几十年过去了。",
	Effects = [{
		Type = ::UPD.EffectType.Active,
		Description = [
			"解锁“岁月诅咒”技能：消耗 " + ::MSU.Text.colorNegative("6") + " 行动点数、" + ::MSU.Text.colorNegative("24") + " 疲劳，施法距离 7 格，作用于目标格及相邻 1 格内的敌人（不影响友军），持续 3 回合。",
			"被诅咒的敌人：行动点 " + ::MSU.Text.colorNegative("-1") + "，主动值 " + ::MSU.Text.colorNegative("-50") + "，近战技能 / 远程技能 " + ::MSU.Text.colorNegative("-10") + "，近战 / 远程伤害 " + ::MSU.Text.colorNegative("-20%") + "。",
			"诅咒期间每受到一次攻击伤害（含尸爆，哪怕只伤到护甲），命中部位护甲的当前耐久额外 " + ::MSU.Text.colorNegative("-(10 + W/4)") + "（W = 施放时你的当前决心 − 20）。",
			"再次诅咒同一目标只刷新持续时间，不叠加。"
		]
	}]
});

::BGP.PerkDescriptions.NecroFlySwarm <- ::UPD.getDescription({
	Fluff = "嗡嗡声比亡灵先到。",
	Effects = [{
		Type = ::UPD.EffectType.Passive,
		Description = [
			"你的召唤亡灵（你复活的单位、你的亡灵宠物、永恒禁卫）身上涌出腐毒蝇群。",
			"任何非亡灵敌人每与 1 只召唤亡灵相邻，近战技能、近战防御、决心各 " + ::MSU.Text.colorNegative("-3") + "。",
			"与召唤亡灵相邻时，每次攻击、每次发起移动（含步伐、换位等位移技能）额外消耗 " + ::MSU.Text.colorNegative("4") + " 点疲劳。"
		]
	}]
});

::BGP.PerkDescriptions.NecroGrandmaster <- ::UPD.getDescription({
	Fluff = "生与死的界线，在你指尖早已模糊。",
	Effects = [{
		Type = ::UPD.EffectType.Passive,
		Description = [
			"亡灵勇士、亡灵天灾两组共用（不参与互斥）。",
			"解锁亡灵驯服与「驱役亡灵」（消耗 " + ::MSU.Text.colorNegative("4") + " 行动点数、" + ::MSU.Text.colorNegative("16") + " 疲劳）：可用「驯服野兽」驯服野兽或亡灵，成功率随决心提高；「驱役亡灵」可收服 6 格内亲手复活的友军（不限生命），或生命不高于最大生命 " + ::MSU.Text.colorPositive("5% + ⌊(当前决心 − 20) / 8⌋%") + "（上限 " + ::MSU.Text.colorPositive("30%") + "）的存活敌方亡灵。亡灵宠物沿用目标属性与装备，升级走亡灵特质池；亡灵法师导师饰品栏已有亡灵宠物时仍可继续收服并存入仓库。",
			"每场战斗「召唤僵尸」与「召唤骷髅」的免费施放次数各 " + ::MSU.Text.colorPositive("+1") + "（亡灵法师导师每场各免费施放 " + ::MSU.Text.colorPositive("2") + " 次；普通亡灵法师借此解锁，每场各免费施放 " + ::MSU.Text.colorPositive("1") + " 次）。",
			"你施放的亡灵法术效果（支配亡灵、冥府活力、岁月诅咒、衰弱术、勇士猎物、尸爆「踉跄」、千魂回响「玉骨盾」）持续时间 " + ::MSU.Text.colorPositive("+1") + " 回合。",
			"每轮首次施放亡灵法术时，自身 " + ::MSU.Text.colorPositive("4") + " 格内所有友方亡灵（含常驻亡灵、亡灵宠物、临时仆从）回复 " + ::MSU.Text.colorPositive("8") + " 点生命，并获得 " + ::MSU.Text.colorPositive("+5") + " 近战技能与远程技能，持续至本轮结束（不叠加）。"
		]
	}]
});

local perks4 = [];
foreach (d in [
	["NecroPossess", "perk.bgp_necro_possess", "perk_bgp_necro_possess"],
	["NecroRegeneration", "perk.bgp_necro_regeneration", "perk_bgp_necro_regeneration"],
	["NecroMastery", "perk.bgp_necro_mastery", "perk_bgp_necro_mastery"],
	["NecroMindMeld", "perk.bgp_necro_mind_meld", "perk_bgp_necro_mind_meld"],
	["NecroBloodSucking", "perk.bgp_necro_blood_sucking", "perk_bgp_necro_blood_sucking"],
	["NecroInfusion", "perk.bgp_necro_infusion", "perk_bgp_necro_infusion"],
	["NecroFleshOfIron", "perk.bgp_necro_flesh_of_iron", "perk_bgp_necro_flesh_of_iron"],
	["CorpseExplosion", "perk.bgp_corpse_explosion", "perk_bgp_corpse_explosion"],
	["NecroFleshReforge", "perk.bgp_necro_flesh_reforge", "perk_bgp_necro_flesh_reforge"],
	["NecroUndyingChampion", "perk.bgp_necro_undying_champion", "perk_bgp_necro_undying_champion"],
	["NecroCurseOfAges", "perk.bgp_necro_curse_of_ages", "perk_bgp_necro_curse_of_ages"],
	["NecroFlySwarm", "perk.bgp_necro_fly_swarm", "perk_bgp_necro_fly_swarm"],
	["NecroGrandmaster", "perk.bgp_necro_grandmaster", "perk_bgp_necro_grandmaster"]
])
{
	::Const.Strings.PerkName[d[0] + "_BGP"] <- ::BGP.PerkNames[d[0]];
	::Const.Strings.PerkDescription[d[0] + "_BGP"] <- ::BGP.PerkDescriptions[d[0]];
	perks4.push({
		ID = d[1],
		Script = "scripts/skills/perks/" + d[2],
		Name = ::BGP.PerkNames[d[0]],
		Tooltip = ::BGP.PerkDescriptions[d[0]],
		Icon = "ui/perks/" + d[2] + ".png",
		IconDisabled = "ui/perks/" + d[2] + "_sw.png"
	});
}
::DynamicPerks.Perks.addPerks(perks4);

// 1.6.0 亡灵冠军 / 亡灵天灾互斥：学了一组的独有特技后，另一组的独有特技锁定（同重铸“轻灵 / 战斗锻造”的做法，
// DPF 的 isPerkUnlockable 和特技提示都会调用特技定义上的 verifyPrerequisites）。死灵精通两组共用，不参与。
::BGP.Necro.makeExclusiveCheck <- function( _otherPerks, _otherName )
{
	return function( _player, _tooltip )
	{
		foreach (id in _otherPerks)
		{
			local s = _player.getSkills().getSkillByID(id);
			if (s != null)
			{
				_tooltip.push({
					id = 3,
					type = "hint",
					icon = "ui/icons/icon_locked.png",
					text = "特技被锁定：已学“" + _otherName + "”的" + s.getName() + "，两组互斥"
				});
				return false;
			}
		}
		return true;
	};
}

foreach (id in ::BGP.Necro.ChampionPerks)
	::Const.Perks.findById(id).verifyPrerequisites <- ::BGP.Necro.makeExclusiveCheck(::BGP.Necro.ScourgePerks, "亡灵天灾");
foreach (id in ::BGP.Necro.ScourgePerks)
	::Const.Perks.findById(id).verifyPrerequisites <- ::BGP.Necro.makeExclusiveCheck(::BGP.Necro.ChampionPerks, "亡灵勇士");

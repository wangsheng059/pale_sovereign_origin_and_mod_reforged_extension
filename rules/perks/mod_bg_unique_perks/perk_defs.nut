// 新特技的名字、说明和注册

::BGP.PerkNames <- {
	BloodSacrifice = "血祭",
	GodsGaze = "诸神注视",
	GracefulEvasion = "游刃有余",
	SwordSaint = "剑圣之名",
	PackLeader = "兽群领袖",
	HuntingFever = "狩猎狂热",
	Feint = "声东击西",
	SharedHatred = "同仇敌忾",
	HuntingHour = "狩猎时刻",
	IronOrders = "军令如山",
	RewardPunish = "赏罚分明",
	ArtOfWar = "战争艺术"
};

::BGP.PerkDescriptions <- {
	BloodSacrifice = ::UPD.getDescription({
		Fluff = "每一条性命，都是献给诸神的祭品。",
		Effects = [{
			Type = ::UPD.EffectType.Passive,
			Description = [
				"每击杀一名敌人，本场战斗中造成的伤害永久提高 " + ::MSU.Text.colorPositive("15%") + "，可无限叠加（加算）。",
				"战斗结束后清空。"
			]
		}]
	}),
	GodsGaze = ::UPD.getDescription({
		Fluff = "诸神在看着你。每一次杀戮，都会换来一份恩赐。",
		Effects = [{
			Type = ::UPD.EffectType.Passive,
			Description = [
				"每击杀一名敌人，随机获得以下恩赐之一，本场战斗有效，可重复获得并叠加：",
				"行动点数 " + ::MSU.Text.colorPositive("+2") + "。",
				"每格移动消耗的行动点数 " + ::MSU.Text.colorPositive("-1") + "、疲劳 " + ::MSU.Text.colorPositive("-2") + "（每格最少仍消耗 1 点）。",
				"立即获得头甲 " + ::MSU.Text.colorPositive("+20") + "、身甲 " + ::MSU.Text.colorPositive("+20") + "（可超过上限），生命值上限和当前生命值 " + ::MSU.Text.colorPositive("+20") + "。",
				"下一次攻击命中时使目标眩晕（命中后消耗，免疫眩晕的目标不受影响）。"
			]
		}]
	}),
	GracefulEvasion = ::UPD.getDescription({
		Fluff = "对手的每一次落空，都让你更加从容。",
		Effects = [{
			Type = ::UPD.EffectType.Passive,
			Description = [
				"每次成功闪避敌人的近战或远程攻击时，恢复 " + ::MSU.Text.colorPositive("3") + " 点疲劳，并使主动值 " + ::MSU.Text.colorPositive("+5") + "。",
				"主动值加成在本场战斗中累积，战斗结束后清空。"
			]
		}]
	}),
	SwordSaint = ::UPD.getDescription({
		Fluff = "你的名号，就足以让敌人胆寒。",
		Effects = [{
			Type = ::UPD.EffectType.Passive,
			Description = [
				"使用剑攻击时，无视目标盾牌提供的近战防御；目标处于盾墙状态时，盾墙额外提供的防御只按一半计算。",
				"每次击杀敌人或使敌人受到伤势时，你周围 2 格内的所有敌人进行一次决心 " + ::MSU.Text.colorNegative("-10") + " 的士气检定。",
				"对士气为动摇或更低的敌人造成的伤害 " + ::MSU.Text.colorPositive("+20%") + "。"
			]
		}]
	}),
	PackLeader = ::UPD.getDescription({
		Fluff = "群兽追随着头领的气息。",
		Effects = [{
			Type = ::UPD.EffectType.Passive,
			Description = [
				"你周围 4 格内的所有友方野兽，获得相当于你当前近战技能、近战防御和决心 " + ::MSU.Text.colorPositive("10%") + " 的加成。",
				"这些野兽不会因为自身受伤而在士气检定中溃逃；面对恐惧类精神攻击时决心 " + ::MSU.Text.colorPositive("+15") + "。",
				"多名驯兽师时取加成最高的一位，不叠加。"
			]
		}]
	}),
	HuntingFever = ::UPD.getDescription({
		Fluff = "血腥味让兽群越发狂热。",
		Effects = [{
			Type = ::UPD.EffectType.Passive,
			Description = [
				"每当场上任意一只友方野兽使敌人流血或击杀敌人时，你和所有友方野兽获得 1 层“狩猎狂热”，最多 " + ::MSU.Text.colorPositive("3") + " 层，本场战斗有效。",
				"每层：伤害 " + ::MSU.Text.colorPositive("+5%") + "，主动值 " + ::MSU.Text.colorPositive("+15") + "。"
			]
		}]
	}),
	Feint = ::UPD.getDescription({
		Fluff = "看这边！不，在那边！",
		Effects = [{
			Type = ::UPD.EffectType.Active,
			Description = [
				"解锁“声东击西”技能：消耗 " + ::MSU.Text.colorNegative("3") + " 行动点数、" + ::MSU.Text.colorNegative("15") + " 疲劳，与 2 格内的一只友方野兽瞬间交换位置。",
				"交换后，该野兽获得“防御姿态”：近战防御 " + ::MSU.Text.colorPositive("+15") + "，持续到它下一次回合结束。",
				"你获得主动值 " + ::MSU.Text.colorPositive("+30") + "，持续到你下一回合结束。"
			]
		}]
	}),
	SharedHatred = ::UPD.getDescription({
		Fluff = "驯兽师与兽群，同仇敌忾。",
		Effects = [{
			Type = ::UPD.EffectType.Passive,
			Description = [
				"你或你的宠物每击杀一名敌人，你和你的宠物各获得 1 层“同仇”，最多 " + ::MSU.Text.colorPositive("3") + " 层，本场战斗有效；每层伤害 " + ::MSU.Text.colorPositive("+8%") + "。",
				"你的宠物站在你旁边时，你和这只宠物受到的伤害都 " + ::MSU.Text.colorPositive("-20%") + "。",
				"“你的宠物”指装在你饰品栏里的配件兄弟宠物或战犬。"
			]
		}]
	}),
	HuntingHour = ::UPD.getDescription({
		Fluff = "吹响终极猎号，狩猎开始了！",
		Effects = [{
			Type = ::UPD.EffectType.Active,
			Description = [
				"解锁“狩猎时刻”技能：消耗 " + ::MSU.Text.colorNegative("4") + " 行动点数、" + ::MSU.Text.colorNegative("25") + " 疲劳，每场战斗限用 1 次。",
				"场上所有友方野兽和你自己：立即解除眩晕、网缚、蛛网、晕眩、踉跄、分神等控制效果，恢复 " + ::MSU.Text.colorPositive("50%") + " 最大疲劳值，士气变为自信。",
				"持续 2 回合：主动值 " + ::MSU.Text.colorPositive("+50") + "，士气锁定为自信，不会下降。"
			]
		}]
	}),
	IronOrders = ::UPD.getDescription({
		Fluff = "军令既出，不容迟疑。",
		Effects = [{
			Type = ::UPD.EffectType.Passive,
			Description = [
				"战斗开始时，你周围 4 格内的战团成员（包括你自己）获得“军令”：主动值 " + ::MSU.Text.colorPositive("+25") + "，近战技能和远程技能 " + ::MSU.Text.colorPositive("+5") + "，持续前 2 回合。"
			]
		}]
	}),
	RewardPunish = ::UPD.getDescription({
		Fluff = "有功必赏。",
		Effects = [{
			Type = ::UPD.EffectType.Passive,
			Description = [
				"你周围 4 格内的战团成员（包括你自己）每击杀一名敌人，恢复 " + ::MSU.Text.colorPositive("8") + " 点疲劳，并进行一次正面士气检定。"
			]
		}]
	}),
	ArtOfWar = ::UPD.getDescription({
		Fluff = "治军如治国。",
		Effects = [{
			Type = ::UPD.EffectType.Passive,
			Description = [
				"只要战团里有人拥有此特技：全队每日薪水 " + ::MSU.Text.colorPositive("-10%") + "；战斗中获得的经验 " + ::MSU.Text.colorPositive("+10%") + "；扎营时生命恢复速度和装备修理速度 " + ::MSU.Text.colorPositive("+20%") + "。多人拥有时不叠加。",
				"你的主动指挥类技能（集结部队、发号施令、稳住阵线、冲击阵线、提振）行动点数消耗 " + ::MSU.Text.colorPositive("-1") + "（最少 1 点），疲劳消耗 " + ::MSU.Text.colorPositive("-30%") + "。"
			]
		}]
	})
};

local defs = [
	["BloodSacrifice", "perk.bgp_blood_sacrifice", "perk_bgp_blood_sacrifice"],
	["GodsGaze", "perk.bgp_gods_gaze", "perk_bgp_gods_gaze"],
	["GracefulEvasion", "perk.bgp_graceful_evasion", "perk_bgp_graceful_evasion"],
	["SwordSaint", "perk.bgp_sword_saint", "perk_bgp_sword_saint"],
	["PackLeader", "perk.bgp_pack_leader", "perk_bgp_pack_leader"],
	["HuntingFever", "perk.bgp_hunting_fever", "perk_bgp_hunting_fever"],
	["Feint", "perk.bgp_feint", "perk_bgp_feint"],
	["SharedHatred", "perk.bgp_shared_hatred", "perk_bgp_shared_hatred"],
	["HuntingHour", "perk.bgp_hunting_hour", "perk_bgp_hunting_hour"],
	["IronOrders", "perk.bgp_iron_orders", "perk_bgp_iron_orders"],
	["RewardPunish", "perk.bgp_reward_punish", "perk_bgp_reward_punish"],
	["ArtOfWar", "perk.bgp_art_of_war", "perk_bgp_art_of_war"]
];

local perks = [];
foreach (d in defs)
{
	::Const.Strings.PerkName[d[0] + "_BGP"] <- ::BGP.PerkNames[d[0]];
	::Const.Strings.PerkDescription[d[0] + "_BGP"] <- ::BGP.PerkDescriptions[d[0]];
	perks.push({
		ID = d[1],
		Script = "scripts/skills/perks/" + d[2],
		Name = ::BGP.PerkNames[d[0]],
		Tooltip = ::BGP.PerkDescriptions[d[0]],
		Icon = "ui/perks/" + d[2] + ".png",
		IconDisabled = "ui/perks/" + d[2] + "_sw.png"
	});
}
::DynamicPerks.Perks.addPerks(perks);

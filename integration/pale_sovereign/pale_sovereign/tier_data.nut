local S = ::PaleSovereign;

// Hitpoints, melee skill, melee defense, ranged defense, initiative, action points.
// Perk groups are listed by collection in TierPerkCollections.
S.TierPerkCollections <- ["pgc.rf_weapon", "pgc.rf_fighting_style", "pgc.rf_armor", "pgc.rf_shared_1", "pgc.rf_exclusive_1"];
S.TierCommonExclusions <- ["bow", "crossbow", "throwing", "dagger", "ranged"];
S.TierCost <- { Level = 7, LevelsSpent = 6, Jade = 1, Reserve = 5, Money = 500 };
S.TierBrushStems <- {
    tomb_blademaster = "blademaster", bloated_corpse = "bloated", frenzied_corpse = "frenzied",
    dread_corpse_lord = "dread_lord", corpse_colossus = "colossus", carnage_fiend = "carnage"
};
S.TierBranches <- {
    grave_guard = {
        Name = "墓穴卫士", Tier = 2, Skeleton = true, Stats = [90, 80, 15, 0, 75, 9], Scale = 1.0,
        Description = "幽绿的魂火在锈蚀的鳞甲下跳动。它生前大概守过某位帝王的陵墓，死后依旧举盾站在阵线最前方，用剑刃替同袍撕开破绽。",
        Skills = ["grave_blade"],
        Groups = [["sword", "mace"], ["shield", "power"], ["heavy_armor", "medium_armor"], ["tough", "unstoppable"], ["soldier"]],
        Excluded = ["polearm", "swift", "light_armor"], Weighted = ["spear"]
    },
    tomb_halberdier = {
        Name = "古墓戟卫", Tier = 2, Skeleton = true, Stats = [70, 75, 10, 0, 80, 9], Scale = 1.0,
        Description = "高冠之下，枯骨披着褪色的长袍。它习惯站在第二排，越过同伴的肩头递出长戟，一击便能砸散敌人的架势。",
        Skills = ["bone_break"],
        Groups = [["polearm", "axe"], ["power", "swift"], ["medium_armor", "heavy_armor"], ["trained", "vicious"], ["soldier"]],
        Excluded = ["shield"], Weighted = ["spear", "hammer"]
    },
    bone_blade = {
        Name = "骨刃斗士", Tier = 2, Skeleton = true, Stats = [65, 80, 10, 10, 110, 9], Scale = 1.0,
        Description = "一条褪色的红布束在脊骨上，像是某场早已被人遗忘的角斗留下的彩头。它总抢在号角声落下前出刀，敌人一倒便踏前一步，去找下一个。",
        Skills = ["chain_slash"],
        Groups = [["sword", "cleaver"], ["swift", "power"], ["light_armor", "medium_armor"], ["fast", "vicious"], ["raider"]],
        Excluded = ["shield", "heavy_armor", "polearm"], Weighted = ["axe", "agile"]
    },
    skeleton_king = {
        Name = "骷髅王", Tier = 3, Skeleton = true, Stats = [85, 80, 20, 20, 85, 9], Scale = 1.0,
        Description = "王冠下的魂火已变成冷蓝色。它还记得自己统领过军团，号令一出，周围的枯骨与行尸会一同举起武器。",
        Skills = ["dead_command"],
        Groups = [["sword", "mace"], ["shield", "power"], ["heavy_armor", "medium_armor"], ["tactician", "tough"], ["noble"]],
        Excluded = ["light_armor"], Weighted = []
    },
    barrow_knight = {
        Name = "墓冢骑士", Tier = 3, Skeleton = true, Stats = [110, 85, 20, 15, 80, 9], Scale = 1.0,
        Description = "黑铁板甲落地时震开了肩上的墓土。它在冲锋中死去，也在冲锋中醒来，盔缝里的魂火一亮，第一个要撞倒的敌人便已选好。",
        Skills = ["death_charge"],
        Groups = [["flail", "hammer"], ["power", "shield"], ["heavy_armor", "medium_armor"], ["unstoppable", "vigorous"], ["noble"]],
        Excluded = ["light_armor", "swift"], Weighted = ["sword", "spear"]
    },
    tomb_blademaster = {
        Name = "墓影剑圣", Tier = 3, Skeleton = true, Stats = [75, 90, 15, 15, 130, 9], Scale = 1.0,
        Description = "长刀出鞘时，暗红色的火沿着刃口掠过。它生前是一代剑术名家，如今从黑斗篷下踏出一步，敌人往往还来不及举刀。",
        Skills = ["first_strike"],
        Groups = [["sword", "axe"], ["swift", "power"], ["light_armor", "medium_armor"], ["agile", "vicious"], ["swordmaster"]],
        Excluded = ["shield", "heavy_armor"], Weighted = ["cleaver", "fast"]
    },
    bloated_corpse = {
        Name = "浮肿行尸", Tier = 2, Skeleton = false, Stats = [160, 70, 10, 0, 60, 9], Scale = 1.0,
        Description = "发青的腹部把缝线撑得紧绷，被砍开的腐肉还会蠕动着合拢。围住它的人要当心，它倒下的那一刻，满腹的腐液会泼向四周。",
        Skills = ["rot_regen", "death_burst"],
        Groups = [["cleaver", "mace"], ["power", "shield"], ["medium_armor", "heavy_armor"], ["tough", "vigorous"], ["laborer"]],
        Excluded = ["swift", "agile", "fast", "light_armor"], Weighted = ["flail"]
    },
    fallen_hero = {
        Name = "堕落英雄", Tier = 2, Skeleton = false, Stats = [180, 60, 5, 0, 60, 7], Scale = 1.0,
        Description = "一张半腐的脸藏在旧骑士盔下。支撑它作战的黑线随着伤口一道道绷紧，伤得越重，它越难被彻底打倒。",
        Skills = ["unyielding"],
        Groups = [["sword", "axe"], ["shield", "power"], ["heavy_armor", "medium_armor"], ["tough", "trained"], ["soldier"]],
        Excluded = ["light_armor"], Weighted = ["hammer"]
    },
    frenzied_corpse = {
        Name = "狂怒行尸", Tier = 2, Skeleton = false, Stats = [130, 75, 5, 0, 100, 9], Scale = 1.0,
        Description = "额前的缝线还在渗血，来不及打结。它一闻到活人的气味就扑上去，身上越是血肉模糊，挥砍越是凶狠。",
        Skills = ["flesh_frenzy"],
        Groups = [["axe", "cleaver"], ["swift", "power"], ["light_armor", "medium_armor"], ["fast", "vicious"], ["wildling"]],
        Excluded = ["shield", "heavy_armor"], Weighted = ["flail", "unstoppable"]
    },
    dread_corpse_lord = {
        Name = "冥尸霸主", Tier = 3, Skeleton = false, Stats = [230, 75, 10, 0, 70, 10], Scale = 1.1,
        Description = "骨刺牢牢钉穿了肩甲，这具高大的缝合尸每踏一步，地面都跟着震动。挡路的人会被它连盾带骨一起踩进泥里。",
        Skills = ["heavy_stomp"],
        Groups = [["hammer", "mace"], ["power", "shield"], ["heavy_armor", "medium_armor"], ["unstoppable", "vicious"], ["raider"]],
        Excluded = ["swift", "light_armor"], Weighted = ["axe", "flail"]
    },
    corpse_colossus = {
        Name = "尸山巨像", Tier = 3, Skeleton = false, Stats = [330, 65, 25, 0, 45, 9], Scale = 1.18,
        Description = "由数具尸体缝合而成，背上的几只手仍在无意识地抓握。它散发的腐臭让贴近的敌人头晕目眩，先耗尽力气的往往是对手。",
        Skills = ["stench_aura"],
        Groups = [["cleaver", "flail"], ["shield", "power"], ["heavy_armor", "medium_armor"], ["tough", "vigorous"], ["laborer"]],
        Excluded = ["swift", "agile", "fast", "light_armor"], Weighted = ["hammer"]
    },
    carnage_fiend = {
        Name = "屠戮尸魔", Tier = 3, Skeleton = false, Stats = [180, 85, 10, 5, 120, 10], Scale = 1.0,
        Description = "指骨被拉长成钩爪，瘦长的身躯总是伏在地上。它会突然越过挡路的人，扑到真正的猎物身旁，把对方撕得鲜血淋漓。",
        Skills = ["rending_pounce"],
        Groups = [["cleaver", "axe"], ["swift", "power"], ["light_armor", "medium_armor"], ["fast", "agile"], ["wildling"]],
        Excluded = ["shield", "heavy_armor"], Weighted = ["sword", "vicious"]
    }
};

S.TierChoices <- [
    [["bloated_corpse", "fallen_hero", "frenzied_corpse"], ["dread_corpse_lord", "corpse_colossus", "carnage_fiend"]],
    [["grave_guard", "tomb_halberdier", "bone_blade"], ["skeleton_king", "barrow_knight", "tomb_blademaster"]]
];

S.TierTalents <- {
    grave_blade = { Flavor = "锈蚀的剑刃划开的伤口，从来不会真正愈合。", Name = "墓之刃", Description = "攻击命中后，目标受到的伤害提高 10%，持续 2 回合。重复命中刷新持续时间。", Script = "effects/pale_tier_attack_effect" },
    bone_break = { Flavor = "长戟的分量足以砸裂盾牌后面的骨头。", Name = "断骨", Description = "长柄武器攻击命中后，目标的近战防御降低 5 点，持续 2 回合。", Script = "effects/pale_tier_attack_effect" },
    chain_slash = { Flavor = "倒下一个，就立刻去找下一个。", Name = "连斩", Description = "每回合首次击杀敌人时回复 4 点行动点，最多回到行动点上限。", Script = "effects/pale_tier_attack_effect" },
    dead_command = { Flavor = "王冠所在之处，死者便列队听令。", Name = "号令亡魂", Description = "4 格内友方亡灵的近战技能 +5，对敌人造成的伤害 +10%。同名光环不叠加。", Script = "effects/pale_tier_aura" },
    death_charge = { Flavor = "墓冢骑士的第一击，总是最重的那一击。", Name = "死亡冲锋", Description = "每场战斗第一次攻击的伤害 +30%，命中使敌人踉跄。", Script = "effects/pale_tier_attack_effect" },
    first_strike = { Flavor = "敌人还没拔刀，胜负就已经分出。", Name = "先手斩", Description = "攻击本回合尚未行动的敌人时伤害 +25%。命中生命低于 50% 的敌人时必定击中头部。", Script = "effects/pale_tier_attack_effect" },
    rot_regen = { Flavor = "砍开的腐肉会自己慢慢合拢。", Name = "腐肉再生", Description = "每回合开始时恢复最大生命的 10%。", Script = "effects/pale_tier_body_effect" },
    death_burst = { Flavor = "就算倒下，也要把围攻者一起拖进坟墓。", Name = "死亡自爆", Description = "死亡时引爆自己的尸体。判定同尸爆，伤害为两倍，波及 2 格内的敌人，不伤友军。", Script = "effects/pale_tier_body_effect" },
    unyielding = { Flavor = "黑线越绷越紧，这具残躯就越难倒下。", Name = "不屈残躯", Description = "生命低于 50% 时受到的伤害降低 15%。", Script = "effects/pale_tier_body_effect" },
    flesh_frenzy = { Flavor = "流出的血越多，它就越疯狂。", Name = "血肉狂热", Description = "每损失 10% 最大生命，攻击伤害 +5%，最多 +30%。", Script = "effects/pale_tier_attack_effect" },
    heavy_stomp = { Flavor = "一脚下去，盾牌和骨头一起碎裂。", Name = "沉重践踏", Description = "重踏相邻敌人，钝击伤害为最大生命 ÷ 4 加头甲与身甲的疲劳惩罚，穿甲 45%、破甲 140%，无视一半盾防。命中时使其眩晕 1 回合，并波及它身旁的一名敌人。", Script = "actives/pale_heavy_stomp" },
    stench_aura = { Flavor = "离得太近的人，很快就会喘不过气。", Name = "腐臭光环", Description = "相邻敌人在回合开始时获得 8 点疲劳，本回合决心 −5。", Script = "effects/pale_tier_aura" },
    rending_pounce = { Flavor = "它总能越过挡路的人，扑向真正的猎物。", Name = "撕裂扑击", Description = "跃至 2 格内敌人身旁的空格并连续砍击，每次命中叠加流血。", Script = "actives/pale_rending_pounce" }
};

S.tierTalentID <- function( _key )
{
    return (::PaleSovereign.TierTalents[_key].Script.find("actives/") == 0 ? "actives.pale_" : "effects.pale_") + _key;
};

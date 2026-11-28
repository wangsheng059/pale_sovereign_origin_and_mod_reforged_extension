local S = ::PaleSovereign;
local weapon = ::Const.Items.WeaponType;

S.RangedTierChoices <- {
    archer = ["crypt_longbow", "tomb_arbalest", "barrow_skirmisher"],
    crypt_longbow = ["death_omen", "arrow_rain_weaver"],
    tomb_arbalest = ["nether_bombardier", "death_omen"],
    barrow_skirmisher = ["arrow_rain_weaver", "nether_bombardier"]
};

S.RangedTierKits <- [
    { Type = weapon.Bow, Ammo = ::Const.Items.AmmoType.Arrows, Quiver = "ammo/quiver_of_arrows" },
    { Type = weapon.Crossbow, Ammo = ::Const.Items.AmmoType.Bolts, Quiver = "ammo/quiver_of_bolts" },
    { Type = weapon.Firearm, Ammo = ::Const.Items.AmmoType.Powder, Quiver = "ammo/powder_bag" }
];

local branches = {
    crypt_longbow = {
        Name = "墓穴长弓手", Tier = 2, Stats = [70, 50, 5, 10, 100, 9], RangedSkill = 70,
        Description = "这具枯骨曾在空无一人的墓道里练习开弓。如今它能把一支箭送过两座坟丘，再钉进一块旧盾。",
        Skills = ["bone_piercing_arrow"], Groups = [["bow"], ["ranged"], ["light_armor"], ["trained"], ["soldier"]],
        Weapon = "weapons/hunting_bow", AllowedWeapons = weapon.Bow
    },
    tomb_arbalest = {
        Name = "古墓重弩卫", Tier = 2, Stats = [75, 55, 10, 15, 100, 9], RangedSkill = 68,
        Description = "它把弩托抵进肩窝，颌骨在弩弦松开以前一动不动。它生前想必守过一段漫长的城墙。",
        Skills = ["fixed_shot"], Groups = [["crossbow"], ["ranged"], ["medium_armor"], ["tough"], ["soldier"]],
        Weapon = "weapons/heavy_crossbow", AllowedWeapons = weapon.Crossbow | weapon.Firearm
    },
    barrow_skirmisher = {
        Name = "荒冢掷矛手", Tier = 2, Stats = [65, 60, 10, 15, 100, 9], RangedSkill = 65,
        Description = "细骨削成矛尖，麻绳捆成一束。每当第一支矛离手，下一支已经落进指骨之间。",
        Skills = ["bone_spike_throw"], Groups = [["throwing"], ["ranged"], ["light_armor"], ["fast"], ["raider"]],
        Weapon = "weapons/javelin", AllowedWeapons = weapon.Throwing
    },
    death_omen = {
        Name = "死兆猎手", Tier = 3, Stats = [80, 55, 10, 20, 120, 9], RangedSkill = 82,
        Description = "夜色和距离都遮不住它眼窝里的冷火。导师的诅咒一旦攀上敌人，那支箭就有了落点。",
        Skills = ["soulfire_lock"], Groups = [["bow", "crossbow"], ["ranged"], ["light_armor", "medium_armor"], ["trained"], ["soldier"]],
        Weapon = "weapons/war_bow", AllowedWeapons = weapon.Bow | weapon.Crossbow
    },
    nether_bombardier = {
        Name = "冥铁弩炮卫", Tier = 3, Stats = [105, 60, 15, 20, 120, 9], RangedSkill = 78,
        Description = "它熟悉重弩绞盘的每一个齿，也知道火炮后坐时该把肩抵在哪里。被它击中的人总要多花片刻才能站稳。",
        Skills = ["armor_shattering_bolt"], Groups = [["crossbow"], ["ranged"], ["medium_armor"], ["tough", "trained"], ["soldier"]],
        Weapon = "weapons/oriental/handgonne", AllowedWeapons = weapon.Firearm
    },
    arrow_rain_weaver = {
        Name = "箭雨织者", Tier = 3, Stats = [80, 55, 10, 25, 120, 9], RangedSkill = 75,
        Description = "空洞的眼窝顺着一条看不见的弧线抬起。箭矢和短矛从高处落下，把一小片阵地织得密不透风。",
        Skills = ["arrow_rain"], Groups = [["bow", "throwing"], ["ranged"], ["light_armor"], ["fast"], ["raider"]],
        Weapon = "weapons/war_bow", AllowedWeapons = weapon.Bow | weapon.Throwing
    }
};

foreach (id, branch in branches)
{
    branch.Skeleton <- true;
    branch.Scale <- 1.0;
    branch.Excluded <- ["dagger", "shield", "heavy_armor"];
    branch.Weighted <- [];
    S.TierBranches[id] <- branch;
}

local talents = {
    bone_piercing_arrow = {
        Name = "穿骨箭", Flavor = "枯骨记得将箭头磨到什么角度，才能穿过甲片的接缝。",
        Description = "弓类攻击的穿甲比例 +20 个百分点，攻击距离 +1（不含亡者箭雨）。"
    },
    fixed_shot = {
        Name = "定点射击", Flavor = "它能在扣下机括以前站上整整一夜。",
        Description = "本回合未移动时，弩和火炮攻击命中 +10、伤害 +15%。"
    },
    bone_spike_throw = {
        Name = "骨刺连投", Flavor = "第一支骨矛离手，指缝间已经夹住下一支。",
        Description = "每回合第一次投掷武器攻击后返还 2 行动点，且不消耗弹药。"
    },
    soulfire_lock = {
        Name = "魂火锁定", Flavor = "诅咒的寒光与远处的靶影，在它眼中一样清楚。",
        Description = "攻击受【衰弱】或【岁月诅咒】影响的敌人，或攻击 4 格以外的敌人时，伤害 +25%、命中头部概率 +25 个百分点。"
    },
    armor_shattering_bolt = {
        Name = "碎甲重矢", Flavor = "重矢撕开铁片，霰弹则把立足点从敌人脚下打掉。",
        Description = "弩和火炮攻击的护甲伤害 +50%，命中后使目标踉跄。"
    },
    arrow_rain = {
        Name = "亡者箭雨", Flavor = "它短促地抬手，骨箭和投矛随即从头顶落下。",
        Description = "以弓或投掷武器攻击 2–6 格内的目标格及其周围一格。每名敌人各受一次远程攻击，伤害 ×0.8。每场限 1 次。"
    }
};

foreach (id, talent in talents)
{
    talent.Script <- id == "arrow_rain" ? "actives/pale_arrow_rain" : "effects/pale_ranged_talent";
    S.TierTalents[id] <- talent;
}

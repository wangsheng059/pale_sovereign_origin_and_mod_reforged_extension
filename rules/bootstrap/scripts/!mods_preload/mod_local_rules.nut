// 背景专属特技（mod_bg_unique_perks）
// 给四个背景各做一个专属特技组（放在重铸“专属”特技组集合里，其余特技组照旧随机）：
//   神选者（北境扩张）  → 神选：野性活力、血祭*、浑身蛮力、野性之怒、诸神注视*
//   成名剑师（重铸）    → 成名剑师：直取空门、游刃有余*、迎击、洞悉招数、剑圣之名*（保留重铸的剑术大师组）
//   驯兽师（配件兄弟）  → 驯兽：兽群领袖*、人多势众、狩猎狂热*、声东击西*、狩猎时刻*
//   统帅（1.2.0 起为本 mod 新背景，继承冒险贵族；冒险贵族本身恢复重铸原版） → 统帅：
//     1 家族自豪感、2 集结部队、3 识骨相人*（主动）、4 军令如山*、5 化瑕为瑜*、6 赏罚分明* / 深渊共鸣*、7 战争艺术* / 千面归一* / 授印封将*（主动）（1.3.0）
// 1.1.0 新增：
//   刺客（北方 / 南方）  → 暗杀：九命猫、卑鄙手段、一击毙命*、行如鬼魅、隐没*（替换重铸的“恶棍”组）
//   流浪骑士（原版）    → 骑士：咄咄逼人、钢铁重压*、征服者、破甲重击*、毁灭一击*（主动）
//   老执誓者（本 mod 新背景，继承原版老执誓者；原版执誓者不改） → 誓约：生存本能、坚定意志、苦行戒律*、复仇之怒、不灭圣徒*
//   角斗士（原版）      → 斗技场：迅猛突袭、观众的宠儿*、战斗之潮、重振精神、斗技场老手*
//   死灵法师（1.4.0 本 mod 新背景，只能靠捕奴 mod 俘获敌方死灵法师获得） → 死灵法师：
//     1 死灵法术*、2 支配亡灵*、3 不死再生*、4 死灵精通* / 心灵交融*、5 嗜血者*、6 死灵灌注*（主动） / 钢铁之躯*、7 尸爆*（主动）
//     背景自带“复活死者”；复活野兽 / 亡灵 / 兽人 / 地精用 scripts/entity/tactical/bgp_undead/ 下单独的类（参考 Nectomancy 1.0、mod_necro 0.4.0）
//     1.5.0：死灵精通（需要配件兄弟）还能驯服亡灵、用“封魂入器”把复活的单位装进配件（宠物类在 scripts/entity/tactical/bgp_pet/）
//     1.5.1：支配亡灵对所有友方亡灵生效；能复活林德蠕龙、地精狼骑；封魂入器 6 格；死灵宠物固定装备（满耐久、不掉落）；只有死灵法师能装备死灵宠物
//     1.5.2：林德蠕龙改回不能复活；心灵交融的坚定意志换成轻灵 / 稳健；死灵宠物用亡灵特质池（新特质在 scripts/skills/bgp_quirks/），11 级得死灵契约
//     1.5.3：灵魂虹吸击杀时另回 20 疲劳；死灵宠物的战斗锻造不再要求护甲
//     1.6.0：拆成两个互斥的专属组 亡灵冠军 / 亡灵天灾（死灵精通共用），死灵法术并入背景；新特技 血肉重铸、不灭冠军、岁月诅咒；
//            死灵宠物也挂死灵仆从效果；野兽宠物保留轻灵；修装备记录把所有装备都跳过的 bug
//     1.6.1：亡灵天灾 5 层嗜血者换成腐毒蝇群
//     1.6.2：两组 8 个特技按死灵法师当前决心（W）加成：支配亡灵、血肉重铸、死灵灌注、不灭号令、不死再生、钢铁之躯、岁月诅咒、尸爆
//     1.6.3：决心加成 W 改为 当前决心 − 20（最低 0）
//     1.6.4：尸爆基础消耗 3 行动点、8 疲劳；不灭号令恢复 15% + W/3 %；驱役亡灵只能收进空着的饰品栏；冠军 / 天灾特技说明写明对死灵宠物、永恒禁卫生效
// 带 * 的是本 mod 新做的特技。
// 特技树只在招募（setStartValuesEx）时生成并随存档保存；已在队里的角色不变，
// 被达库尔转化（只替换背景技能）后特技树也保持原样。

::BGP <- {
	ID = "mod_local_rules",
	Version = "1.6.7",
	Name = "本地玩法规则",
	HasAC = false
};

::BGP.HooksMod <- ::Hooks.register(::BGP.ID, ::BGP.Version, ::BGP.Name);
::BGP.HooksMod.require("mod_reforged", "mod_dynamic_perks", "mod_msu");

::BGP.HooksMod.queue([">mod_reforged", ">mod_dynamic_perks", ">mod_msu", ">mod_AC", ">mod_north_expansion", ">mod_upd", ">mod_modular_vanilla"], function()
{
	::include("mod_bg_unique_perks/utils");
	::include("mod_bg_unique_perks/necro");
	::include("mod_bg_unique_perks/necro_art");
	::include("mod_bg_unique_perks/necro_raise_map");
	::include("mod_bg_unique_perks/necro_champion");
	::include("mod_bg_unique_perks/perk_defs");
	::include("mod_bg_unique_perks/perk_defs_2");
	::include("mod_bg_unique_perks/perk_defs_3");
	::include("mod_bg_unique_perks/perk_defs_4");
	::include("mod_bg_unique_perks/hooks");
	::include("mod_bg_unique_perks/necro_hooks");
	::include("mod_local_rules/combat_xp");
	::include("mod_local_rules/weapon_loot");
});

// 特技组要等全部脚本加载完、重铸的特技组和集合注册之后再加
::BGP.HooksMod.queue([">mod_reforged", ">mod_dynamic_perks"], function()
{
	::include("mod_bg_unique_perks/perk_groups");
}, ::Hooks.QueueBucket.AfterHooks);

// 配件兄弟 × 潘多拉的嗜好 兼容补丁
// 1. 驯服潘多拉的冠军野兽后，宠物保留冠军加成（以“冠军”特质存储，放出时生效）。
// 2. 恐惧战狼接入配件兄弟的宠物系统（等级、特质、属性成长、存档）。
// 3. 用宠物制作恐惧战狼时，继承原宠物的名字、等级、经验、成长属性和后天特质。
// 4. 重铸的地狱犬可以驯服（新宠物种类）。
// 5. 修复北境扩张的冰原狼白灵（原名 Ghost；接入配件兄弟宠物系统，仍只有驯狼者能装备）。
// 6. 德鲁伊召唤的野兽按德鲁伊等级成长，并随机获得配件兄弟的宠物特质。
// 7. 特质池新增 5 个通用重铸特技，以及按野兽种类的专属特技（1.2.1 起在 11 级一次性获得）。
// 8. 装了重铸时战狼也接入配件兄弟宠物系统，并补回重铸、潘多拉给战狼的加成（1.2.2）。
// 9. 重铸经验：有主人的宠物造成的伤害记到主人名下，宠物击杀时兄弟拿到完整经验（1.2.3）。

::AC_PH_Compat <- {
	ID = "mod_ac_ph_compat",
	Version = "1.2.4",
	Name = "配件兄弟×潘多拉兼容补丁"
};

::AC_PH_Compat.HooksMod <- ::Hooks.register(::AC_PH_Compat.ID, ::AC_PH_Compat.Version, ::AC_PH_Compat.Name);
::AC_PH_Compat.HooksMod.require("mod_AC", "mod_pandoras_hobby");

::AC_PH_Compat.HooksMod.queue([">mod_AC", ">mod_pandoras_hobby", ">mod_reforged", ">mod_druid", ">mod_north_expansion"], function()
{
	::include("mod_ac_ph_compat/champions");
	::include("mod_ac_ph_compat/hooks");
	::include("mod_ac_ph_compat/hooks_more");
	if (::Hooks.hasMod("mod_reforged"))
		::include("mod_ac_ph_compat/xp_share");
});

// 配件兄弟的宠物库和特质表定义在 scripts/companions 下，要等全部脚本加载完才存在。
::AC_PH_Compat.HooksMod.queue([">mod_AC", ">mod_pandoras_hobby"], function()
{
	::include("mod_ac_ph_compat/library");
}, ::Hooks.QueueBucket.AfterHooks);

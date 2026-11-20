// 统帅：本 mod 新背景，继承原版冒险贵族（adventurous_noble_background），只把专属特技组换成“统帅”。
// 冒险贵族本身保持重铸原版（专属组“贵族”）。
// 捕奴背景扩展 1.0.3 起把俘获的重铸强盗男爵（rf_bandit_baron）、元帅（rf_marshal）转成这个背景。
// 其余特技组倾向沿用重铸冒险贵族：领袖组权重 ×20、战术家 / 重甲 ×3、训练有素 ×5，共享集合多抽 1 组。
// 1.3.0：加入时给角色打上标记 bgp_commander（随存档保存；达库尔转化只换背景，标记保留），
// 用于“神选者且等级 ≥ 11 时自动升为达库尔先知”（见 hooks.nut）。
this.bgp_commander_background <- this.inherit("scripts/skills/backgrounds/adventurous_noble_background", {
	m = {},
	function create()
	{
		this.adventurous_noble_background.create();
		this.m.ID = "background.bgp_commander";
		this.m.Name = "统帅";
	}

	function onAdded()
	{
		this.adventurous_noble_background.onAdded();
		try { this.getContainer().getActor().getFlags().set("bgp_commander", true); } catch (e) {}
	}

	function createPerkTreeBlueprint()
	{
		return ::BGP.setExclusive(this.adventurous_noble_background.createPerkTreeBlueprint(), ["pg.bgp_noble"]);
	}
});

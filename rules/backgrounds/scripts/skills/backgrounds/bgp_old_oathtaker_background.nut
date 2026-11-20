// 老执誓者：本 mod 新背景，继承原版老执誓者（old_paladin_background），只换专属特技组。
// 原版执誓者（paladin_background）和原版老执誓者都不改。
// 捕奴背景扩展把俘获的执誓者敌人（oathbringer / firstborn）转成这个背景。
this.bgp_old_oathtaker_background <- this.inherit("scripts/skills/backgrounds/old_paladin_background", {
	m = {},
	function create()
	{
		this.old_paladin_background.create();
		this.m.ID = "background.bgp_old_oathtaker";
		this.m.Name = "老执誓者";
	}

	function createPerkTreeBlueprint()
	{
		return ::BGP.setExclusive(this.old_paladin_background.createPerkTreeBlueprint(), ["pg.bgp_oathtaker"]);
	}
});

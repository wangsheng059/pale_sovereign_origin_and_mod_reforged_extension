// 配件兄弟版恐惧战狼：沿用配件兄弟的恐狼宠物（外观、啃咬、AI、等级缩放），
// 再补上潘多拉恐惧战狼的两项特性：不容易被敌人当作目标、不会受伤病影响。
this.companions_ph_dreadwolf <- this.inherit("scripts/companions/types/companions_direwolf", {
	m = {},
	function create()
	{
		this.companions_direwolf.create();
		this.m.Name = "恐惧战狼";
	}

	function applyCompanionScaling()
	{
		this.companions_direwolf.applyCompanionScaling();
		local b = this.m.BaseProperties;
		b.TargetAttractionMult = 0.5;
		b.IsAffectedByInjuries = false;
	}
});

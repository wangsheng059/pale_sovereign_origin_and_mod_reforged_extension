// 配件兄弟版冰原狼白灵（北境扩张原名 Ghost）：沿用配件兄弟的恐狼宠物，
// 补上北境扩张原版 Ghost 的外观和特性（固定外观、不易被当作目标、不受伤病、“狼与主人”加成）。
this.companions_ne_ghost <- this.inherit("scripts/companions/types/companions_direwolf", {
	m = {},
	function create()
	{
		this.companions_direwolf.create();
		this.m.Name = "白灵";
	}

	function setVariant( _v )
	{
		this.m.Items.getAppearance().Body = "bust_direwolf_01_body";
		this.getSprite("body").setBrush("bust_direwolf_01");
		this.getSprite("head").setBrush("bust_direwolf_01_head");
		this.setDirty(true);
	}

	function applyCompanionScaling()
	{
		this.companions_direwolf.applyCompanionScaling();
		local b = this.m.BaseProperties;
		b.TargetAttractionMult = 0.1;
		b.IsAffectedByInjuries = false;

		try
		{
			if (!this.m.Skills.hasSkill("effects.wolfmaster_bonus"))
				this.m.Skills.add(this.new("scripts/skills/effects/wolfmaster_bonus_effect"));
		}
		catch (e) {}
	}
});

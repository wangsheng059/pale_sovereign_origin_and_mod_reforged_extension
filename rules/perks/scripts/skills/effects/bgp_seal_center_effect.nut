// 中军印·磐石卫：自身受到伤害 -10%，敌方注意 ×2；相邻友军的 -20% 减伤在友军的 effects.bgp_command_link 里判定
this.bgp_seal_center_effect <- ::inherit("scripts/skills/skill", {
	m = {},
	function create()
	{
		this.m.ID = "effects.bgp_seal_center";
		this.m.Name = "中军印";
		this.m.Icon = "skills/bgp_seal_center_skill.png";
		this.m.Type = ::Const.SkillType.StatusEffect;
		this.m.Order = ::Const.SkillOrder.Perk;
		this.m.IsActive = false;
		this.m.IsRemovedAfterBattle = true;
		this.m.IsSerialized = false;
	}

	function getDescription()
	{
		return "磐石卫：立于阵中，护住两翼。";
	}

	function getTooltip()
	{
		local ret = this.skill.getTooltip();
		ret.push({ id = 10, type = "text", icon = "ui/icons/special.png", text = "相邻的友军受到伤害 " + ::MSU.Text.colorPositive("-20%") });
		ret.push({ id = 11, type = "text", icon = "ui/icons/special.png", text = "自身受到伤害 " + ::MSU.Text.colorPositive("-10%") });
		ret.push({ id = 12, type = "text", icon = "ui/icons/special.png", text = "敌人更倾向于攻击他" });
		return ret;
	}

	function onAdded()
	{
		// 相邻友军的减伤要靠他们身上的联动效果
		::BGP.ensureCommandLinks();
	}

	function onUpdate( _properties )
	{
		_properties.DamageReceivedTotalMult *= 0.9;
		_properties.TargetAttractionMult *= 2.0;
	}
});

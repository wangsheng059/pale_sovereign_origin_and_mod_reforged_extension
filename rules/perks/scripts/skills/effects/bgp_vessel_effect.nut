// 识骨相人给目标的指令，持续整场战斗
// Kind 0 苦行之躯（生命 / 疲劳）、1 无声巡猎（主动 / 远程 / 远防）、2 血祭处决（近战 / 近防 / 决心）
this.bgp_vessel_effect <- ::inherit("scripts/skills/skill", {
	m = {
		Kind = 2,
		FatigueMult = 0.7,
		ReductionPerTier = 0.02,
		DirectAdd = 0.15,
		DamagePerEnemy = 0.08,
		MaxEnemies = 3,
		Lifesteal = 0.15
	},
	function create()
	{
		this.m.ID = "effects.bgp_vessel";
		this.m.Name = ::BGP.PerkNames.Discerning;
		this.m.Icon = "ui/perks/perk_bgp_discerning.png";
		this.m.Type = ::Const.SkillType.StatusEffect;
		this.m.Order = ::Const.SkillOrder.Perk;
		this.m.IsActive = false;
		this.m.IsRemovedAfterBattle = true;
		this.m.IsSerialized = false;
	}

	function setKind( _k )
	{
		this.m.Kind = _k;
		this.m.Name = this.getKindName();
	}

	function getKindName()
	{
		switch (this.m.Kind)
		{
			case 0: return "苦行之躯";
			case 1: return "无声巡猎";
		}
		return "血祭处决";
	}

	function getDescription()
	{
		return "统帅看穿了这副骨相，知道该把他用在哪里。持续整场战斗。";
	}

	function getTier()
	{
		return ::BGP.getCultistTier(this.getContainer().getActor());
	}

	function getTooltip()
	{
		local ret = this.skill.getTooltip();
		local tier = this.getTier();
		switch (this.m.Kind)
		{
			case 0:
				ret.push({ id = 10, type = "text", icon = "ui/icons/fatigue.png", text = "使用技能与受击产生的疲劳 " + ::MSU.Text.colorPositive("-30%") });
				if (tier > 0)
					ret.push({ id = 11, type = "text", icon = "ui/icons/special.png", text = "受到的伤害 " + ::MSU.Text.colorPositive("-" + (::Math.min(6, tier) * 2) + "%") + "（信徒阶位 " + tier + "）" });
				break;
			case 1:
				ret.push({ id = 10, type = "text", icon = "ui/icons/special.png", text = "免疫控制区（离开敌人控制区时不会受到借机攻击）" });
				ret.push({ id = 11, type = "text", icon = "ui/icons/direct_damage.png", text = "穿甲伤害比例 " + ::MSU.Text.colorPositive("+15%") });
				break;
			default:
				ret.push({ id = 10, type = "text", icon = "ui/icons/regular_damage.png", text = "攻击时相邻敌人每比相邻友军多 1 名，伤害 " + ::MSU.Text.colorPositive("+8%") + "（最多 +24%）" });
				if (tier >= 0)
					ret.push({ id = 11, type = "text", icon = "ui/icons/health.png", text = "造成生命伤害的 " + ::MSU.Text.colorPositive("15%") + " 回复自身生命" });
				break;
		}
		return ret;
	}

	function onUpdate( _properties )
	{
		if (this.m.Kind == 0)
		{
			_properties.FatigueEffectMult *= this.m.FatigueMult;
			local tier = this.getTier();
			if (tier > 0)
				_properties.DamageReceivedTotalMult *= 1.0 - this.m.ReductionPerTier * ::Math.min(6, tier);
		}
		else if (this.m.Kind == 1)
		{
			_properties.IsImmuneToZoneOfControl = true;
			_properties.DamageDirectAdd += this.m.DirectAdd;
		}
	}

	function onAnySkillUsed( _skill, _targetEntity, _properties )
	{
		if (this.m.Kind != 2 || _targetEntity == null || _skill == null || !_skill.isAttack())
			return;
		local adj = ::BGP.countAdjacent(this.getContainer().getActor());
		local diff = ::Math.min(this.m.MaxEnemies, adj.Enemies - adj.Allies);
		if (diff > 0)
			_properties.DamageTotalMult *= 1.0 + this.m.DamagePerEnemy * diff;
	}

	function onTargetHit( _skill, _targetEntity, _bodyPart, _damageInflictedHitpoints, _damageInflictedArmor )
	{
		if (this.m.Kind != 2 || _damageInflictedHitpoints <= 0)
			return;
		if (this.getTier() < 0)
			return;
		::BGP.heal(this.getContainer().getActor(), ::Math.floor(_damageInflictedHitpoints * this.m.Lifesteal));
	}
});

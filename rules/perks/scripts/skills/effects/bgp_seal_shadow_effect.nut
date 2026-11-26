// 奇兵印·暗影刺：攻击本场没攻击过自己的敌人时穿甲 +20%、近战无视盾牌近防；击杀后到下一回合开始敌方注意 ×0.3
this.bgp_seal_shadow_effect <- ::inherit("scripts/skills/skill", {
	m = {
		Attackers = {},
		IsHidden = false
	},
	function create()
	{
		this.m.ID = "effects.bgp_seal_shadow";
		this.m.Name = "奇兵印";
		this.m.Icon = "skills/bgp_seal_shadow_skill.png";
		this.m.Type = ::Const.SkillType.StatusEffect;
		this.m.Order = ::Const.SkillOrder.Perk;
		this.m.IsActive = false;
		this.m.IsRemovedAfterBattle = true;
		this.m.IsSerialized = false;
		this.m.Attackers = {};
	}

	function getDescription()
	{
		return "暗影刺：出其不意，一击即走。";
	}

	function getTooltip()
	{
		local ret = this.skill.getTooltip();
		ret.push({ id = 10, type = "text", icon = "ui/icons/direct_damage.png", text = "攻击本场还没攻击过他的敌人时：穿甲伤害比例 " + ::MSU.Text.colorPositive("+20%") + "，近战攻击无视目标盾牌的近战防御（盾墙额外防御按一半计算）" });
		ret.push({ id = 11, type = "text", icon = "ui/icons/special.png", text = "已攻击过他的敌人：" + this.m.Attackers.len() + " 名" });
		ret.push({ id = 12, type = "text", icon = "ui/icons/special.png", text = "隐入阵中：击杀敌人后至下一回合开始，敌人不太会把他当作目标" + (this.m.IsHidden ? ::MSU.Text.colorPositive("（当前已生效）") : "（未触发）") });
		return ret;
	}

	function record( _attacker )
	{
		try
		{
			if (_attacker != null && !(_attacker instanceof ::WeakTableRef && _attacker.isNull()))
				this.m.Attackers[_attacker.getID()] <- true;
		}
		catch (e)
		{
		}
	}

	function onBeingAttacked( _attacker, _skill, _properties )
	{
		this.record(_attacker);
	}

	function onDamageReceived( _attacker, _damageHitpoints, _damageArmor )
	{
		this.record(_attacker);
	}

	function onAnySkillUsed( _skill, _targetEntity, _properties )
	{
		if (_skill == null || _targetEntity == null || !_skill.isAttack())
			return;
		local id = -1;
		try { id = _targetEntity.getID(); } catch (e) { return; }
		if (id in this.m.Attackers)
			return;
		_properties.DamageDirectAdd += 0.2;
		if (!_skill.isRanged())
			_properties.MeleeSkill += ::BGP.getShieldCompensation(_targetEntity);
	}

	function onTargetKilled( _targetEntity, _skill )
	{
		this.m.IsHidden = true;
		this.getContainer().getActor().setDirty(true);
	}

	function onUpdate( _properties )
	{
		if (this.m.IsHidden)
			_properties.TargetAttractionMult *= 0.3;
	}

	function onTurnStart()
	{
		if (this.m.IsHidden)
		{
			this.m.IsHidden = false;
			this.getContainer().getActor().setDirty(true);
		}
	}
});

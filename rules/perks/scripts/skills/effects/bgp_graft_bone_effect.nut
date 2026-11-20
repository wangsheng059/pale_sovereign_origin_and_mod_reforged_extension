// 1.6.0 血肉重铸第 1 次嫁接：骨刺外甲
//   1.6.2 起按施放者决心 W：骨甲 40 + W/2，反伤 5 + W/4（下面写的 80 / 15 是 1.6.0 的固定值）
//   独立骨甲 80：受到攻击时先吸收原始伤害（生命伤害和对护甲伤害按同一比例减少），吸收量在伤害实际结算后扣除
//   （onBeforeDamageReceived 也会被伤害预览调用，所以只在 onDamageReceived 里真正扣）；
//   骨甲没碎时，每次被敌人近战攻击（命中或闪避）对攻击者造成 15 点穿刺伤害（无视护甲）
this.bgp_graft_bone_effect <- ::inherit("scripts/skills/skill", {
	m = {
		Pool = 40,
		PoolMax = 40,
		Thorns = 5,
		PendingAbsorb = 0,
		PendingThorn = null
	},
	function create()
	{
		this.m.ID = "effects.bgp_graft_bone";
		this.m.Name = "骨刺外甲";
		this.m.Description = "嫁接上去的骨板和骨刺裹住了这具躯体。";
		this.m.Icon = "skills/bgp_necro_flesh_reforge_skill.png";
		this.m.IconMini = "";
		this.m.Type = ::Const.SkillType.StatusEffect;
		this.m.Order = ::Const.SkillOrder.Last;
		this.m.IsActive = false;
		this.m.IsStacking = false;
		this.m.IsRemovedAfterBattle = true;
		this.m.IsSerialized = false;
	}

	function getTooltip()
	{
		local ret = this.skill.getTooltip();
		ret.push({ id = 10, type = "text", icon = "ui/icons/armor_body.png", text = "骨甲 " + ::MSU.Text.colorPositive(this.m.Pool) + " / " + this.m.PoolMax + "：先于护甲吸收伤害" });
		if (this.m.Pool > 0)
			ret.push({ id = 11, type = "text", icon = "ui/icons/special.png", text = "被敌人近战攻击时，对攻击者造成 " + ::MSU.Text.colorNegative(this.m.Thorns) + " 点穿刺伤害（无视护甲）" });
		else
			ret.push({ id = 11, type = "text", icon = "ui/icons/warning.png", text = "骨甲已碎，骨刺不再生效" });
		return ret;
	}

	function setWill( _w )
	{
		this.m.PoolMax = ::BGP.Necro.WillScale.BoneArmor(_w);
		this.m.Pool = this.m.PoolMax;
		this.m.Thorns = ::BGP.Necro.WillScale.BoneThorns(_w);
	}

	function isMeleeAttackBy( _attacker, _skill )
	{
		if (_attacker == null || _skill == null)
			return false;
		try
		{
			if (!_skill.isAttack() || _skill.isRanged())
				return false;
			return !_attacker.isAlliedWith(this.getContainer().getActor());
		}
		catch (e)
		{
		}
		return false;
	}

	function onBeforeDamageReceived( _attacker, _skill, _hitInfo, _properties )
	{
		this.m.PendingAbsorb = 0;
		this.m.PendingThorn = null;
		if (this.m.Pool <= 0)
			return;
		if (this.isMeleeAttackBy(_attacker, _skill))
			this.m.PendingThorn = ::MSU.asWeakTableRef(_attacker);
		if (_hitInfo.DamageRegular <= 0)
			return;
		local absorb = ::Math.min(this.m.Pool, _hitInfo.DamageRegular);
		local ratio = (_hitInfo.DamageRegular - absorb) / _hitInfo.DamageRegular;
		_hitInfo.DamageRegular -= absorb;
		_hitInfo.DamageArmor = ::Math.maxf(0.0, _hitInfo.DamageArmor * ratio);
		this.m.PendingAbsorb = absorb;
	}

	function onDamageReceived( _attacker, _damageHitpoints, _damageArmor )
	{
		local actor = this.getContainer().getActor();
		if (this.m.PendingAbsorb > 0)
		{
			this.m.Pool = ::Math.max(0, this.m.Pool - ::Math.round(this.m.PendingAbsorb));
			if (this.m.Pool == 0)
				::BGP.log(actor, "的骨刺外甲碎裂了");
		}
		this.m.PendingAbsorb = 0;
		this.fireThorns();
	}

	function onMissed( _attacker, _skill )
	{
		if (this.m.Pool > 0 && this.isMeleeAttackBy(_attacker, _skill))
		{
			this.m.PendingThorn = ::MSU.asWeakTableRef(_attacker);
			this.fireThorns();
		}
	}

	function fireThorns()
	{
		local thorn = this.m.PendingThorn;
		this.m.PendingThorn = null;
		if (thorn == null || ::MSU.isNull(thorn))
			return;
		::BGP.Champion.applyThorns(this.getContainer().getActor(), thorn.get(), this, this.m.Thorns);
	}
});

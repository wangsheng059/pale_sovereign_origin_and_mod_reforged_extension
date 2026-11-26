// 挂在友方野兽身上：兽群领袖的加成、士气保护，以及狩猎狂热的触发检测
this.bgp_beast_link_effect <- ::inherit("scripts/skills/skill", {
	m = {
		BleedBefore = null,   // 目标 ID → 命中前的流血层数
		Bonus = null          // 本次更新算出的兽群领袖加成
	},
	function create()
	{
		this.m.ID = "effects.bgp_beast_link";
		this.m.Name = ::BGP.PerkNames.PackLeader;
		this.m.Icon = "ui/perks/perk_bgp_pack_leader.png";
		this.m.Type = ::Const.SkillType.StatusEffect;
		this.m.Order = ::Const.SkillOrder.Perk;
		this.m.IsActive = false;
		this.m.IsRemovedAfterBattle = true;
		this.m.IsSerialized = false;
		this.m.BleedBefore = {};
	}

	function getDescription()
	{
		return "附近的驯兽师在指挥兽群。";
	}

	// 4 格内加成最高的一位带“兽群领袖”的驯兽师
	function getPackLeader()
	{
		local actor = this.getContainer().getActor();
		if (!::BGP.isValid(actor))
			return null;

		local best = null;
		local bestScore = -1;
		foreach (bm in ::BGP.getBrosWithSkill("perk.bgp_pack_leader"))
		{
			if (::BGP.distance(bm, actor) > 4)
				continue;
			local p = bm.getCurrentProperties();
			local score = p.getMeleeSkill() + p.getMeleeDefense() + p.getBravery();
			if (score > bestScore)
			{
				bestScore = score;
				best = bm;
			}
		}
		return best;
	}

	function isHidden()
	{
		return this.m.Bonus == null;
	}

	function getTooltip()
	{
		local ret = this.skill.getTooltip();
		if (this.m.Bonus != null)
		{
			ret.extend([
				{ id = 10, type = "text", icon = "ui/icons/melee_skill.png", text = "近战技能 " + ::MSU.Text.colorPositive("+" + this.m.Bonus.MeleeSkill) },
				{ id = 11, type = "text", icon = "ui/icons/melee_defense.png", text = "近战防御 " + ::MSU.Text.colorPositive("+" + this.m.Bonus.MeleeDefense) },
				{ id = 12, type = "text", icon = "ui/icons/bravery.png", text = "决心 " + ::MSU.Text.colorPositive("+" + this.m.Bonus.Bravery) + "，面对恐惧类精神攻击再 " + ::MSU.Text.colorPositive("+15") },
				{ id = 13, type = "text", icon = "ui/icons/special.png", text = "不会因为自身受伤而溃逃" }
			]);
		}
		return ret;
	}

	function onUpdate( _properties )
	{
		this.m.Bonus = null;
		local bm = null;
		try { bm = this.getPackLeader(); } catch (e) { bm = null; }
		if (bm == null)
			return;

		local p = bm.getCurrentProperties();
		this.m.Bonus = {
			MeleeSkill = ::Math.floor(p.getMeleeSkill() * 0.1),
			MeleeDefense = ::Math.floor(p.getMeleeDefense() * 0.1),
			Bravery = ::Math.floor(p.getBravery() * 0.1)
		};
		_properties.MeleeSkill += this.m.Bonus.MeleeSkill;
		_properties.MeleeDefense += this.m.Bonus.MeleeDefense;
		_properties.Bravery += this.m.Bonus.Bravery;
		_properties.MoraleCheckBravery[::Const.MoraleCheckType.MentalAttack] += 15;
	}

	function onBeforeTargetHit( _skill, _targetEntity, _hitInfo )
	{
		if (_targetEntity == null)
			return;
		this.m.BleedBefore[_targetEntity.getID()] <- ::BGP.countBleedingStacks(_targetEntity);
	}

	function onTargetHit( _skill, _targetEntity, _bodyPart, _damageInflictedHitpoints, _damageInflictedArmor )
	{
		if (_targetEntity == null)
			return;
		local id = _targetEntity.getID();
		if (!(id in this.m.BleedBefore))
			return;
		local before = this.m.BleedBefore[id];
		delete this.m.BleedBefore[id];

		if (!_targetEntity.isAlive() || _targetEntity.isDying())
			return;   // 击杀由 onTargetKilled 处理，避免同一次攻击算两次
		local actor = this.getContainer().getActor();
		if (_targetEntity.isAlliedWith(actor))
			return;

		if (::BGP.countBleedingStacks(_targetEntity) > before)
			::BGP.triggerHuntingFever();
	}

	function onTargetKilled( _targetEntity, _skill )
	{
		local actor = this.getContainer().getActor();
		if (_targetEntity == null || _targetEntity.isAlliedWith(actor))
			return;
		::BGP.triggerHuntingFever();

		local owner = ::BGP.getPetOwner(actor);
		if (owner != null)
			::BGP.triggerSharedHatred(owner);
	}

	// 同仇敌忾：站在主人旁边时受到的伤害 -20%
	function onBeforeDamageReceived( _attacker, _skill, _hitInfo, _properties )
	{
		local actor = this.getContainer().getActor();
		local owner = ::BGP.getPetOwner(actor);
		if (owner == null || !::BGP.isValid(owner))
			return;
		try
		{
			if (owner.getSkills().hasSkill("perk.bgp_shared_hatred") && ::BGP.distance(owner, actor) == 1)
				_properties.DamageReceivedTotalMult *= 0.8;
		}
		catch (e)
		{
		}
	}
});

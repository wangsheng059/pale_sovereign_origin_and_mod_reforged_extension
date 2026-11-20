this.perk_bgp_gods_gaze <- ::inherit("scripts/skills/skill", {
	m = {
		APStacks = 0,
		MoveStacks = 0,
		ShellStacks = 0,
		StunCharges = 0,
		ArmorBoosts = null   // [{ Item = WeakTableRef, Amount = 20 }]，create 里初始化
	},
	function create()
	{
		this.m.ID = "perk.bgp_gods_gaze";
		this.m.Name = ::BGP.PerkNames.GodsGaze;
		this.m.Description = ::BGP.PerkDescriptions.GodsGaze;
		this.m.Icon = "ui/perks/perk_bgp_gods_gaze.png";
		this.m.Type = ::Const.SkillType.Perk | ::Const.SkillType.StatusEffect;
		this.m.Order = ::Const.SkillOrder.Perk;
		this.m.ArmorBoosts = [];
	}

	function isHidden()
	{
		return this.m.APStacks + this.m.MoveStacks + this.m.ShellStacks + this.m.StunCharges == 0;
	}

	function getDescription()
	{
		return "诸神在看着你。每一次杀戮，都会换来一份恩赐。";
	}

	function getTooltip()
	{
		local ret = this.skill.getTooltip();
		if (this.m.APStacks > 0)
			ret.push({ id = 10, type = "text", icon = "ui/icons/action_points.png", text = "行动点数 " + ::MSU.Text.colorPositive("+" + (2 * this.m.APStacks)) });
		if (this.m.MoveStacks > 0)
			ret.push({ id = 11, type = "text", icon = "ui/icons/fatigue.png", text = "每格移动消耗行动点数 " + ::MSU.Text.colorPositive("-" + this.m.MoveStacks) + "、疲劳 " + ::MSU.Text.colorPositive("-" + (2 * this.m.MoveStacks)) + "（每格最少 1 点）" });
		if (this.m.ShellStacks > 0)
			ret.push({ id = 12, type = "text", icon = "ui/icons/health.png", text = "生命值上限 " + ::MSU.Text.colorPositive("+" + (20 * this.m.ShellStacks)) + "，已获得 " + this.m.ShellStacks + " 次 +20 头甲 / 身甲" });
		if (this.m.StunCharges > 0)
			ret.push({ id = 13, type = "text", icon = "ui/icons/special.png", text = "接下来 " + ::MSU.Text.colorPositive(this.m.StunCharges) + " 次命中会使目标眩晕" });
		return ret;
	}

	function onUpdate( _properties )
	{
		_properties.ActionPoints += 2 * this.m.APStacks;
		_properties.Hitpoints += 20 * this.m.ShellStacks;
	}

	function onAfterUpdate( _properties )
	{
		if (this.m.MoveStacks <= 0)
			return;

		_properties.MovementAPCostAdditional -= this.m.MoveStacks;   // 引擎把每格行动点数消耗限制在至少 1

		// 疲劳引擎不设下限：保证最便宜的地格每格仍至少消耗 1 点
		local actor = this.getContainer().getActor();
		local minCost = 9999;
		try
		{
			foreach (c in actor.m.FatigueCosts)
			{
				if (c > 0 && c < minCost)
					minCost = c;
			}
		}
		catch (e)
		{
			minCost = 9999;
		}
		if (minCost == 9999)
			return;

		local headroom = minCost + _properties.MovementFatigueCostAdditional - 1;
		if (headroom > 0)
			_properties.MovementFatigueCostAdditional -= ::Math.min(2 * this.m.MoveStacks, headroom);
	}

	function onTargetKilled( _targetEntity, _skill )
	{
		local actor = this.getContainer().getActor();
		if (_targetEntity == null || _targetEntity.isAlliedWith(actor))
			return;

		switch (::Math.rand(1, 4))
		{
			case 1:
				this.m.APStacks++;
				::BGP.log(actor, "获得诸神恩赐：行动点数 +2");
				break;

			case 2:
				this.m.MoveStacks++;
				::BGP.log(actor, "获得诸神恩赐：移动更轻快");
				break;

			case 3:
				this.m.ShellStacks++;
				this.grantShell(actor);
				::BGP.log(actor, "获得诸神恩赐：护甲与生命 +20");
				break;

			default:
				this.m.StunCharges++;
				::BGP.log(actor, "获得诸神恩赐：下一次命中使目标眩晕");
				break;
		}

		this.getContainer().update();
	}

	function grantShell( _actor )
	{
		foreach (slot in [::Const.ItemSlot.Head, ::Const.ItemSlot.Body])
		{
			local item = _actor.getItems().getItemAtSlot(slot);
			if (item == null)
				continue;
			try
			{
				item.m.ConditionMax += 20;
				item.m.Condition += 20;
				this.m.ArmorBoosts.push({ Item = (item instanceof ::WeakTableRef) ? item : ::WeakTableRef(item), Amount = 20 });
			}
			catch (e)
			{
			}
		}

		this.getContainer().update();
		_actor.setHitpoints(::Math.min(_actor.getHitpointsMax(), _actor.getHitpoints() + 20));
		_actor.setDirty(true);
	}

	function onTargetHit( _skill, _targetEntity, _bodyPart, _damageInflictedHitpoints, _damageInflictedArmor )
	{
		if (this.m.StunCharges <= 0 || _skill == null || !_skill.isAttack())
			return;
		if (_targetEntity == null || !_targetEntity.isAlive() || _targetEntity.isDying())
			return;

		this.m.StunCharges--;

		if (_targetEntity.getCurrentProperties().IsImmuneToStun)
			return;

		_targetEntity.getSkills().add(::new("scripts/skills/effects/stunned_effect"));
		::BGP.log(_targetEntity, "被诸神的力量震晕了");
	}

	function revertArmor()
	{
		foreach (b in this.m.ArmorBoosts)
		{
			try
			{
				if (b.Item == null || b.Item.isNull())
					continue;
				local item = b.Item.get();
				item.m.ConditionMax = ::Math.max(1, item.m.ConditionMax - b.Amount);
				item.m.Condition = ::Math.min(item.m.Condition, item.m.ConditionMax);
			}
			catch (e)
			{
			}
		}
		this.m.ArmorBoosts = [];
	}

	function reset()
	{
		this.revertArmor();
		this.m.APStacks = 0;
		this.m.MoveStacks = 0;
		this.m.ShellStacks = 0;
		this.m.StunCharges = 0;
	}

	function onCombatStarted()
	{
		this.reset();
	}

	function onCombatFinished()
	{
		this.skill.onCombatFinished();
		this.reset();
	}

	function onDeath( _fatalityType )
	{
		this.revertArmor();
	}

	function onRemoved()
	{
		this.revertArmor();
	}
});

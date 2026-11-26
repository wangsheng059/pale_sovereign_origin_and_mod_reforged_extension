// The saved skill ID and both resource paths stay compatible with existing saves.
this.bgp_necro_bind_skill <- ::inherit("scripts/skills/skill", {
	m = {},
	function create()
	{
		this.m.ID = "actives.bgp_necro_bind";
		this.m.Name = "驱役亡灵";
		this.m.Description = "以意志锁住亡灵的魂火。你可以收回亲手复活的仆从，也可以趁敌方亡灵虚弱时将它收入棺椁，成为战团的亡灵宠物。";
		this.m.Icon = "skills/bgp_necro_bind_skill.png";
		this.m.IconDisabled = "skills/bgp_necro_bind_skill_sw.png";
		this.m.Overlay = "";
		this.m.SoundOnUse = [
			"sounds/enemies/necromancer_01.wav",
			"sounds/enemies/necromancer_02.wav",
			"sounds/enemies/necromancer_03.wav"
		];
		this.m.Type = ::Const.SkillType.Active;
		this.m.Order = ::Const.SkillOrder.UtilityTargeted;
		this.m.IsSerialized = false;
		this.m.IsActive = true;
		this.m.IsTargeted = true;
		this.m.IsTargetingActor = true;
		this.m.IsStacking = false;
		this.m.IsAttack = false;
		this.m.IsIgnoredAsAOO = true;
		this.m.ActionPointCost = 4;
		this.m.FatigueCost = 16;
		this.m.MinRange = 1;
		this.m.MaxRange = 6;
		this.m.AIBehaviorID = null;
	}

	function getEnemyHpThresholdPct( _user )
	{
		return ::Math.min(30, 5 + ::Math.floor(::BGP.Necro.getWill(_user) / 8.0));
	}

	function getTooltip()
	{
		local ret = this.skill.getDefaultUtilityTooltip();
		local user = this.getContainer().getActor();
		local pct = this.getEnemyHpThresholdPct(user);
		local resolve = ::BGP.Necro.getResolve(user);
		ret.extend([
			{ id = 10, type = "text", icon = "ui/icons/special.png", text = "目标为 " + ::MSU.Text.colorPositive("6") + " 格内仍在场的单位：你亲手复活的友军不限生命值；敌方亡灵须尚未死亡，且当前生命不高于最大生命的 " + ::MSU.Text.colorPositive(pct + "%") + "（5% + ⌊(当前决心 " + resolve + " − 20) / 8⌋%，上限 30%）。目标须有对应的亡灵宠物类型" },
			{ id = 11, type = "text", icon = "ui/icons/special.png", text = "只能在饰品栏空着时使用，收服后直接装备（本场不能再放出）；属性、名字、伤势沿用这个单位" },
			{ id = 12, type = "text", icon = "ui/icons/special.png", text = "之后和其他饰品栏的宠物一样放出、收回、升级，升级时从亡灵特质池抽特质，11 级得到死灵契约" },
			{ id = 13, type = "text", icon = "ui/icons/special.png", text = "记住它现在的武器和护甲：每次放出都是满耐久的同款，不会掉落；原来那套随它一起消失" }
		]);
		if (!this.hasDestination(user))
			ret.push({ id = 20, type = "text", icon = "ui/icons/warning.png", text = ::MSU.Text.colorNegative("饰品栏已被占用") });
		return ret;
	}

	function hasDestination( _user )
	{
		try
		{
			// 1.6.4 普通亡灵法师只能收进空着的饰品栏；亡灵主宰的导师另有规则（pale_sovereign/hooks.nut）
			return _user.getItems().getItemAtSlot(::Const.ItemSlot.Accessory) == null;
		}
		catch (e)
		{
		}
		return false;
	}

	function isUsable()
	{
		return this.skill.isUsable() && this.hasDestination(this.getContainer().getActor());
	}

	function onVerifyTarget( _originTile, _targetTile )
	{
		if (!_targetTile.IsOccupiedByActor)
			return false;
		if (!this.skill.onVerifyTarget(_originTile, _targetTile))
			return false;
		return this.canCommand(this.getContainer().getActor(), _targetTile.getEntity());
	}

	function canCommand( user, target )
	{
		if (target == null || !target.isAlive() || target.isDying() || target.getHitpoints() <= 0 || target.getID() == user.getID())
			return false;
		if (target.isAlliedWith(user))
		{
			local master = ::BGP.Necro.getMaster(target);
			if (master == null || master.getID() != user.getID())
				return false;
		}
		else
		{
			local pct = this.getEnemyHpThresholdPct(user);
			if (!target.getFlags().has("undead") || target.getHitpoints() * 100 > target.getHitpointsMax() * pct)
				return false;
		}
		try
		{
			if (target.m.Item != null)
				return false;
		}
		catch (e)
		{
		}
		return ::BGP.NecroPet.getTypeForEntity(target, false) != null;
	}

	function onUse( _user, _targetTile )
	{
		if (!_targetTile.IsOccupiedByActor || !this.hasDestination(_user) || !this.onVerifyTarget(_user.getTile(), _targetTile))
			return false;
		local target = _targetTile.getEntity();
		local type = ::BGP.NecroPet.getTypeForEntity(target, false);
		if (type == null)
			return false;
		try
		{
			local item = ::new("scripts/items/accessory/wardog_item");
			item.setType(type);
			::BGP.NecroPet.fillFromEntity(item, target);

			local equipped = false;
			if (_user.getItems().getItemAtSlot(::Const.ItemSlot.Accessory) == null)
			{
				_user.getItems().equip(item);
				if (_user.getItems().getItemAtSlot(::Const.ItemSlot.Accessory) != item)
					return false;
				equipped = true;
				local unleash = _user.getSkills().getSkillByID("actives.unleash_companion");
				if (unleash != null)
				{
					unleash.m.IsUsed = true;
					unleash.m.IsHidden = unleash.isUsed();
				}
			}
			else
			{
				if (!::World.Assets.getStash().hasEmptySlot()) return false;
				::World.Assets.getStash().add(item);
			}

			if (!_user.isHiddenToPlayer())
				::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(_user) + "把" + ::Const.UI.getColorizedEntityName(target) + "封进了棺椁" + (equipped ? "" : "（放进仓库）"));
			::BGP.NecroPet.removeEntity(target);
		}
		catch (e)
		{
			::logError("mod_bg_unique_perks: 驱役亡灵失败: " + e);
			return false;
		}
		return true;
	}
});

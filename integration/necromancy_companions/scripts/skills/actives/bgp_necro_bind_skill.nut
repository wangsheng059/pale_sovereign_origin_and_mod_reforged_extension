// 封魂入器（死灵精通，需要配件兄弟）：3 行动点、15 疲劳、6 格（1.5.1 起，原为相邻），把一个自己复活的单位封进配件（饰品）。
// 饰品栏空着就直接装备（同驯服，本场不能再放出），否则放进仓库；仓库满了不能用。
// 封进去的是配件兄弟宠物：属性取这个单位自己的，之后像宠物一样放出、收回、升级、抽特质池；
// 1.5.1 起记下它身上的武器和护甲，放出时生成满耐久的同款（不掉落）。
this.bgp_necro_bind_skill <- ::inherit("scripts/skills/skill", {
	m = {},
	function create()
	{
		this.m.ID = "actives.bgp_necro_bind";
		this.m.Name = "封魂入器";
		this.m.Description = "把一个由你复活的单位连同它的魂魄封进封魂匣，从此像宠物一样随战团同行。";
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
		this.m.ActionPointCost = 3;
		this.m.FatigueCost = 15;
		this.m.MinRange = 1;
		this.m.MaxRange = 6;
		this.m.AIBehaviorID = null;
	}

	function getTooltip()
	{
		local ret = this.skill.getDefaultUtilityTooltip();
		ret.extend([
			{ id = 10, type = "text", icon = "ui/icons/special.png", text = "目标为 " + ::MSU.Text.colorPositive("6") + " 格内、由你复活的单位（复活死者得到的僵尸，以及死灵法术复活的野兽、亡灵、兽人、地精）" },
			{ id = 11, type = "text", icon = "ui/icons/special.png", text = "饰品栏空着时直接装备（本场不能再放出），否则放进仓库；属性、名字、伤势沿用这个单位" },
			{ id = 12, type = "text", icon = "ui/icons/special.png", text = "之后和配件兄弟的宠物一样放出、收回、升级，升级时从亡灵特质池抽特质，11 级得到死灵契约" },
			{ id = 13, type = "text", icon = "ui/icons/special.png", text = "记住它现在的武器和护甲：每次放出都是满耐久的同款，不会掉落；原来那套随它一起消失" }
		]);
		local user = this.getContainer().getActor();
		if (!this.hasDestination(user))
			ret.push({ id = 20, type = "text", icon = "ui/icons/warning.png", text = ::MSU.Text.colorNegative("饰品栏和仓库都没有空位") });
		return ret;
	}

	function hasDestination( _user )
	{
		try
		{
			if (_user.getItems().getItemAtSlot(::Const.ItemSlot.Accessory) == null)
				return true;
			return ::World.Assets.getStash().hasEmptySlot();
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
		local target = _targetTile.getEntity();
		local user = this.getContainer().getActor();
		if (target.getID() == user.getID() || !target.isAlliedWith(user))
			return false;
		local master = ::BGP.Necro.getMaster(target);
		if (master == null || master.getID() != user.getID())
			return false;
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
				::World.Assets.getStash().add(item);
			}

			if (!_user.isHiddenToPlayer())
				::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(_user) + "把" + ::Const.UI.getColorizedEntityName(target) + "封进了封魂匣" + (equipped ? "" : "（放进仓库）"));
			::BGP.NecroPet.removeEntity(target);
		}
		catch (e)
		{
			::logError("mod_bg_unique_perks: 封魂入器失败: " + e);
			return false;
		}
		return true;
	}
});

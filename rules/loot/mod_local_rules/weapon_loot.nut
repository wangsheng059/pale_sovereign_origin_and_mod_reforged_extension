// Enemy equipment guaranteed drop & broken named/legendary weapon/shield preservation (Modern Hooks + MSU toggles).
foreach (scenarioScript in [
	"scripts/scenarios/world/starting_scenario",
	"scripts/scenarios/world/raiders_scenario"
])
{
	::BGP.HooksMod.hook(scenarioScript, function(q)
	{
		q.isDroppedAsLoot = @(__original) function( _item )
		{
			if (_item != null
				&& (_item.isItemType(::Const.Items.ItemType.Named) || _item.isItemType(::Const.Items.ItemType.Legendary))
				&& (_item.isItemType(::Const.Items.ItemType.Weapon) || _item.isItemType(::Const.Items.ItemType.Shield))
				&& _item.getCondition() <= 0)
			{
				return ::BGP.getSetting("BGP_SaveBrokenNamed", true);
			}
			if (::BGP.getSetting("BGP_ForceEnemyLoot", true))
				return true;
			return __original(_item);
		};
	});
}

::BGP.HooksMod.hook("scripts/items/shields/shield", function(q)
{
	q.isDroppedAsLoot = @(__original) function()
	{
		if (this.isItemType(::Const.Items.ItemType.Legendary) || this.isItemType(::Const.Items.ItemType.Named))
		{
			if (this.m.Condition <= 0)
				return ::BGP.getSetting("BGP_SaveBrokenNamed", true) && this.item.isDroppedAsLoot();
			if (::BGP.getSetting("BGP_SaveBrokenNamed", true))
				return this.item.isDroppedAsLoot();
		}
		return __original();
	};

	q.applyShieldDamage = @(__original) function( _damage, _playHitSound = true )
	{
		if (!::BGP.getSetting("BGP_SaveBrokenNamed", true))
			return __original(_damage, _playHitSound);

		local isSpecial = this.isItemType(::Const.Items.ItemType.Legendary) || this.isItemType(::Const.Items.ItemType.Named);
		local holder = this.getContainer();
		if (!isSpecial || this.m.Condition <= 0 || holder == null || ::MSU.isNull(holder))
			return __original(_damage, _playHitSound);

		local actor = holder.getActor();
		local tile = (actor != null && !::MSU.isNull(actor) && actor.isPlacedOnMap()) ? actor.getTile() : null;
		local isPlayer = this.m.LastEquippedByFaction == ::Const.Faction.Player
			|| (actor != null && !::MSU.isNull(actor) && ::MSU.isKindOf(actor, "player"));

		local ret = __original(_damage, _playHitSound);

		if (this.m.Condition <= 0 && tile != null)
		{
			local dropsAnyway = isPlayer && !::Tactical.State.isScenarioMode() && ::World.Assets.m.IsBlacksmithed;
			if (!dropsAnyway)
			{
				this.drop(tile);
				if (tile.Items.find(this) == null)
				{
					tile.Items.push(this);
					tile.IsContainingItems = true;
					this.m.Tile = tile;
				}
			}
		}
		return ret;
	};
});

::BGP.HooksMod.hook("scripts/items/weapons/weapon", function(q)
{
	q.isDroppedAsLoot = @(__original) function()
	{
		if (this.isItemType(::Const.Items.ItemType.Legendary) || this.isItemType(::Const.Items.ItemType.Named))
		{
			if (this.m.Condition <= 0)
				return ::BGP.getSetting("BGP_SaveBrokenNamed", true) && this.item.isDroppedAsLoot();
			if (::BGP.getSetting("BGP_SaveBrokenNamed", true))
				return this.item.isDroppedAsLoot();
		}
		return __original();
	};

	q.lowerCondition = @(__original) function( _value = this.Const.Combat.WeaponDurabilityLossOnHit )
	{
		if (!::BGP.getSetting("BGP_SaveBrokenNamed", true))
			return __original(_value);

		local special = this.isItemType(::Const.Items.ItemType.Legendary) || this.isItemType(::Const.Items.ItemType.Named);
		if (!special || this.m.Condition - _value > 0)
			return __original(_value);

		local holder = this.getContainer();
		if (holder == null || ::MSU.isNull(holder))
			return __original(_value);

		local actor = holder.getActor();
		if (actor == null || ::MSU.isNull(actor) || !actor.isAlive() || !actor.isPlacedOnMap())
			return __original(_value);
		if (this.m.Condition <= 0.0)
			return;

		this.m.Condition = 0.0;
		local weapon = this;
		::Time.scheduleEvent(::TimeUnit.Virtual, 300, function(_tag)
		{
			if (!::MSU.isNull(actor) && actor.isAlive() && actor.isPlacedOnMap()
				&& !::MSU.isNull(weapon.getContainer()) && ::MSU.isEqual(weapon.getContainer(), holder)
				&& weapon.m.Condition <= 0.0)
			{
				local t = actor.getTile();
				weapon.drop(t);
				if (t != null && t.Items.find(weapon) == null)
				{
					t.Items.push(weapon);
					t.IsContainingItems = true;
					weapon.m.Tile = t;
				}
			}
		}, null);

		if (actor.isHiddenToPlayer())
			return;

		::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(actor) + "的" + this.getName() + "损坏了！");
		local s = ::Const.Tactical.Settings;
		::Tactical.spawnIconEffect("status_effect_36", actor.getTile(), s.SkillIconOffsetX, s.SkillIconOffsetY,
			s.SkillIconScale, s.SkillIconFadeInDuration, s.SkillIconStayDuration, s.SkillIconFadeOutDuration, s.SkillIconMovement);
		::Sound.play(this.m.BreakingSound, 1.0, actor.getPos());
	};
});

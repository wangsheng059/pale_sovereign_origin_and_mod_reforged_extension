// 强制剥敌人甲 (zbigmap015) - wrapper rewrite.
//
// What the mod does (unchanged):
//   1. every item an enemy carries counts as loot, whatever the origin is;
//   2. a NAMED or LEGENDARY shield that gets destroyed is dropped on the ground instead of vanishing;
//   3. a NAMED or LEGENDARY weapon that breaks is dropped on the ground instead of vanishing.
//
// What changed: the old version replaced shield.applyShieldDamage() and
// weapon.lowerCondition() with full copies of the vanilla code, which threw
// away whatever the game or other mods (Reforged, MSU, ...) do in those
// functions. This version calls the original function and only adds the drop.

::mods_hookBaseClass("scenarios/world/starting_scenario", function(o)
{
	o.isDroppedAsLoot <- function( _item )
	{
		return true;
	}
});

::mods_hookBaseClass("scenarios/world/raiders_scenario", function(o)
{
	o.isDroppedAsLoot <- function( _item )
	{
		return true;
	}
});

::mods_hookExactClass("items/shields/shield", function(o)
{
	local applyShieldDamage = o.applyShieldDamage;
	o.applyShieldDamage = function( _damage, _playHitSound = true )
	{
		local isSpecial = this.isItemType(this.Const.Items.ItemType.Legendary) || this.isItemType(this.Const.Items.ItemType.Named);

		if (!isSpecial || this.m.Condition == 0 || this.getContainer() == null)
		{
			return applyShieldDamage(_damage, _playHitSound);
		}

		// Remember the bearer before the game unequips a destroyed shield.
		local actor = this.getContainer().getActor();
		local ret = applyShieldDamage(_damage, _playHitSound);

		if (this.m.Condition == 0)
		{
			// The game drops the shield by itself for a player with the
			// blacksmith retinue; in every other case we drop it here.
			local isPlayer = this.m.LastEquippedByFaction == this.Const.Faction.Player || actor != null && !actor.isNull() && this.isKindOf(actor.get(), "player");
			local dropsAnyway = isPlayer && !this.Tactical.State.isScenarioMode() && this.World.Assets.m.IsBlacksmithed;

			if (!dropsAnyway)
			{
				this.drop(actor.getTile());
			}
		}

		return ret;
	}
});

::mods_hookExactClass("items/weapons/weapon", function(o)
{
	local lowerCondition = o.lowerCondition;
	o.lowerCondition = function( _value = this.Const.Combat.WeaponDurabilityLossOnHit )
	{
		local isSpecial = this.isItemType(this.Const.Items.ItemType.Legendary) || this.isItemType(this.Const.Items.ItemType.Named);

		// Ordinary weapons, and special ones that survive this hit: untouched.
		if (!isSpecial || this.m.Condition - _value > 0)
		{
			return lowerCondition(_value);
		}

		// A named / legendary weapon breaks right now: same feedback as the
		// game, but the weapon falls to the ground instead of being removed.
		local actor = this.getContainer().getActor();
		this.m.Condition = 0.0;

		if (!actor.isHiddenToPlayer())
		{
			this.Tactical.EventLog.log(this.Const.UI.getColorizedEntityName(actor) + "\'s " + this.getName() + " has broken!");
			this.Tactical.spawnIconEffect("status_effect_36", actor.getTile(), this.Const.Tactical.Settings.SkillIconOffsetX, this.Const.Tactical.Settings.SkillIconOffsetY, this.Const.Tactical.Settings.SkillIconScale, this.Const.Tactical.Settings.SkillIconFadeInDuration, this.Const.Tactical.Settings.SkillIconStayDuration, this.Const.Tactical.Settings.SkillIconFadeOutDuration, this.Const.Tactical.Settings.SkillIconMovement);
			this.Sound.play(this.m.BreakingSound, 1.0, actor.getPos());
			this.Time.scheduleEvent(this.TimeUnit.Virtual, 300, this.drop, null);
		}
	}
});

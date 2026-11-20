// 强制剥敌人甲 (zbigmap015) - wrapper rewrite.
//
// What the mod does (unchanged):
//   1. every item an enemy carries counts as loot, whatever the origin is;
//   2. a NAMED or LEGENDARY shield that gets destroyed is dropped on the ground instead of vanishing;
// Weapon recovery is handled separately by the local rules entry point.
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


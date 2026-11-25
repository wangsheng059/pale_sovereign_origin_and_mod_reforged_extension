// Actor combat hooks for Career Stats (real HP damage + fatal DOT detection) and WeaponKills.
// Removed the fragile per-hit Skills.add monkey-patch from original mod_Legacy.

::CareerStats.MH.hook("scripts/entity/tactical/actor", function(q)
{
	q.kill = @(__original) function( _killer = null, _skill = null, _fatalityType = ::Const.FatalityType.None, _silent = false )
	{
		if (_killer != null) this.career_killer <- ::MSU.asWeakTableRef(_killer);
		return __original(_killer, _skill, _fatalityType, _silent);
	};

	q.onDeath = @(__original) function( _killer, _skill, _tile, _fatalityType )
	{
		local killer = ("career_killer" in this && this.career_killer.isAlive()) ? this.career_killer.get() : _killer;

		// Capture fatal DOT cause before status effects are cleared during original onDeath.
		if ("CareerStats_Stats" in this.m)
		{
			try
			{
				local cause = ::CareerStats.detectFatalCause(this, _skill, _fatalityType);
				if (cause != null) this.m.CareerStats_FatalCause <- cause;
			}
			catch (e) {}
		}

		// Forward kill to WeaponKills tracker.
		if ("WeaponKills" in ::getroottable())
		{
			try { ::WeaponKills.onKill(killer, _skill); }
			catch (e) { ::logWarning("WeaponKills.onKill error: " + e); }
		}

		return __original(_killer, _skill, _tile, _fatalityType);
	};

	q.onDamageReceived = @(__original) function( _attacker, _skill, _hitInfo )
	{
		local oldBodyArmor = this.getArmor(::Const.BodyPart.Body);
		local oldHeadArmor = this.getArmor(::Const.BodyPart.Head);
		local shield = null;
		try { shield = this.getItems().getItemAtSlot(::Const.ItemSlot.Offhand); } catch (e) {}
		local oldShieldCond = (shield != null && shield.isItemType(::Const.Items.ItemType.Shield)) ? shield.getCondition() : 0;
		local oldHitpoints = this.getHitpoints();

		local damage = __original(_attacker, _skill, _hitInfo);

		// Record actual HP removed (no overkill).
		try
		{
			local realHp = oldHitpoints - this.getHitpoints();
			if (realHp > 0)
			{
				if (_attacker != null && ("CareerStats_Stats" in _attacker.m) && _attacker.m.CareerStats_Stats != null)
					_attacker.m.CareerStats_Stats.m.Stats.DamageDealtHitpoints += realHp;
				if (("CareerStats_Stats" in this.m) && this.m.CareerStats_Stats != null)
					this.m.CareerStats_Stats.m.Stats.DamageReceivedHitpoints += realHp;
			}
		}
		catch (e) {}

		// Forward armor/helmet/shield absorption to WeaponKills tracker.
		if ("WeaponKills" in ::getroottable())
		{
			try { ::WeaponKills.onDamageReceived(this, oldBodyArmor, oldHeadArmor, oldShieldCond); }
			catch (e) {}
		}

		return damage;
	};
});

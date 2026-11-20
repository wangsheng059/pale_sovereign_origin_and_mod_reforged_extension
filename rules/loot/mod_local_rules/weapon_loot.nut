// Broken named and legendary weapons remain recoverable from the ground.
::BGP.HooksMod.hook("scripts/items/weapons/weapon", function(q)
{
	q.lowerCondition = @(__original) function( _value = this.Const.Combat.WeaponDurabilityLossOnHit )
	{
		local special = this.isItemType(::Const.Items.ItemType.Legendary) || this.isItemType(::Const.Items.ItemType.Named);
		if (!special || this.m.Condition - _value > 0)
			return __original(_value);

		local holder = this.getContainer();
		local actor = holder == null ? null : holder.getActor();
		if (actor == null || ::MSU.isNull(actor) || !actor.isAlive() || !actor.isPlacedOnMap())
			return __original(_value);
		if (this.m.Condition <= 0.0)
			return;

		this.m.Condition = 0.0;
		local weapon = this;
		::Time.scheduleEvent(::TimeUnit.Virtual, 300, function(_tag)
		{
			// Death or another effect may already have removed the weapon.
			if (!::MSU.isNull(actor) && actor.isAlive() && actor.isPlacedOnMap()
				&& ::MSU.isEqual(weapon.getContainer(), holder) && weapon.m.Condition <= 0.0)
				weapon.drop(actor.getTile());
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

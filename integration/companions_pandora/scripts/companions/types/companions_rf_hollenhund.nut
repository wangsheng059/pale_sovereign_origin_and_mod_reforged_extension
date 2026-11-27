// 配件兄弟版地狱犬：沿用重铸地狱犬的外观、技能（幽灵/骷髅种族、灵体啃咬、灵雾）和 AI，
// 补上配件兄弟宠物需要的接口（物品、名字、外观、等级缩放、阵亡收回、击杀经验）。
this.companions_rf_hollenhund <- this.inherit("scripts/entity/tactical/enemies/rf_hollenhund", {
	m = {
		Item = null,
		Name = "地狱犬"
	},
	function create()
	{
		this.rf_hollenhund.create();
		this.m.Name = "地狱犬";
	}

	function setItem( _i )
	{
		if (typeof _i == "instance")
			this.m.Item = _i;
		else
			this.m.Item = this.WeakTableRef(_i);
	}

	function setName( _n )
	{
		this.m.Name = _n;
	}

	function getName()
	{
		return this.m.Name;
	}

	function setVariant( _v )
	{
		this.m.Variant = _v;
		local brush = "bust_rf_hollenhund_0" + _v;
		this.m.Items.getAppearance().Body = brush;
		this.getSprite("body").setBrush(brush);
		this.getSprite("blur_1").setBrush(brush);
		this.getSprite("head").setBrush(brush);
		this.setDirty(true);
	}

	function onFactionChanged()
	{
		this.rf_hollenhund.onFactionChanged();

		if (!this.Tactical.State.isScenarioMode())
		{
			local f = this.World.FactionManager.getFaction(this.getFaction());
			if (f != null)
				this.getSprite("socket").setBrush(f.getTacticalBase());
		}
		else
		{
			this.getSprite("socket").setBrush(this.Const.FactionBase[this.getFaction()]);
		}
	}

	function onDeath( _killer, _skill, _tile, _fatalityType )
	{
		if (this.m.Item != null && !this.m.Item.isNull())
		{
			local item = this.m.Item.get();
			try { item.setEntity(null); } catch (e) {}

			local c = null;
			try { c = item.getContainer(); } catch (e) {}
			if (c != null && !::MSU.isNull(c))
			{
				try
				{
					if (item.getCurrentSlotType() == this.Const.ItemSlot.Bag)
						c.removeFromBag(item);
					else
						c.unequip(item);
				}
				catch (e)
				{
					try { c.remove(item); } catch (e2) {}
				}
			}

			this.m.Item = null;
		}

		this.rf_hollenhund.onDeath(_killer, _skill, _tile, _fatalityType);
	}

	function onActorKilled( _actor, _tile, _skill )
	{
		this.actor.onActorKilled(_actor, _tile, _skill);

		if (this.getFaction() == this.Const.Faction.Player || this.getFaction() == this.Const.Faction.PlayerAnimals)
		{
			local XPgroup = _actor.getXPValue();
			local brothers = this.Tactical.Entities.getInstancesOfFaction(this.Const.Faction.Player);

			foreach (bro in brothers)
			{
				bro.addXP(this.Math.max(1, this.Math.floor(XPgroup / brothers.len())));

				local acc = bro.getItems().getItemAtSlot(this.Const.ItemSlot.Accessory);
				if (acc != null && "setType" in acc)
				{
					if (acc.getType() != null)
						acc.addXP(this.Math.max(1, this.Math.floor(XPgroup / brothers.len())));
				}
			}
		}
	}

	function applyCompanionScaling()
	{
		local d = ::Const.Tactical.Actor.RF_Hollenhund;
		local a = this.m.Item.m.Attributes;
		local b = this.m.BaseProperties;
		b.setValues({
			ActionPoints = d.ActionPoints,
			Hitpoints = a.Hitpoints,
			Stamina = a.Stamina,
			Bravery = a.Bravery,
			Initiative = a.Initiative,
			MeleeSkill = a.MeleeSkill,
			RangedSkill = a.RangedSkill,
			MeleeDefense = a.MeleeDefense,
			RangedDefense = a.RangedDefense,
			Armor = [d.Armor[0], d.Armor[1]],
			FatigueEffectMult = d.FatigueEffectMult,
			MoraleEffectMult = d.MoraleEffectMult,
			FatigueRecoveryRate = 20
		});
		b.Reach = ::Reforged.Reach.Default.BeastMedium;
		this.m.CurrentProperties = clone b;
		this.m.Hitpoints = b.Hitpoints;

		foreach (quirk in this.m.Item.m.Quirks)
			this.m.Skills.add(this.new(quirk));

		::AC_PH_Compat.addQuirkBehaviors(this);
	}
});

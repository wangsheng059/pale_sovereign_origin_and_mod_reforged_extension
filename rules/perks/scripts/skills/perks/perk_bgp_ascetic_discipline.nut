this.perk_bgp_ascetic_discipline <- ::inherit("scripts/skills/skill", {
	m = {
		MeleeDefense = 5,
		Initiative = 10,
		BraveryToInitiative = 0.25
	},
	function create()
	{
		this.m.ID = "perk.bgp_ascetic_discipline";
		this.m.Name = ::BGP.PerkNames.AsceticDiscipline;
		this.m.Description = ::BGP.PerkDescriptions.AsceticDiscipline;
		this.m.Icon = "ui/perks/perk_bgp_ascetic_discipline.png";
		this.m.Type = ::Const.SkillType.Perk;
		this.m.Order = ::Const.SkillOrder.Perk;
	}

	// 穿着护甲，且头盔和身甲都不是著名 / 传奇
	function isWearingPlainArmor()
	{
		local items = this.getContainer().getActor().getItems();
		local wearing = false;
		foreach (slot in [::Const.ItemSlot.Head, ::Const.ItemSlot.Body])
		{
			local item = items.getItemAtSlot(slot);
			if (item == null)
				continue;
			wearing = true;
			if (item.isItemType(::Const.Items.ItemType.Named) || item.isItemType(::Const.Items.ItemType.Legendary))
				return false;
		}
		return wearing;
	}

	function onUpdate( _properties )
	{
		if (this.isWearingPlainArmor())
		{
			_properties.MeleeDefense += this.m.MeleeDefense;
			_properties.Initiative += this.m.Initiative;
		}
	}

	function onAfterUpdate( _properties )
	{
		_properties.Initiative += ::Math.floor(_properties.getBravery() * this.m.BraveryToInitiative);
	}
});

// Mind Meld: raised/pet/guard undead copy selected passive perks; the caster gains 10% of all 8 attributes of their equipped accessory undead pet.
this.perk_bgp_necro_mind_meld <- ::inherit("scripts/skills/skill", {
	m = {
		PetBonus = null
	},
	function create()
	{
		this.m.ID = "perk.bgp_necro_mind_meld";
		this.m.Name = ::BGP.PerkNames.NecroMindMeld;
		this.m.Description = ::BGP.PerkDescriptions.NecroMindMeld;
		this.m.Icon = "ui/perks/perk_bgp_necro_mind_meld.png";
		this.m.Type = ::Const.SkillType.Perk;
		this.m.Order = ::Const.SkillOrder.Perk;
	}

	function getEquippedUndeadPet()
	{
		try
		{
			local container = this.getContainer();
			if (container == null)
				return null;
			local actor = container.getActor();
			if (actor == null || ::MSU.isNull(actor))
				return null;
			local items = actor.getItems();
			if (items == null)
				return null;
			local acc = items.getItemAtSlot(::Const.ItemSlot.Accessory);
			if (acc == null || !("NecroPet" in ::BGP) || !::BGP.NecroPet.isOwnItem(acc))
				return null;
			if (!("Attributes" in acc.m) || acc.m.Attributes == null)
				return null;
			return acc;
		}
		catch (e)
		{
			return null;
		}
	}

	function onUpdate( _properties )
	{
		this.m.PetBonus = null;
		local pet = this.getEquippedUndeadPet();
		if (pet == null)
			return;
		try
		{
			local a = pet.m.Attributes;
			local bonus = {};
			foreach (key in ["Hitpoints", "Stamina", "Bravery", "Initiative", "MeleeSkill", "RangedSkill", "MeleeDefense", "RangedDefense"])
			{
				local gain = ::Math.max(0, ::Math.floor(a[key] * 0.1));
				bonus[key] <- gain;
				_properties[key] += gain;
			}
			this.m.PetBonus = bonus;
		}
		catch (e)
		{
			this.m.PetBonus = null;
		}
	}
});

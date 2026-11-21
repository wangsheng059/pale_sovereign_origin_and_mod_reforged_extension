local S = ::PaleSovereign;

S.Attributes <- ["Hitpoints", "Stamina", "Bravery", "Initiative", "MeleeSkill", "RangedSkill", "MeleeDefense", "RangedDefense"];
S.WeaponFields <- ["RegularDamage", "RegularDamageMax", "DirectDamageMult", "ArmorDamageMult", "StaminaModifier", "ConditionMax", "ChanceToHitHead", "ShieldDamage", "FatigueOnSkillUse", "AdditionalAccuracy", "Variant"];
S.PetTag <- "\npale_id=";

S.isCoffin <- function( _item )
{
    if (!::BGP.NecroPet.isOwnItem(_item))
        return false;
    return ::BGP.NecroPet.TypeDefs[_item.getType()].Category == "undead";
};

S.petID <- function( _item )
{
    if (_item.m.PaleID == 0)
    {
        _item.m.PaleID = this.get("NextPetID") + 1;
        this.set("NextPetID", _item.m.PaleID);
    }
    return _item.m.PaleID;
};

S.petKey <- function( _id, _key )
{
    return "Pet." + _id + "." + _key;
};

S.petGet <- function( _item, _key )
{
    return this.get(this.petKey(_item.m.PaleID, _key));
};

S.petSet <- function( _item, _key, _value )
{
    this.set(this.petKey(this.petID(_item), _key), _value);
};

S.mainPet <- function()
{
    local chief = this.chief();
    if (chief == null)
        return null;
    local item = chief.getItems().getItemAtSlot(::Const.ItemSlot.Accessory);
    return this.isCoffin(item) ? item : null;
};

S.reservePet <- function()
{
    local id = this.get("ReservePetID");
    if (id == 0)
        return null;
    foreach (item in ::World.Assets.getStash().getItems())
        if (this.isCoffin(item) && item.m.PaleID == id)
            return item;
    return null;
};

S.isDeployed <- function( _pet, _actor = null )
{
    if (_pet == null)
        return false;
    local entity = _pet.m.Entity;
    return entity != null && !::MSU.isNull(entity) && entity.isAlive() && !entity.isDying() && entity.isPlacedOnMap()
        && (_actor == null || entity.getID() == _actor.getID());
};

S.makeGuard <- function( _starting )
{
    local type = ::BGP.NecroPet.getTypeForScript("scripts/entity/tactical/enemies/skeleton_light", true);
    local pet = ::new(this.ItemDir + "accessory/wardog_item");
    pet.setType(type);
    pet.m.Name = _starting ? "残破的墓穴守卫" : "墓穴守卫";
    pet.m.BGP_Gear = "S:scripts/items/weapons/militia_spear;S:scripts/items/shields/wooden_shield";
    if (_starting)
        pet.m.Wounds = 25;
    this.petID(pet);
    if (_starting)
        this.set("StarterID", pet.m.PaleID);
    pet.updateCompanion();
    return pet;
};

S.isElite <- function( _actor )
{
    local script = ::IO.scriptFilenameByHash(_actor.ClassNameHash);
    if (script == null || !this.isTameEliteScript(script))
        return false;
    return _actor.getFlags().has("undead");
};

S.isTameEliteScript <- function( _script )
{
    return _script.find("skeleton_heavy_elite") != null || _script.find("skeleton_medium_elite") != null
        || _script.find("zombie_hero") != null || _script.find("zombie_knight") != null
        || _script.find("vampire") != null;
};

S.soulSpecies <- function( _script )
{
    if (_script.find("vampire") != null)
        return 3;
    if (_script.find("zombie") != null)
        return 2;
    return 1;
};

S.canMarkEnemy <- function( _actor )
{
    return this.isElite(_actor) && _actor.getHitpoints() * 100 <= _actor.getHitpointsMax() * 35;
};

S.canMarkSoul <- function()
{
    return this.Battle != null && this.Battle.Mark == null && this.get("PendingSoul") == 0
        && this.countItems("misc.pale_chain") > 0 && this.isDeployed(this.mainPet());
};

S.markSoul <- function( _target )
{
    if (!this.canMarkSoul() || !this.canMarkEnemy(_target))
        return false;
    local script = ::IO.scriptFilenameByHash(_target.ClassNameHash);
    local kind = this.soulSpecies(script);
    local weapon = _target.getItems().getItemAtSlot(::Const.ItemSlot.Mainhand);
    local named = null;
    if (weapon != null && weapon.isItemType(::Const.Items.ItemType.Named | ::Const.Items.ItemType.Weapon)
        && weapon.isItemType(::Const.Items.ItemType.Named))
    {
        named = { Script = ::IO.scriptFilenameByHash(weapon.ClassNameHash), Name = weapon.getName(), Fields = {} };
        foreach (key in this.WeaponFields)
        {
            try { named.Fields[key] <- weapon.m[key]; } catch (e) {}
        }
    }
    this.Battle.Mark = {
        Target = _target.getID(), Name = _target.getName(), Species = kind,
        PetID = this.petID(this.mainPet()), Named = named,
        Champion = _target.getSkills().hasSkill("racial.champion")
    };
    ::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(_target) + "已被缚魂锁链标记。");
    return true;
};

S.saveSoul <- function( _mark )
{
    this.set("PendingSoul", _mark.PetID);
    this.set("SoulName", _mark.Name);
    this.set("SoulSpecies", _mark.Species);
    this.set("SoulChampion", _mark.Champion ? 1 : 0);
    this.set("Soul.Weapon", _mark.Named == null ? "" : _mark.Named.Script);
    if (_mark.Named != null)
    {
        this.set("Soul.WeaponName", _mark.Named.Name);
        foreach (key in this.WeaponFields)
        {
            this.set("Soul.WeaponSet." + key, key in _mark.Named.Fields ? 1 : 0);
            if (key in _mark.Named.Fields)
                this.set("Soul.Weapon." + key, _mark.Named.Fields[key]);
        }
    }
};

S.canUseSoul <- function()
{
    local pet = this.mainPet();
    return pet != null && this.get("PendingSoul") > 0 && pet.m.PaleID == this.get("PendingSoul") && this.countItems("misc.pale_chain") > 0;
};

S.resolveSoul <- function( _choice )
{
    if (!this.canUseSoul())
        return false;
    local pet = this.mainPet();
    if (_choice == "soul" && this.petGet(pet, "Devours") >= 3)
        return false;
    if (_choice == "body")
    {
        local stats = clone this.Attributes;
        for (local i = 0; i < 3; ++i)
        {
            local index = ::Math.rand(0, stats.len() - 1);
            ++pet.m.Attributes[stats.remove(index)];
        }
    }
    else if (_choice == "soul")
    {
        local species = this.get("SoulSpecies");
        this.petSet(pet, "Species." + species, 1);
        this.petSet(pet, "Devours", this.petGet(pet, "Devours") + 1);
    }
    else if (_choice == "inherit")
    {
        if (this.get("SoulChampion") != 0)
            this.petSet(pet, "ChampionRacial", 1);
        local script = ::World.Flags.get("Pale.Soul.Weapon");
        if (script != null && script != "")
        {
            this.petSet(pet, "Weapon", script);
            this.petSet(pet, "WeaponName", ::World.Flags.get("Pale.Soul.WeaponName"));
            foreach (key in this.WeaponFields)
            {
                this.petSet(pet, "WeaponSet." + key, this.get("Soul.WeaponSet." + key));
                if (this.get("Soul.WeaponSet." + key) != 0)
                    this.petSet(pet, "Weapon." + key, ::World.Flags.get("Pale.Soul.Weapon." + key));
            }
        }
    }
    else
    {
        return false;
    }
    this.removeMaterial("chain");
    this.set("PendingSoul", 0);
    pet.updateCompanion();
    return true;
};

S.applyPetProgress <- function( _pet, _entity )
{
    if (_pet.m.PaleID == 0)
        return;
    local id = _pet.m.PaleID;
    local flags = ::World.Flags;
    local prefix = "Pale." + this.petKey(id, "");
    local weaponPath = flags.get(prefix + "Weapon");
    if (weaponPath != null && weaponPath != "")
    {
        local weapon = ::new(weaponPath);
        weapon.m.PaleReplica <- true;
        weapon.m.Name = flags.get(prefix + "WeaponName");
        foreach (key in this.WeaponFields)
        {
            if (flags.getAsInt(prefix + "WeaponSet." + key) == 0)
                continue;
            local datum = flags.get(prefix + "Weapon." + key);
            if (key == "DirectDamageMult" || key == "ArmorDamageMult" || key == "ConditionMax")
                datum = flags.getAsFloat(prefix + "Weapon." + key);
            else
                datum = flags.getAsInt(prefix + "Weapon." + key);
            weapon.m[key] = datum;
        }
        weapon.setCondition(weapon.getConditionMax());
        weapon.m.IsDroppedAsLoot = false;
        local items = _entity.getItems();
        local old = items.getItemAtSlot(::Const.ItemSlot.Mainhand);
        local shield = items.getItemAtSlot(::Const.ItemSlot.Offhand);
        if (old != null)
            items.unequip(old);
        if (shield != null && weapon.isItemType(::Const.Items.ItemType.TwoHanded))
            items.unequip(shield);
        items.equip(weapon);
    }

    local skills = _entity.getSkills();
    if (this.petGet(_pet, "ChampionRacial") != 0 && !skills.hasSkill("racial.champion"))
        skills.add(::new(this.SkillDir + "racial/champion_racial"));
    foreach (species in [1, 2, 3, 4])
    {
        if (this.petGet(_pet, "Species." + species) == 0)
            continue;
        local trait = ::new(this.SkillDir + "effects/pale_pet_trait");
        trait.configure(species);
        skills.add(trait);
    }
    if (this.petGet(_pet, "Mastery") != 0)
    {
        local weapon = _entity.getItems().getItemAtSlot(::Const.ItemSlot.Mainhand);
        local mastery = weapon == null ? null : ::BGP.NecroPet.getMasteryFor(weapon);
        if (mastery != null)
        {
            local skill = ::new(mastery);
            if (!skills.hasSkill(skill.getID()))
                skills.add(skill);
        }
    }
    skills.update();
};

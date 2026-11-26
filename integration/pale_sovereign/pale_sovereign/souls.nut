local S = ::PaleSovereign;

S.Attributes <- ["Hitpoints", "Stamina", "Bravery", "Initiative", "MeleeSkill", "RangedSkill", "MeleeDefense", "RangedDefense"];
S.WeaponFields <- ["RegularDamage", "RegularDamageMax", "DirectDamageMult", "ArmorDamageMult", "StaminaModifier", "ConditionMax", "ChanceToHitHead", "ShieldDamage", "FatigueOnSkillUse", "AdditionalAccuracy", "Variant"];
S.PetTag <- "\npale_id=";

// 吞魂特质。编号存进存档（Pet.<id>.Species.<n>），只能往后追加，不能改顺序。
// Scripts 按脚本文件名精确匹配（不含路径）；4 号只由“第三面残旗”授予。
S.Souls <- [
    null,
    { Name = "荣誉卫队之魂", Icon = "skills/pale_honor", Desc = "昔日古帝国仪仗队至死未散的列阵本能。装备盾牌时，其近战防御和远程防御加成提高 25%。",
      Scripts = ["rf_skeleton_heavy_elite", "rf_skeleton_heavy_elite_bodyguard", "rf_skeleton_medium_elite", "rf_skeleton_medium_elite_polearm", "skeleton_heavy_bodyguard", "rf_skeleton_centurion", "rf_skeleton_decanus"] },
    { Name = "堕落英雄之魂", Icon = "skills/pale_fallen", Desc = "旧日悍将死后留下的蛮劲，挥起兵器又沉又狠。近战技能 +5，近战伤害 +10%。",
      Scripts = ["zombie_knight", "zombie_knight_bodyguard", "rf_zombie_hero", "rf_zombie_hero_bodyguard", "zombie_betrayer", "zombie_boss", "rf_draugr_hero", "rf_draugr_huskarl", "rf_draugr_huskarl_bodyguard"] },
    { Name = "血族之魂", Icon = "skills/pale_vampire", Desc = "暗夜猎手对鲜血的渴求渗进枯骨，见血就能续命。攻击造成生命伤害时，恢复相当于该生命伤害 25% 的生命。",
      Scripts = ["vampire", "vampire_low", "rf_vampire_lord"] },
    { Name = "护驾遗志", Icon = "skills/pale_banner", Desc = "哪怕身躯化作枯骨，它依然记得自己曾立在君王身前。每场战斗首次在导师身旁遭受敌方攻击时，生命与护甲伤害减半。",
      Scripts = [] },
    { Name = "军团统帅之魂", Icon = "skills/pale_soul_legate", Desc = "旧帝国军团长临阵的章法还在骨头里，进退都稳。近战技能 +5，近战防御 +5，决心 +10。",
      Scripts = ["rf_skeleton_legatus", "skeleton_boss"] },
    { Name = "古帝祭司之魂", Icon = "skills/pale_soul_priest", Desc = "古帝祭司与巫妖的失明禁咒仍烙在骨铭之中，落刃处总裹着阴寒咒雾。决心 +15；攻击命中后，目标陷入致盲（近战技能、远程技能 −15，持续到它的下一回合结束）。",
      Scripts = ["skeleton_priest", "skeleton_lich", "rf_draugr_shaman"] },
    { Name = "督军之魂", Icon = "skills/pale_soul_warlord", Desc = "绿皮督军砍翻敌阵后的狂躁战意未曾消散，每斩一人便迫不及待扑向下一个猎物。击杀敌人后，立刻恢复 3 点行动点数。",
      Scripts = ["orc_warlord", "orc_berserker", "rf_zombie_orc_warlord", "rf_zombie_orc_berserker"] },
    { Name = "天选者之魂", Icon = "skills/pale_soul_chosen", Desc = "北地天选战士越是重伤越是凶狠，枯骨开裂之时反而杀性大炽。生命低于 50% 时，近战伤害 +25%。",
      Scripts = ["barbarian_chosen", "barbarian_champion"] },
    { Name = "古龙之魂", Icon = "skills/pale_soul_lindwurm", Desc = "林德蠕龙沉重如山的庞然筋骨烙进了这具躯壳，任凭冲撞也难以撼动分毫。生命 +30，免疫击退与抓取。",
      Scripts = ["lindwurm"] },
    { Name = "巨魔之魂", Icon = "skills/pale_soul_unhold", Desc = "巨魔狂野不绝的再生本能附着于骨肉之间，崩裂的残躯总在悄然愈合。每回合开始时恢复 10% 最大生命。",
      Scripts = ["unhold", "unhold_frost", "unhold_bog", "unhold_armored", "unhold_frost_armored"] },
    { Name = "古树之魂", Icon = "skills/pale_soul_schrat", Desc = "古树人盘根错节的木质铁皮覆上骨铠，寻常矢石难伤其根本。受到的远程伤害 −25%，生命 +15。",
      Scripts = ["schrat"] },
    { Name = "梦魇之魂", Icon = "skills/pale_soul_alp", Desc = "梦魇与女巫游走于虚实之间的诡影绕身不散，让敌人的兵刃与箭矢屡屡落空。近战防御、远程防御 +7。",
      Scripts = ["alp", "hexe"] },
    { Name = "噬尸鬼之魂", Icon = "skills/pale_soul_ghoul", Desc = "噬尸鬼啖肉吞髓的贪婪本性寄生在魂火深处，每吞一具倒下的躯体便愈发饱满。击杀敌人后，恢复 20% 最大生命。",
      Scripts = ["ghoul_high"] },
    { Name = "剑圣之魂", Icon = "skills/pale_soul_swordmaster", Desc = "一代剑术宗师千锤百炼的步法与出剑节奏刻进了骨节，举刃便抢占先机。近战技能 +7，主动值 +10。",
      Scripts = ["swordmaster", "rf_fencer", "gladiator", "executioner", "desert_devil", "assassin", "desert_stalker"] },
    { Name = "骑士之魂", Icon = "skills/pale_soul_knight", Desc = "重甲骑士顶着刀林箭雨冲阵的沉稳定力犹存，面对近身搏杀从容不迫。近战防御 +5，受到的近战伤害 −10%。",
      Scripts = ["knight", "hedge_knight", "rf_knight_anointed", "rf_marshal"] },
    { Name = "狼王之魂", Icon = "skills/pale_soul_wolf", Desc = "狂暴兽王扑杀猎物时的凌厉迅捷融入了肢节，动若奔雷。主动值 +20，近战技能 +3。",
      Scripts = ["direwolf_high", "rf_hollenhund", "hyena_high"] },
    { Name = "上古神兽之魂", Icon = "skills/pale_soul_ancient", Desc = "上古巨兽的筋骨残意护住这具身躯，刀剑术法都难伤其根本。受到的所有伤害 −15%。",
      Scripts = ["trickster_god", "kraken"] }
];

S.scriptBase <- function( _script )
{
    if (_script == null)
        return "";
    local cut = 0;
    local at = _script.find("/");
    while (at != null)
    {
        cut = at + 1;
        at = _script.find("/", cut);
    }
    return _script.slice(cut);
};

S.isAscended <- function()
{
    return this.get("Ascended") == 1;
};

S.devourCap <- function( _pet )
{
    return 3 + (this.isAscended() && this.oath() == this.Oath.Champion ? 1 : 0);
};

S.markThreshold <- function()
{
    return (this.isAscended() && this.oath() == this.Oath.Champion ? 50 : 25) + (this.followerRank("wight_captain") >= 2 ? 5 : 0);
};

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
    // 1.6.7 开局护卫改用古代军团士兵模板，装备在第一次放出时按模板随机生成并记下
    local type = ::BGP.NecroPet.getTypeForScript("scripts/entity/tactical/enemies/" + (_starting ? "skeleton_medium" : "skeleton_light"), true);
    local pet = ::new(this.ItemDir + "accessory/wardog_item");
    pet.setType(type);
    pet.m.Name = _starting ? "残破的荒坟守卫" : "荒坟守卫";
    pet.m.BGP_Gear = _starting ? null : "S:scripts/items/weapons/militia_spear;S:scripts/items/shields/wooden_shield";
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
    if (_script == null)
        return 0;
    local fileName = this.scriptBase(_script);
    foreach (i, soul in this.Souls)
        if (soul != null && soul.Scripts.find(fileName) != null)
            return i;
    // 其他模组的同类精锐
    if (fileName.find("vampire") != null)
        return 3;
    if (fileName.find("zombie_hero") != null || fileName.find("zombie_knight") != null)
        return 2;
    if (fileName.find("skeleton_heavy_elite") != null || fileName.find("skeleton_medium_elite") != null)
        return 1;
    return 0;
};

S.canMarkEnemy <- function( _actor )
{
    if (_actor == null || !_actor.isAlive() || _actor.isDying())
        return false;
    local script = ::IO.scriptFilenameByHash(_actor.ClassNameHash);
    return this.soulSpecies(script) != 0 && _actor.getHitpoints() * 100 <= _actor.getHitpointsMax() * this.markThreshold();
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
    _target.getSkills().add(::new("scripts/skills/effects/pale_bound_soul_effect"));
    ::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(_target) + "已被黑铁缚魂锁链牢牢锚定。");
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

S.canDevour <- function( _pet )
{
    local species = this.get("SoulSpecies");
    return species > 0 && species < this.Souls.len() && this.petGet(_pet, "Devours") < this.devourCap(_pet)
        && this.petGet(_pet, "Species." + species) == 0;
};

// 1.7.5 承誓能继承的内容：冠军加成（冠军还没有时）和具名武器；都没有时不显示承誓选项，也不消耗锁链
S.inheritParts <- function( _pet )
{
    local parts = [];
    if (this.get("SoulChampion") != 0 && this.petGet(_pet, "ChampionRacial") == 0)
        parts.push("冠军加成");
    local script = ::World.Flags.get("Pale.Soul.Weapon");
    if (typeof script == "string" && script.len() > 0)
    {
        local text = "具名武器【" + ::World.Flags.get("Pale.Soul.WeaponName") + "】";
        local old = ::World.Flags.get("Pale." + this.petKey(_pet.m.PaleID, "WeaponName"));
        if (typeof old == "string" && old.len() > 0)
            text += "（替换现有的【" + old + "】）";
        parts.push(text);
    }
    return parts;
};

S.resolveSoul <- function( _choice )
{
    if (!this.canUseSoul())
        return false;
    if (_choice == "inherit" && this.inheritParts(this.mainPet()).len() == 0)
        return false;
    local pet = this.mainPet();
    if (_choice == "soul" && !this.canDevour(pet))
        return false;
    if (_choice == "body")
    {
        local gain = this.isAscended() && this.oath() == this.Oath.Champion ? 2 : 1;
        this.raiseRandomAttributes(pet.m.Attributes, 4, gain);
    }
    else if (_choice == "soul")
    {
        local species = this.get("SoulSpecies");
        this.petSet(pet, "Species." + species, 1);
        this.petSet(pet, "Devours", this.petGet(pet, "Devours") + 1);
    }
    else if (_choice == "inherit")
    {
        this.petSet(pet, "Inherited", 1);
        if (this.get("SoulChampion") != 0)
            this.petSet(pet, "ChampionRacial", 1);
        local script = ::World.Flags.get("Pale.Soul.Weapon");
        if (typeof script == "string" && script.len() > 0)
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
    this.set("SoulInfusions", this.get("SoulInfusions") + 1);
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
    if (typeof weaponPath == "string" && weaponPath.len() > 0)
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
    local maxBefore = _entity.getHitpointsMax();
    if (this.petGet(_pet, "ChampionRacial") != 0 && !skills.hasSkill("racial.champion"))
        skills.add(::new(this.SkillDir + "racial/champion_racial"));
    for (local species = 1; species < this.Souls.len(); ++species)
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
    local gain = _entity.getHitpointsMax() - maxBefore;
    if (gain > 0)
        _entity.setHitpoints(::Math.min(_entity.getHitpointsMax(), _entity.getHitpoints() + gain));
};

// 古代魂玉的冠军用途
// 1.6.32 尸妖王的基础属性改为固定值；守卫起步是死灵宠物的通用基础值（necro_ac_library.nut），
// 晋升时补上两者之差，之前的成长与淬骨保留
S.GuardBaseStats <- { Hitpoints = 60, Bravery = 50, Initiative = 80, MeleeSkill = 55, MeleeDefense = 5 };
S.LichStats <- { Hitpoints = 150, Bravery = 150, Initiative = 150, MeleeSkill = 80, MeleeDefense = 30 };
// 1.6.31 及以前的晋升加成，旧存档补差时扣掉
S.OldLichBonus <- { Hitpoints = 15, Bravery = 10, Initiative = 0, MeleeSkill = 5, MeleeDefense = 5 };

S.promoteGuard <- function( _pet )
{
    this.petSet(_pet, "Promoted", 1);
    this.petSet(_pet, "LichV2", 1);
    _pet.m.Name = "尸妖王";
    foreach (key, value in this.LichStats)
        _pet.m.Attributes[key] += value - this.GuardBaseStats[key];
    _pet.updateCompanion();
};

// 旧存档里已晋升的尸妖王补到新属性，只执行一次
S.upgradeLich <- function( _pet )
{
    if (_pet == null || _pet.m.PaleID == 0 || this.petGet(_pet, "Promoted") == 0 || this.petGet(_pet, "LichV2") != 0)
        return;
    this.petSet(_pet, "LichV2", 1);
    foreach (key, value in this.LichStats)
        _pet.m.Attributes[key] += value - this.GuardBaseStats[key] - this.OldLichBonus[key];
    _pet.updateCompanion();
};

S.isLich <- function( _pet )
{
    return _pet != null && _pet.m.PaleID != 0 && this.petGet(_pet, "Promoted") != 0;
};

S.AttributeNames <- { Hitpoints = "生命", Stamina = "疲劳值", Bravery = "决心", Initiative = "主动值",
    MeleeSkill = "近战技能", RangedSkill = "远程技能", MeleeDefense = "近战防御", RangedDefense = "远程防御" };

// 从 8 项属性里随机抽 _count 项各加 _gain，返回抽中的属性名（中文，顿号分隔）
S.raiseRandomAttributes <- function( _target, _count, _gain )
{
    local keys = clone this.Attributes;
    local names = [];
    for (local i = 0; i < _count && keys.len() > 0; ++i)
    {
        local key = keys.remove(::Math.rand(0, keys.len() - 1));
        _target[key] += _gain;
        names.push(this.AttributeNames[key]);
    }
    local text = "";
    foreach (i, name in names)
        text += (i == 0 ? "" : "、") + name;
    return text;
};

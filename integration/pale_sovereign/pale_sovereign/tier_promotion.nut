local S = ::PaleSovereign;

S.getUndeadBackground <- function( _bro )
{
    local background = _bro.getBackground();
    return ::MSU.isKindOf(background, "pale_undead_background") ? background : null;
};

S.getUndeadTier <- function( _bro )
{
    local background = this.getUndeadBackground(_bro);
    return background == null ? 0 : background.m.PaleTier;
};

S.tierChoicesFor <- function( _background )
{
    local tier = _background.m.PaleTier;
    if (tier >= 3)
        return [];
    if (_background.m.PaleRanged)
        return this.RangedTierChoices[tier == 1 ? "archer" : _background.m.PaleBranch];
    return this.TierChoices[_background.m.PaleSkeleton ? 1 : 0][tier - 1];
};

S.tierNewLevel <- function( _bro, _background )
{
    return _background.m.PaleRanged ? 1 : _bro.getLevel() - this.tierLevelsSpent();
};

S.restoreTierSkills <- function( _bro )
{
    local background = this.getUndeadBackground(_bro);
    if (background == null)
        return;
    if ("restoreRetainedUndeadPerks" in this)
        this.restoreRetainedUndeadPerks(_bro);
    if (background.m.PaleTier < 2)
        return;
    local branch = this.TierBranches[background.m.PaleBranch];
    local keys = clone branch.Skills;
    local middle = _bro.getFlags().get("PaleMiddleBranch");
    if (branch.Tier == 3 && typeof middle == "string" && middle in this.TierBranches)
    {
        local previous = this.TierBranches[middle];
        if (previous.Tier == 2 && previous.Skeleton == branch.Skeleton
            && ("RangedSkill" in previous) == ("RangedSkill" in branch)
            && (!background.m.PaleRanged || this.RangedTierChoices[middle].find(background.m.PaleBranch) != null))
            keys.extend(previous.Skills);
    }
    local skills = _bro.getSkills();
    foreach (key in keys)
    {
        if (skills.hasSkill(this.tierTalentID(key)))
            continue;
        local talent = ::new(this.SkillDir + this.TierTalents[key].Script);
        talent.configure(key);
        skills.add(talent);
    }
    if (branch.Tier == 3)
        this.grantVisage(_bro, true);
};

// 1.6.32 高阶亡灵默认带“恐惧之容”：不占特技点、不能退还；_tree 为 true 时在特技树第 1 行显示为已学会
S.VisageID <- "perk.rf_terrifying_visage";
S.VisageScript <- "scripts/skills/perks/perk_rf_terrifying_visage";
S.grantVisage <- function( _actor, _tree )
{
    local skills = _actor.getSkills();
    if (_tree)
    {
        try
        {
            local tree = _actor.getPerkTree();
            if (tree != null && !tree.hasPerk(this.VisageID))
                tree.addPerk(this.VisageID, 1);
        }
        catch (e)
        {
            ::logError("Pale Sovereign: could not add Terrifying Visage to the perk tree: " + e);
        }
    }
    local perk = skills.getSkillByID(this.VisageID);
    if (perk == null)
    {
        perk = ::new(this.VisageScript);
        skills.add(perk);
    }
    perk.m.PaleTierSkill <- true;
    try { perk.m.IsRefundable = false; } catch (e) {}
};

// 1.7.0 活人转化为中阶亡灵时免费升阶（不检查等级与材料、不扣材料）
S.FreeTier <- false;

// Permanent undead tier ascension is exclusive to the Champion oath route.
S.canUseTierSystem <- function()
{
    return this.isActive() && this.oath() == this.Oath.Champion;
};

S.tierCanPromote <- function( _bro, _branch )
{
    if (!this.canUseTierSystem())
        return false;
    if (this.FreeTier)
    {
        local baseBg = this.getUndeadBackground(_bro);
        return _bro != null && this.isUndead(_bro) && baseBg != null && _branch in this.TierBranches && this.tierChoicesFor(baseBg).find(_branch) != null;
    }
    if (_bro == null || !_bro.isAlive()
        || !this.isUndead(_bro) || _bro.getFlags().has("PaleSoulbound") || _bro.getLevel() < this.TierCost.Level
        || this.undead().find(_bro) == null || !(_branch in this.TierBranches))
        return false;
    local old = this.getUndeadBackground(_bro);
    return old != null && this.tierChoicesFor(old).find(_branch) != null
        && this.get("Reserve") >= this.tierReserveCost() && this.countItems("misc.pale_jade") >= this.TierCost.Jade
        && ::World.Assets.getMoney() >= this.TierCost.Money;
};

S.planTierEquipment <- function( _bro, _branch )
{
    local slots = ::Const.ItemSlot;
    local items = _bro.getItems();
    local weapon = items.getItemAtSlot(slots.Mainhand);
    local ammo = items.getItemAtSlot(slots.Ammo);
    local plan = { Issue = [], Store = [] };
    if (::MSU.isNull(weapon) || !::MSU.isKindOf(weapon, "weapon") || !weapon.isWeaponType(_branch.AllowedWeapons))
    {
        if (!::MSU.isNull(weapon))
            plan.Store.push(weapon);
        weapon = ::new(this.ItemDir + _branch.Weapon);
        plan.Issue.push(weapon);
        if (weapon.getBlockedSlotType() == slots.Offhand)
        {
            local offhand = items.getItemAtSlot(slots.Offhand);
            if (!::MSU.isNull(offhand))
                plan.Store.push(offhand);
        }
    }
    foreach (kit in this.RangedTierKits)
    {
        if (!weapon.isWeaponType(kit.Type))
            continue;
        if (::MSU.isNull(ammo) || !::MSU.isKindOf(ammo, "ammo") || ammo.getAmmoType() != kit.Ammo || ammo.getAmmo() == 0)
        {
            if (!::MSU.isNull(ammo))
                plan.Store.push(ammo);
            plan.Issue.push(::new(this.ItemDir + kit.Quiver));
        }
        break;
    }
    return plan;
};

S.equipTierKit <- function( _items, _stash, _plan )
{
    local displaced = [];
    local stored = [];
    local issued = [];
    try
    {
        foreach (item in _plan.Store)
        {
            _items.unequip(item);
            displaced.push(item);
            if (_stash.add(item) == null)
                throw "no space for the displaced equipment";
            stored.push(item);
        }
        foreach (item in _plan.Issue)
        {
            if (!_items.equip(item))
                throw "could not equip " + item.getID();
            issued.push(item);
        }
    }
    catch (e)
    {
        foreach (item in issued)
            _items.unequip(item);
        foreach (item in stored)
            _stash.remove(item);
        foreach (item in displaced)
            _items.equip(item);
        throw e;
    }
};

S.resetTierArmor <- function( _bro )
{
    local flags = _bro.getFlags();
    if (!flags.has("PaleGilded"))
        return;
    foreach (slot in [::Const.ItemSlot.Body, ::Const.ItemSlot.Head])
    {
        local item = _bro.getItems().getItemAtSlot(slot);
        if (item != null && "PaleGildedBonus" in item.m)
        {
            item.m.ConditionMax -= item.m.PaleGildedBonus;
            delete item.m.PaleGildedBonus;
            item.setCondition(::Math.minf(item.getCondition(), item.getConditionMax()));
        }
        flags.remove("PaleGildedCondition." + slot);
    }
};

S.tierPromote <- function( _bro, _branch )
{
    if (!this.tierCanPromote(_bro, _branch))
        return "升阶条件已改变。请回到账簿检查人选与材料。";

    local oldBackground = _bro.getBackground();
    local oldLevel = _bro.getLevel();
    local oldHealth = _bro.getHitpointsPct();
    local next = this.TierBranches[_branch];
    local stash = ::World.Assets.getStash();
    local kit = null;
    if ("RangedSkill" in next)
    {
        kit = this.planTierEquipment(_bro, next);
        if (stash.getNumberOfEmptySlots() < kit.Store.len())
            return "仓库没有足够空位存放换下的装备，升阶尚未开始。";
    }
    local background = ::new(this.SkillDir + "backgrounds/pale_" + _branch + "_background");
    if (!::MSU.isKindOf(background, "pale_tier_background"))
        return "升阶背景未能加载，材料仍在账簿中。";
    local skills = _bro.getSkills();
    local props = _bro.getBaseProperties();
    local oldStats = props.getClone();
    local saved = { Level = _bro.m.Level, XP = _bro.m.XP, LevelUps = _bro.m.LevelUps,
        Attributes = _bro.m.Attributes, Tree = _bro.m.PerkTree };
    local level = this.tierNewLevel(_bro, oldBackground);
    // Retain the fraction of progress within the level, using the new level's XP curve.
    local progress = 0.0;
    if (!oldBackground.m.PaleRanged)
    {
        local oldMinimum = ::Const.LevelXP[oldLevel - 1];
        local oldInterval = ::Math.max(1, _bro.getXPForNextLevel() - oldMinimum);
        progress = ::Math.maxf(0.0, ::Math.minf(1.0, (_bro.getXP() - oldMinimum).tofloat() / oldInterval));
    }
    local minimum = ::Const.LevelXP[level - 1];
    local interval = ::Const.LevelXP[level] - minimum;
    local statNames = ["Hitpoints", "MeleeSkill", "MeleeDefense", "RangedDefense", "Initiative", "ActionPoints"];

    try
    {
        skills.removeByID(oldBackground.getID());
        skills.add(background);
        _bro.m.Background = background;
        foreach (i, key in statNames)
            props[key] = next.Stats[i];
        props.Bravery = 100;
        // These fields are unspecified. Use the untrained low-tier range midpoint.
        local template = ::new(this.SkillDir + "backgrounds/pale_" + (next.Skeleton ? "skeleton" : "zombie") + "_background");
        local adjustments = template.onChangeAttributes();
        foreach (key in ["Stamina", "RangedSkill"])
        {
            local bounds = template.m.BaseAttributes[key];
            local delta = adjustments[key];
            props[key] = ::Math.floor((bounds[0] + bounds[1] + delta[0] + delta[1]) * 0.5);
        }
        if ("RangedSkill" in next)
            props.RangedSkill = next.RangedSkill;

        _bro.m.Level = level;
        _bro.m.XP = minimum + ::Math.min(interval - 1, ::Math.floor(interval * progress));
        _bro.m.LevelUps = level - 1;
        _bro.m.Attributes = [];
        _bro.fillAttributeLevelUpValues(::Const.XP.MaxLevelWithPerkpoints - 1);
        background.buildDescription(true);
        local tree = background.createPerkTreeBlueprint();
        tree.setActor(_bro);
        _bro.m.PerkTree = tree;
        tree.build();
        if (kit != null)
            this.equipTierKit(_bro.getItems(), stash, kit);
    }
    catch (e)
    {
        skills.removeByID(background.getID());
        _bro.m.Background = oldBackground;
        if (!skills.hasSkill(oldBackground.getID()))
            skills.add(oldBackground);
        foreach (key in statNames)
            props[key] = oldStats[key];
        foreach (key in ["Bravery", "Stamina", "RangedSkill"])
            props[key] = oldStats[key];
        _bro.m.Level = saved.Level;
        _bro.m.XP = saved.XP;
        _bro.m.LevelUps = saved.LevelUps;
        _bro.m.Attributes = saved.Attributes;
        _bro.m.PerkTree = saved.Tree;
        skills.update();
        ::logError("Pale Sovereign: could not prepare promotion to " + _branch + ": " + e);
        return "升阶仪式未能完成，材料仍在账簿中。";
    }

    local retainedKeys = "retainedUndeadPerkKeys" in this ? this.retainedUndeadPerkKeys(_bro) : [];
    local perks = skills.getSkillsByFunction(@(skill) skill.isType(::Const.SkillType.Perk) && ::MSU.isNull(skill.getItem()));
    foreach (perk in perks)
    {
        if ("isRetainedUndeadPerk" in this && this.isRetainedUndeadPerk(perk))
        {
            try { perk.m.IsRefundable = false; } catch (e) {}
            local key = "PaleKey" in perk.m ? perk.m.PaleKey : perk.getID().slice(13);
            if ("UndeadPerks" in this && key in this.UndeadPerks && retainedKeys.find(key) == null)
                retainedKeys.push(key);
            continue;
        }
        if (!::MSU.isIn("PaleTierSkill", perk.m, true) || !perk.m.PaleTierSkill)
            perk.removeSelf();
    }
    if ("saveRetainedUndeadPerkKeys" in this)
        this.saveRetainedUndeadPerkKeys(_bro, retainedKeys);
    local retainedNote = "";
    if (retainedKeys.len() > 0 && "UndeadPerks" in this)
    {
        local names = "";
        foreach (i, key in retainedKeys)
            if (key in this.UndeadPerks)
                names += (names == "" ? "" : "、") + "【" + this.UndeadPerks[key].Name + "】";
        if (names != "")
            retainedNote = "，并保留常驻亡灵专属特技：" + names;
    }
    local count;
    do
    {
        count = skills.m.Skills.len();
        skills.collectGarbage(false);
    }
    while (skills.m.Skills.len() < count);
    _bro.m.LevelUpsSpent = 0;
    _bro.m.PerkPoints = ::Math.min(level, ::Const.XP.MaxLevelWithPerkpoints) - 1;
    _bro.m.PerkPointsSpent = 0;
    _bro.resetPerkTier();

    local flags = _bro.getFlags();
    if (next.Tier == 2)
        flags.set("PaleMiddleBranch", _branch);
    this.resetTierArmor(_bro);
    // 1.7.7 升阶清空魂玉统领与镀金护甲，可再次施加；宝石眼窝已改为永久特质，随特质保留且终生限一次
    foreach (key in ["PaleJade", "PaleLeader", "PaleGilded"])
        flags.remove(key);
    skills.removeByID("effects.pale_jade_leader");
    this.restoreTierSkills(_bro);
    if ("ensureCaptiveChampion" in this)
        this.ensureCaptiveChampion(_bro);
    this.applyUndeadLook(_bro);
    skills.update();
    _bro.setHitpointsPct(::Math.maxf(oldHealth, 1.0 / _bro.getHitpointsMax()));

    if (!this.FreeTier)
    {
        this.removeMaterial("jade");
        this.changeReserve(-this.tierReserveCost());
        ::World.Assets.addMoney(-this.TierCost.Money);
    }
    ::World.State.updateTopbarAssets();
    return "法阵里的碧火熄灭时，旧骨已重锻为新的形骸。" + _bro.getName() + " 拄着兵刃缓缓起身，眼窝里的魂火比从前更冷、也更沉。\n\n（"
        + _bro.getName() + " 已升阶为【" + next.Name + "】。等级 " + oldLevel + " → " + level
        + "，可重新分配 " + _bro.getLevelUps() + " 次属性增长与 " + _bro.getPerkPoints() + " 点特技" + retainedNote + "）";
};

S.Mod.hook("scripts/entity/tactical/player", function(q)
{
    q.fillAttributeLevelUpValues = @(__original) function( _amount, _maxOnly = false, _minOnly = false )
    {
        local tier = S.getUndeadTier(this);
        local former = [];
        if (tier >= 2)
            foreach (rolls in this.m.Attributes)
                former.push(rolls.len());
        local result = __original(_amount, _maxOnly, _minOnly);
        if (tier >= 2)
        {
            foreach (i, rolls in this.m.Attributes)
            {
                // Vanilla prepends the newly rolled gains to the existing queue.
                local added = rolls.len() - (i < former.len() ? former[i] : 0);
                for (local j = 0; j < added; ++j)
                    rolls[j] = ::Math.max(1, ::Math.floor(rolls[j] * 0.5));
            }
        }
        return result;
    };
});

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

S.restoreTierSkills <- function( _bro )
{
    local background = this.getUndeadBackground(_bro);
    if (background == null || background.m.PaleTier < 2)
        return;
    local branch = this.TierBranches[background.m.PaleBranch];
    local keys = clone branch.Skills;
    local middle = _bro.getFlags().get("PaleMiddleBranch");
    if (branch.Tier == 3 && typeof middle == "string" && middle in this.TierBranches)
    {
        local previous = this.TierBranches[middle];
        if (previous.Tier == 2 && previous.Skeleton == branch.Skeleton)
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
};

S.tierCanPromote <- function( _bro, _branch )
{
    if (!this.isActive() || !::World.Assets.isCamping() || _bro == null || !_bro.isAlive()
        || !this.isUndead(_bro) || _bro.getFlags().has("PaleSoulbound") || _bro.getLevel() < this.TierCost.Level
        || this.undead().find(_bro) == null || !(_branch in this.TierBranches))
        return false;
    local old = this.getUndeadBackground(_bro);
    local next = this.TierBranches[_branch];
    return old != null && next.Tier == old.m.PaleTier + 1 && next.Skeleton == old.m.PaleSkeleton
        && this.get("Reserve") >= this.TierCost.Reserve && this.countItems("misc.pale_jade") >= this.TierCost.Jade
        && ::World.Assets.getMoney() >= this.TierCost.Money;
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
    local background = ::new(this.SkillDir + "backgrounds/pale_" + _branch + "_background");
    if (!::MSU.isKindOf(background, "pale_tier_background"))
        return "升阶背景未能加载，材料仍在账簿中。";
    local skills = _bro.getSkills();
    local props = _bro.getBaseProperties();
    local oldStats = props.getClone();
    local saved = { Level = _bro.m.Level, XP = _bro.m.XP, LevelUps = _bro.m.LevelUps,
        Attributes = _bro.m.Attributes, Tree = _bro.m.PerkTree };
    local level = oldLevel - this.TierCost.LevelsSpent;
    // Retain the fraction of progress within the level, using the new level's XP curve.
    local oldMinimum = ::Const.LevelXP[oldLevel - 1];
    local oldInterval = ::Math.max(1, _bro.getXPForNextLevel() - oldMinimum);
    local progress = ::Math.maxf(0.0, ::Math.minf(1.0, (_bro.getXP() - oldMinimum).tofloat() / oldInterval));
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
        props.Bravery = 120;
        // These fields are unspecified. Use the untrained low-tier range midpoint.
        local template = ::new(this.SkillDir + "backgrounds/pale_" + (next.Skeleton ? "skeleton" : "zombie") + "_background");
        local adjustments = template.onChangeAttributes();
        foreach (key in ["Stamina", "RangedSkill"])
        {
            local bounds = template.m.BaseAttributes[key];
            local delta = adjustments[key];
            props[key] = ::Math.floor((bounds[0] + bounds[1] + delta[0] + delta[1]) * 0.5);
        }

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

    local perks = skills.getSkillsByFunction(@(skill) skill.isType(::Const.SkillType.Perk) && ::MSU.isNull(skill.getItem()));
    foreach (perk in perks)
    {
        if (!::MSU.isIn("PaleTierSkill", perk.m, true) || !perk.m.PaleTierSkill)
            perk.removeSelf();
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
    foreach (key in ["PaleJade", "PaleGilded", "PaleGemEyes"])
        flags.remove(key);
    this.restoreTierSkills(_bro);
    skills.update();
    _bro.setHitpointsPct(::Math.maxf(oldHealth, 1.0 / _bro.getHitpointsMax()));

    this.removeMaterial("jade");
    this.changeReserve(-this.TierCost.Reserve);
    ::World.Assets.addMoney(-this.TierCost.Money);
    ::World.State.updateTopbarAssets();
    return _bro.getName() + " 已升阶为【" + next.Name + "】。等级 " + oldLevel + " → " + level
        + "，可重新分配 " + _bro.getLevelUps() + " 次属性增长与 " + _bro.getPerkPoints() + " 点特技。";
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

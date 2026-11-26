// Shared by the branch backgrounds. It is not a recruitable background.
this.pale_tier_background <- ::inherit("scripts/skills/backgrounds/pale_undead_background", {
    m = {},

    function create()
    {
        this.pale_undead_background.create();
        local branch = ::PaleSovereign.TierBranches[this.m.PaleBranch];
        this.m.ID = "background.pale_" + this.m.PaleBranch;
        this.m.Name = branch.Name;
        this.m.PaleTier = branch.Tier;
        this.m.PaleSkeleton = branch.Skeleton;
        this.m.PaleRanged = "RangedSkill" in branch;
        this.m.Icon = "ui/backgrounds/pale_" + this.m.PaleBranch + ".png";
        this.m.BackgroundDescription = branch.Description;
    }

    function getTooltip()
    {
        local ret = this.pale_undead_background.getTooltip();
        ret.push({ id = 11, type = "text", icon = "ui/icons/pale_tier_" + this.m.PaleTier + ".png",
            text = (this.m.PaleTier == 2 ? "中阶" : "高阶") + "常驻亡灵。升级属性增长减半，向下取整，最低 1 点。" });
        return ret;
    }

    function createPerkTreeBlueprint()
    {
        local S = ::PaleSovereign;
        local branch = S.TierBranches[this.m.PaleBranch];
        local groups = {};
        foreach (i, collection in S.TierPerkCollections)
            groups[collection] <- branch.Groups[i].map(@(group) "pg.rf_" + group);
        local undeadGroup = this.m.PaleSkeleton ? "pg.pale_undead_skeleton" : "pg.pale_undead_zombie";
        if (!("pgc.rf_exclusive_1" in groups))
            groups["pgc.rf_exclusive_1"] <- [];
        if (groups["pgc.rf_exclusive_1"].find(undeadGroup) == null)
            groups["pgc.rf_exclusive_1"].push(undeadGroup);
        return ::new(::DynamicPerks.Class.PerkTree).init({ DynamicMap = groups });
    }

    function getPerkGroupMultiplier( _groupID, _tree )
    {
        local S = ::PaleSovereign;
        if (_groupID.find("pg.rf_") == 0)
        {
            local group = _groupID.slice(6);
            local branch = S.TierBranches[this.m.PaleBranch];
            if ((!this.m.PaleRanged && S.TierCommonExclusions.find(group) != null) || branch.Excluded.find(group) != null)
                return 0; // MSU treats negative weights as forced choices.
            if (branch.Weighted.find(group) != null)
                return 3;
        }
        if (this.m.PaleBranch == "skeleton_king" && _groupID == "pg.special.rf_leadership")
            return 3;
        return this.pale_undead_background.getPerkGroupMultiplier(_groupID, _tree);
    }
});

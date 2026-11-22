local S = ::PaleSovereign;

// 1.6.8 常驻亡灵的三种模板：征召、兵营、亡者之城和受缚亡灵共用
S.UndeadKinds <- {
    skeleton = { Name = "骷髅", Background = "pale_skeleton_background", Skeleton = true,
        Gear = ["weapons/ancient/ancient_sword", "shields/wooden_shield"] },
    archer = { Name = "骷髅弓手", Background = "pale_skeleton_archer_background", Skeleton = true,
        Gear = ["weapons/short_bow", "ammo/quiver_of_arrows"] },
    zombie = { Name = "行尸", Background = "pale_zombie_background", Skeleton = false,
        Gear = ["weapons/wooden_stick", "armor/tattered_sackcloth"] }
};
S.UndeadKindOrder <- ["skeleton", "archer", "zombie"];

S.undeadKindOf <- function( _kind )
{
    if (typeof _kind == "bool")
        return _kind ? "skeleton" : "zombie";
    return _kind in this.UndeadKinds ? _kind : "skeleton";
};

// 特质池：原版特质里挑适合亡灵的，加上 12 个亡灵专属特质（scripts/skills/traits/pale_undead_*）
S.UndeadTraitPool <- {
    Both = ["iron_jaw_trait", "eagle_eyes_trait", "short_sighted_trait", "clumsy_trait", "dexterous_trait", "sure_footing_trait",
        "quick_trait", "hesitant_trait", "strong_trait", "lucky_trait", "bloodthirsty_trait", "brute_trait", "bright_trait",
        "dumb_trait", "night_owl_trait", "night_blind_trait",
        "pale_undead_sleepless_trait", "pale_undead_grudge_trait", "pale_undead_soulfire_trait"],
    Zombie = ["huge_trait", "tough_trait", "fat_trait", "clubfooted_trait", "iron_lungs_trait",
        "pale_undead_salted_trait", "pale_undead_gnawing_trait", "pale_undead_deathgrip_trait", "pale_undead_putrid_trait"],
    Skeleton = ["tiny_trait", "fragile_trait", "athletic_trait",
        "pale_undead_dense_bone_trait", "pale_undead_hollow_skull_trait", "pale_undead_old_drill_trait",
        "pale_undead_legion_discipline_trait", "pale_undead_brittle_trait"]
};

// 亡灵专属特质的数据（Icon 借用原版特质的图标）
S.UndeadTraits <- {
    salted = { Name = "盐渍之躯", Icon = "tough_trait", Excluded = ["trait.fragile", "trait.pale_putrid"],
        Description = "这具尸身在盐坑里泡了整整一个冬天，皮肉硬得像腌过的皮革。",
        Effects = [["ui/icons/health.png", "生命 +12"]] },
    gnawing = { Name = "饥渴撕咬", Icon = "bloodthirsty_trait", Excluded = [],
        Description = "它的牙齿从没停止过咬合，每一次得手都像是在进食。",
        Effects = [["ui/icons/health.png", "近战攻击命中后恢复 5 点生命"]] },
    deathgrip = { Name = "亡者之握", Icon = "sure_footing_trait", Excluded = [],
        Description = "僵直的十指一旦扣进泥土，就再也扳不开。",
        Effects = [["ui/icons/special.png", "免疫击退与抓取"]] },
    putrid = { Name = "腐坏之躯", Icon = "fragile_trait", Excluded = ["trait.tough", "trait.huge", "trait.pale_salted"],
        Description = "盐没能留住这具身体，腐肉一碰就往下掉。",
        Effects = [["ui/icons/health.png", "生命 " + ::MSU.Text.colorNegative("-12")]] },
    dense_bone = { Name = "致密骨骼", Icon = "strong_trait", Excluded = ["trait.fragile", "trait.pale_brittle"],
        Description = "这副骨架沉得出奇，像是在墓土里慢慢长成了石头。",
        Effects = [["ui/icons/armor_body.png", "受到的伤害 -5%"]] },
    hollow_skull = { Name = "空鸣颅骨", Icon = "iron_jaw_trait", Excluded = [],
        Description = "颅腔里早已空空如也，敲上去只有一声闷响。",
        Effects = [["ui/icons/armor_head.png", "头部受到的伤害 -25%"]] },
    old_drill = { Name = "旧日武艺", Icon = "dexterous_trait", Excluded = ["trait.clumsy"],
        Description = "它忘了自己的名字，却没忘生前操练过千百遍的招式。",
        Effects = [["ui/icons/melee_skill.png", "近战技能 +4"], ["ui/icons/ranged_skill.png", "远程技能 +4"]] },
    legion_discipline = { Name = "军团纪律", Icon = "teamplayer_trait", Excluded = [],
        Description = "古帝国军团的队列刻进了骨头里，身边有同袍时站得格外稳。",
        Effects = [["ui/icons/melee_defense.png", "每有 1 名相邻的友方亡灵，近战防御 +3（最多 +9）"]] },
    brittle = { Name = "朽坏关节", Icon = "clubfooted_trait", Excluded = ["trait.quick", "trait.dexterous", "trait.pale_soulfire", "trait.pale_dense_bone"],
        Description = "捆住关节的铜索早已锈蚀，每走一步都咯吱作响。",
        Effects = [["ui/icons/initiative.png", "主动 " + ::MSU.Text.colorNegative("-10")], ["ui/icons/melee_defense.png", "近战防御 " + ::MSU.Text.colorNegative("-3")]] },
    sleepless = { Name = "不眠者", Icon = "iron_lungs_trait", Excluded = [],
        Description = "死人不需要喘息，它只是在等下一道命令。",
        Effects = [["ui/icons/fatigue.png", "每回合疲劳恢复 +3"]] },
    grudge = { Name = "不灭执念", Icon = "deathwish_trait", Excluded = [],
        Description = "生前的某桩恨意仍旧缠着它，越是残破越是凶狠。",
        Effects = [["ui/icons/regular_damage.png", "生命低于 50% 时造成的伤害 +15%"]] },
    soulfire = { Name = "魂火炽烈", Icon = "quick_trait", Excluded = ["trait.hesitant", "trait.pale_brittle"],
        Description = "眼窝里的魂火烧得比同类更旺，总是第一个动起来。",
        Effects = [["ui/icons/initiative.png", "主动 +10"]] }
};

// 随机加 1–2 个特质（40% 两个），互斥的不会同时出现
S.addUndeadTraits <- function( _bro, _skeleton )
{
    local pool = clone this.UndeadTraitPool.Both;
    pool.extend(_skeleton ? this.UndeadTraitPool.Skeleton : this.UndeadTraitPool.Zombie);
    local count = ::Math.rand(1, 100) <= 40 ? 2 : 1;
    local added = [];
    while (added.len() < count && pool.len() > 0)
    {
        local script = pool.remove(::Math.rand(0, pool.len() - 1));
        local trait = null;
        try { trait = ::new("scripts/skills/traits/" + script); } catch (e) { trait = null; }
        if (trait == null || _bro.getSkills().hasSkill(trait.getID()))
            continue;
        local fits = true;
        foreach (other in added)
            if (other.isExcluded(trait.getID()) || trait.isExcluded(other.getID()))
                fits = false;
        if (!fits)
            continue;
        _bro.getSkills().add(trait);
        added.push(trait);
    }
    return added;
};

// 生成一名常驻亡灵：属性按背景范围随机，抽天赋星和特质
S.createUndead <- function( _kind )
{
    local kind = this.UndeadKinds[this.undeadKindOf(_kind)];
    local bro = this.spawnBrother(kind.Background, kind.Gear, -1, false);
    bro.getFlags().set("PalePermanentUndead", true);
    bro.getFlags().set("undead", true);
    try { bro.fillTalentValues(); } catch (e) { ::logError("[PaleSovereign] 常驻亡灵天赋: " + e); }
    this.addUndeadTraits(bro, kind.Skeleton);
    bro.fillAttributeLevelUpValues(::Const.XP.MaxLevelWithPerkpoints - 1);
    local titles = kind.Skeleton ? this.SkeletonTitles : this.ZombieTitles;
    bro.setTitle(titles[::Math.rand(0, titles.len() - 1)]);
    bro.m.MoraleState = ::Const.MoraleState.Ignore;
    this.applyUndeadLook(bro);
    bro.getSkills().update();
    bro.setHitpointsPct(1.0);
    return bro;
};

S.hasUndeadSlot <- function()
{
    local limit = this.permanentUndeadLimit();
    return (limit == null || this.undead().len() < limit) && ::World.getPlayerRoster().getSize() < ::World.Assets.getBrothersMax();
};

// 受缚亡灵（攻破亡灵营地获得）：在仓库里右键使用即可收编
S.recruitBoundUndead <- function( _item )
{
    if (!this.isActive() || (::Tactical != null && ::Tactical.isActive()) || !this.hasUndeadSlot())
        return false;
    this.createUndead(_item.m.PaleKind);
    ::World.Assets.updateFormation(true);
    return true;
};

S.isUndeadCamp <- function( _location )
{
    local faction = ::World.FactionManager.getFaction(_location.getFaction());
    return faction != null && [::Const.FactionType.Undead, ::Const.FactionType.Zombies].find(faction.getType()) != null;
};

// 亡灵营地的征召子页（在登记地点附近，每处一次）
S.RecruitSite <- null;
S.recruitPanel <- function( _screen )
{
    local site = this.RecruitSite;
    if (site == null || !this.canRecruitUndead(site))
    {
        _screen.Text = "现在无法在这里征召。";
        this.option(_screen, "返回营地", @() "@camp");
        return;
    }
    _screen.Text = "选择要从盐封棺里唤起的亡灵，花费 " + this.recruitCost() + " 点防腐尸骸，每处登记地点只能征召一次。属性按种类在范围内随机，另有天赋星和 1–2 个特质。";
    foreach (kind in this.UndeadKindOrder)
    {
        local recruitKind = kind;
        this.option(_screen, "征召常驻" + this.UndeadKinds[recruitKind].Name, function()
        {
            S.RecruitSite = null;
            return S.recruitUndead(site, recruitKind) ? "一具" + S.UndeadKinds[recruitKind].Name + "从盐封棺中站起，加入了战团。" : "无法征召。";
        });
    }
    this.option(_screen, "返回营地", @() "@camp");
};

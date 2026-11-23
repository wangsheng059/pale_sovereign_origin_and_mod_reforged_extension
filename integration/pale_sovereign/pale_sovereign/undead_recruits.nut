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

// Combine appropriate vanilla traits with the origin-specific traits.
S.UndeadTraitPool <- {
    Both = ["iron_jaw_trait", "eagle_eyes_trait", "clumsy_trait", "dexterous_trait", "sure_footing_trait",
        "quick_trait", "strong_trait", "lucky_trait", "bloodthirsty_trait", "brute_trait", "bright_trait", "dumb_trait",
        "pale_undead_sleepless_trait", "pale_undead_grudge_trait", "pale_undead_soulfire_trait",
        "pale_undead_dim_soulfire_trait", "pale_undead_forgotten_drill_trait"],
    Zombie = ["huge_trait", "tough_trait", "fat_trait", "clubfooted_trait", "iron_lungs_trait",
        "pale_undead_salted_trait", "pale_undead_gnawing_trait", "pale_undead_deathgrip_trait", "pale_undead_putrid_trait",
        "pale_undead_embalmed_trait", "pale_undead_thick_hide_trait", "pale_undead_toxic_flesh_trait",
        "pale_undead_stiff_corpse_trait", "pale_undead_broken_fingers_trait", "pale_undead_maggot_ridden_trait"],
    Skeleton = ["tiny_trait", "fragile_trait", "athletic_trait",
        "pale_undead_dense_bone_trait", "pale_undead_hollow_skull_trait", "pale_undead_old_drill_trait",
        "pale_undead_legion_discipline_trait", "pale_undead_brittle_trait",
        "pale_undead_refined_joints_trait", "pale_undead_tall_frame_trait", "pale_undead_frail_bone_trait",
        "pale_undead_loose_skull_trait", "pale_undead_cracked_ribs_trait", "pale_undead_rusted_pins_trait"]
};

// 1.6.18 负面特质：队伍里等级最高的亡灵法师学会死灵精通后，新唤起的常驻亡灵不再抽到这些
S.UndeadNegativeTraits <- ["trait.clumsy", "trait.dumb", "trait.fat", "trait.clubfooted", "trait.tiny", "trait.fragile",
    "trait.pale_putrid", "trait.pale_brittle", "trait.pale_frail_bone",
    "trait.pale_stiff_corpse", "trait.pale_broken_fingers", "trait.pale_maggot_ridden",
    "trait.pale_loose_skull", "trait.pale_cracked_ribs", "trait.pale_rusted_pins",
    "trait.pale_dim_soulfire", "trait.pale_forgotten_drill"];

// Origin-specific trait icons are derived from the stable trait keys.
S.UndeadTraits <- {
    salted = { Name = "盐渍之躯", Excluded = ["trait.fragile", "trait.pale_putrid"],
        Description = "这具尸身在盐坑里泡了整整一个冬天，皮肉硬得像腌过的皮革。",
        Effects = [["ui/icons/health.png", "生命 +12"]] },
    gnawing = { Name = "饥渴撕咬", Excluded = [],
        Description = "它的牙齿从没停止过咬合，每一次得手都像是在进食。",
        Effects = [["ui/icons/health.png", "近战攻击命中后恢复 5 点生命"]] },
    deathgrip = { Name = "亡者之握", Excluded = [],
        Description = "僵直的十指一旦扣进泥土，就再也扳不开。",
        Effects = [["ui/icons/special.png", "免疫击退与抓取"]] },
    putrid = { Name = "腐坏之躯", Excluded = ["trait.tough", "trait.huge", "trait.pale_salted"],
        Description = "盐没能留住这具身体，腐肉一碰就往下掉。",
        Effects = [["ui/icons/health.png", "生命 " + ::MSU.Text.colorNegative("-12")]] },
    dense_bone = { Name = "致密骨骼", Excluded = ["trait.fragile", "trait.pale_brittle", "trait.pale_frail_bone"],
        Description = "这副骨架沉得出奇，像是在墓土里慢慢长成了石头。",
        Effects = [["ui/icons/armor_body.png", "受到的伤害 -10%"]] },
    hollow_skull = { Name = "空鸣颅骨", Excluded = [],
        Description = "颅腔里早已空空如也，敲上去只有一声闷响。",
        Effects = [["ui/icons/armor_head.png", "头部受到的伤害 -25%"]] },
    old_drill = { Name = "旧日武艺", Excluded = ["trait.clumsy"],
        Description = "它忘了自己的名字，却没忘生前操练过千百遍的招式。",
        Effects = [["ui/icons/melee_skill.png", "近战技能 +4"], ["ui/icons/ranged_skill.png", "远程技能 +4"],
            ["ui/icons/melee_defense.png", "近战防御 +4"], ["ui/icons/ranged_defense.png", "远程防御 +4"]] },
    legion_discipline = { Name = "军团纪律", Excluded = [],
        Description = "古帝国军团的队列刻进了骨头里，身边有同袍时站得格外稳。",
        Effects = [["ui/icons/melee_defense.png", "每有 1 名相邻的友方亡灵，近战防御 +3（最多 +9）"]] },
    brittle = { Name = "朽坏关节", Excluded = ["trait.quick", "trait.dexterous", "trait.pale_soulfire", "trait.pale_dense_bone"],
        Description = "捆住关节的铜索早已锈蚀，每走一步都咯吱作响。",
        Effects = [["ui/icons/initiative.png", "主动 " + ::MSU.Text.colorNegative("-10")], ["ui/icons/melee_defense.png", "近战防御 " + ::MSU.Text.colorNegative("-3")]] },
    sleepless = { Name = "不眠者", Excluded = [],
        Description = "死人不需要喘息，它只是在等下一道命令。",
        Effects = [["ui/icons/fatigue.png", "每回合疲劳恢复 +3"]] },
    grudge = { Name = "不灭执念", Excluded = [],
        Description = "生前的某桩恨意仍旧缠着它，越是残破越是凶狠。",
        Effects = [["ui/icons/regular_damage.png", "生命低于 50% 时造成的伤害 +15%"]] },
    embalmed = { Name = "精良防腐", Excluded = ["trait.pale_putrid"],
        Description = "缝合它的人用足了药草和松脂，这具身体几乎看不出腐坏的痕迹。",
        Effects = [["ui/icons/health.png", "每日用防腐尸骸修补时额外恢复 10% 最大生命"], ["ui/icons/health.png", "战斗中受到死灵技能的治疗 +25%"]] },
    thick_hide = { Name = "硬皮", Excluded = [],
        Description = "盐痂结成了厚厚一层硬壳，刀砍上去像劈在老树皮上。",
        Effects = [["ui/icons/special.png", "受到重伤的阈值提高 25%"], ["ui/icons/armor_head.png", "被击中头部时的额外伤害降低 25%"]] },
    toxic_flesh = { Name = "腐毒血肉", Excluded = [],
        Description = "砍开它的皮肉，溅出来的不是血，而是一股呛人的腐毒。",
        Effects = [["ui/icons/fatigue.png", "每次受到近战生命伤害时，1 格内的活人攻击者疲劳 +5"]] },
    refined_joints = { Name = "精炼骨节", Excluded = [],
        Description = "关节被细细打磨过，铜索换成了上好的银线，动起来几乎没有声响。",
        Effects = [["ui/icons/fatigue.png", "最大疲劳 +10，每回合额外恢复 2 点疲劳"]] },
    tall_frame = { Name = "高大骨架", Excluded = ["trait.tiny"],
        Description = "这副骨架生前属于一个异常高大的人，挥起兵器来分量十足，却也更容易被打中。",
        Effects = [["ui/icons/regular_damage.png", "近战伤害 +10%"], ["ui/icons/health.png", "生命 +8"],
            ["ui/icons/melee_defense.png", "近战防御 " + ::MSU.Text.colorNegative("-5")], ["ui/icons/ranged_defense.png", "远程防御 " + ::MSU.Text.colorNegative("-5")]] },
    frail_bone = { Name = "脆化骨质", Excluded = ["trait.pale_dense_bone"],
        Description = "骨头在墓里放得太久，已经发酥发脆，一锤下去就是一片裂纹。",
        Effects = [["ui/icons/health.png", "生命 " + ::MSU.Text.colorNegative("-10")], ["ui/icons/armor_body.png", "受到的钝击伤害 " + ::MSU.Text.colorNegative("+10%")]] },
    soulfire = { Name = "魂火炽烈", Excluded = ["trait.hesitant", "trait.pale_brittle"],
        Description = "眼窝里的魂火烧得比同类更旺，总是第一个动起来。",
        Effects = [["ui/icons/initiative.png", "主动 +10"]] },
    // 1.6.18 新增 8 个负面特质（Icon 写了的用原版特质图标，没写的用 gfx/ui/traits/pale_<key>.png）
    stiff_corpse = { Name = "僵直尸身", Excluded = ["trait.quick", "trait.dexterous", "trait.pale_soulfire"], Icon = "ui/traits/trait_icon_25.png",
        Description = "尸僵从没真正褪去，关节像冻住的门轴，每个动作都慢半拍。",
        Effects = [["ui/icons/initiative.png", "主动 " + ::MSU.Text.colorNegative("-15")], ["ui/icons/melee_defense.png", "近战防御 " + ::MSU.Text.colorNegative("-3")]] },
    broken_fingers = { Name = "残缺手指", Excluded = ["trait.strong", "trait.pale_gnawing"], Icon = "ui/traits/trait_icon_35.png",
        Description = "几根手指早已烂掉，剩下的勉强攥住兵器，砍下去总是使不上劲。",
        Effects = [["ui/icons/regular_damage.png", "近战伤害 " + ::MSU.Text.colorNegative("-10%")]] },
    maggot_ridden = { Name = "蛆虫蛀空", Excluded = ["trait.tough", "trait.pale_salted", "trait.pale_embalmed", "trait.pale_putrid"], Icon = "ui/traits/trait_icon_59.png",
        Description = "蛆虫在它的腹腔里筑了巢，皮肉底下空了一大块，一刀就能捅穿。",
        Effects = [["ui/icons/health.png", "生命上限 " + ::MSU.Text.colorNegative("-10%")]] },
    loose_skull = { Name = "松脱颅骨", Excluded = ["trait.iron_jaw", "trait.pale_hollow_skull"], Icon = "ui/traits/trait_icon_12.png",
        Description = "连着颈骨的铜丝早就锈断了，颅骨只是搁在上面，一碰就晃。",
        Effects = [["ui/icons/armor_head.png", "头部受到的伤害 " + ::MSU.Text.colorNegative("+15%")]] },
    cracked_ribs = { Name = "裂纹肋骨", Excluded = ["trait.pale_dense_bone", "trait.pale_frail_bone"],
        Description = "胸廓上布满细密的裂纹，再挨几下重击就会整片塌下去。",
        Effects = [["ui/icons/armor_body.png", "身体受到的伤害 " + ::MSU.Text.colorNegative("+10%")]] },
    rusted_pins = { Name = "锈蚀骨钉", Excluded = ["trait.athletic", "trait.pale_refined_joints", "trait.pale_brittle"],
        Description = "固定骨节的铁钉锈成了一团，每动一下都要多费一份力气。",
        Effects = [["ui/icons/fatigue.png", "最大疲劳 " + ::MSU.Text.colorNegative("-10") + "，每回合疲劳恢复 " + ::MSU.Text.colorNegative("-2")]] },
    dim_soulfire = { Name = "魂火黯淡", Excluded = ["trait.quick", "trait.eagle_eyes", "trait.pale_soulfire"], Icon = "ui/traits/trait_icon_40.png",
        Description = "眼窝里只剩一点将熄的余烬，它看不远，也总是最后一个动起来。",
        Effects = [["ui/icons/initiative.png", "主动 " + ::MSU.Text.colorNegative("-10")], ["ui/icons/vision.png", "视野 " + ::MSU.Text.colorNegative("-1")]] },
    forgotten_drill = { Name = "遗忘武艺", Excluded = ["trait.bright", "trait.pale_old_drill"],
        Description = "生前学过的招式早已随魂魄散尽，它挥舞兵器的样子和村夫抡锄头没什么两样。",
        Effects = [["ui/icons/melee_skill.png", "近战技能 " + ::MSU.Text.colorNegative("-5")], ["ui/icons/ranged_skill.png", "远程技能 " + ::MSU.Text.colorNegative("-5")]] }
};

// 队伍里等级最高的亡灵法师（导师或死灵法师背景，可并列）中有人学会死灵精通
S.undeadTraitsPurified <- function()
{
    local best = -1;
    local mastered = false;
    foreach (bro in ::World.getPlayerRoster().getAll())
    {
        local skills = bro.getSkills();
        if (!skills.hasSkill(this.Chief) && !skills.hasSkill("background.bgp_necromancer"))
            continue;
        local level = bro.getLevel();
        local has = skills.hasSkill("perk.bgp_necro_mastery");
        if (level > best)
        {
            best = level;
            mastered = has;
        }
        else if (level == best && has)
            mastered = true;
    }
    return mastered;
};

S.isNegativeUndeadTrait <- function( _id )
{
    return this.UndeadNegativeTraits.find(_id) != null;
};

// 待选名单里已生成的亡灵：换成没有负面特质的版本（去掉负面特质，去完没有特质时补 1 个）
S.purgeNegativeUndeadTraits <- function( _bro )
{
    local flags = _bro.getFlags();
    if (flags.has("PaleTraitsPurified"))
        return;
    flags.set("PaleTraitsPurified", true);
    local skills = _bro.getSkills();
    local removed = false;
    foreach (trait in skills.query(::Const.SkillType.Trait))
        if (this.isNegativeUndeadTrait(trait.getID()))
        {
            skills.removeByID(trait.getID());
            removed = true;
        }
    if (!removed)
        return;
    skills.collectGarbage();
    local kind = this.UndeadKinds[this.undeadKindOf(flags.get("PaleUndeadKind"))];
    local left = 0;
    foreach (trait in skills.query(::Const.SkillType.Trait))
        if (!trait.isHidden())
            ++left;
    if (left == 0)
        this.addUndeadTraits(_bro, kind.Skeleton, 1);
    // 头衔来自被去掉的负面特质时重新挑一个
    local titleTrait = flags.has("PaleTitleTrait") ? flags.get("PaleTitleTrait") : null;
    if (titleTrait != null && !skills.hasSkill(titleTrait))
        this.assignUndeadTitle(_bro);
    skills.update();
};

// 随机加 1–2 个特质（40% 两个），互斥的不会同时出现
S.addUndeadTraits <- function( _bro, _skeleton, _count = null, _purify = true )
{
    local pool = clone this.UndeadTraitPool.Both;
    pool.extend(_skeleton ? this.UndeadTraitPool.Skeleton : this.UndeadTraitPool.Zombie);
    local count = _count != null ? _count : ::Math.rand(1, 100) <= 40 ? 2 : 1;
    local purified = false;
    try { purified = _purify && this.undeadTraitsPurified(); } catch (e) { purified = false; }
    local added = [];
    while (added.len() < count && pool.len() > 0)
    {
        local script = pool.remove(::Math.rand(0, pool.len() - 1));
        local trait = null;
        try { trait = ::new("scripts/skills/traits/" + script); } catch (e) { trait = null; }
        if (trait == null || _bro.getSkills().hasSkill(trait.getID()) || (purified && this.isNegativeUndeadTrait(trait.getID())))
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

// 1.6.22 头衔与特质挂钩：有表里的特质时 70% 从这些头衔里挑（行尸 / 骷髅 / 骷髅弓手各一列）
S.UndeadTraitTitles <- {
    ["trait.pale_sleepless"] = { zombie = "不眠尸卫", skeleton = "长夜骨哨", archer = "不眠弓骸" },
    ["trait.pale_grudge"] = { zombie = "怨念死士", skeleton = "含恨枯骨", archer = "怨火射手" },
    ["trait.pale_soulfire"] = { zombie = "炽魂行尸", skeleton = "炽魂骨卒", archer = "炽魂射手" },
    ["trait.pale_dim_soulfire"] = { zombie = "残烛行尸", skeleton = "残烛骸骨", archer = "残烛弓骸" },
    ["trait.pale_forgotten_drill"] = { zombie = "失忆尸卒", skeleton = "忘武骨兵", archer = "忘弦弓骨" },
    ["trait.pale_salted"] = { zombie = "盐腌重尸" },
    ["trait.pale_gnawing"] = { zombie = "噬咬行尸" },
    ["trait.pale_deathgrip"] = { zombie = "铁握尸卒" },
    ["trait.pale_putrid"] = { zombie = "烂肉行尸" },
    ["trait.pale_embalmed"] = { zombie = "精腌尸卫" },
    ["trait.pale_thick_hide"] = { zombie = "硬痂尸兵" },
    ["trait.pale_toxic_flesh"] = { zombie = "毒血行尸" },
    ["trait.pale_stiff_corpse"] = { zombie = "僵直尸卒" },
    ["trait.pale_broken_fingers"] = { zombie = "残指尸兵" },
    ["trait.pale_maggot_ridden"] = { zombie = "蛆巢行尸" },
    ["trait.pale_dense_bone"] = { skeleton = "石骨卫卒", archer = "石骨弓手" },
    ["trait.pale_hollow_skull"] = { skeleton = "空颅骨兵", archer = "空颅射手" },
    ["trait.pale_old_drill"] = { skeleton = "老练骨卒", archer = "老练弓骨" },
    ["trait.pale_legion_discipline"] = { skeleton = "军团骨卫", archer = "军团弓卒" },
    ["trait.pale_brittle"] = { skeleton = "朽节骸骨", archer = "朽节弓骸" },
    ["trait.pale_refined_joints"] = { skeleton = "银线骨卒", archer = "银线射手" },
    ["trait.pale_tall_frame"] = { skeleton = "长骨巨卒", archer = "长臂弓骸" },
    ["trait.pale_frail_bone"] = { skeleton = "酥骨残兵", archer = "酥骨弓骸" },
    ["trait.pale_loose_skull"] = { skeleton = "松颅骸骨", archer = "松颅弓骨" },
    ["trait.pale_cracked_ribs"] = { skeleton = "裂肋骨兵", archer = "裂肋弓骸" },
    ["trait.pale_rusted_pins"] = { skeleton = "锈钉枯骨", archer = "锈钉弓骸" },
    ["trait.iron_jaw"] = { zombie = "铁颌尸卒", skeleton = "铁颌骨兵", archer = "铁颌弓骸" },
    ["trait.eagle_eyes"] = { zombie = "鹰眼行尸", skeleton = "鹰眼骨哨", archer = "鹰眼神射" },
    ["trait.clumsy"] = { zombie = "笨手尸奴", skeleton = "笨拙骨卒", archer = "拙手弓骸" },
    ["trait.dexterous"] = { zombie = "巧手行尸", skeleton = "灵指骨卒", archer = "灵指射手" },
    ["trait.sure_footing"] = { zombie = "稳步尸卫", skeleton = "稳足骨卒", archer = "稳足弓骸" },
    ["trait.quick"] = { zombie = "疾步行尸", skeleton = "疾骨骨卒", archer = "疾弦射手" },
    ["trait.strong"] = { zombie = "蛮力尸卒", skeleton = "重骨骨兵", archer = "强弓骸骨" },
    ["trait.lucky"] = { zombie = "命硬行尸", skeleton = "不散骸骨", archer = "福星弓骨" },
    ["trait.bloodthirsty"] = { zombie = "嗜血行尸", skeleton = "嗜血骸骨", archer = "嗜血射手" },
    ["trait.brute"] = { zombie = "蛮横尸卒", skeleton = "粗野骨兵", archer = "粗野弓骸" },
    ["trait.bright"] = { zombie = "机敏行尸", skeleton = "慧眼骨卒", archer = "慧眼射手" },
    ["trait.dumb"] = { zombie = "呆滞行尸", skeleton = "痴骨骨卒", archer = "痴骨弓骸" },
    ["trait.huge"] = { zombie = "巨躯行尸" },
    ["trait.tough"] = { zombie = "铁皮尸卫" },
    ["trait.fat"] = { zombie = "臃肿行尸" },
    ["trait.clubfooted"] = { zombie = "跛足行尸" },
    ["trait.iron_lungs"] = { zombie = "铁肺尸卒" },
    ["trait.tiny"] = { skeleton = "矮小骨卒", archer = "矮小弓骸" },
    ["trait.fragile"] = { skeleton = "薄骨残兵", archer = "薄骨弓骸" },
    ["trait.athletic"] = { skeleton = "健骨骨卒", archer = "健骨弓手" }
};

S.undeadTitleFamily <- function( _bro )
{
    local kind = this.undeadKindOf(_bro.getFlags().get("PaleUndeadKind"));
    return kind == "archer" ? "archer" : kind == "zombie" ? "zombie" : "skeleton";
};

S.assignUndeadTitle <- function( _bro )
{
    local family = this.undeadTitleFamily(_bro);
    local picks = [];
    foreach (trait in _bro.getSkills().query(::Const.SkillType.Trait))
    {
        local id = trait.getID();
        if (id in this.UndeadTraitTitles && family in this.UndeadTraitTitles[id])
            picks.push([id, this.UndeadTraitTitles[id][family]]);
    }
    local flags = _bro.getFlags();
    if (picks.len() > 0 && ::Math.rand(1, 100) <= 70)
    {
        local pick = picks[::Math.rand(0, picks.len() - 1)];
        _bro.setTitle(pick[1]);
        flags.set("PaleTitleTrait", pick[0]);
        return;
    }
    local titles = family == "archer" ? this.ArcherTitles : family == "zombie" ? this.ZombieTitles : this.SkeletonTitles;
    _bro.setTitle(titles[::Math.rand(0, titles.len() - 1)]);
    flags.remove("PaleTitleTrait");
};

// 生成一名常驻亡灵：属性按背景范围随机，抽天赋星和特质
// _purify = false：不受“死灵精通后无负面特质”影响（受缚亡灵）
S.createUndead <- function( _kind, _roster = null, _purify = true )
{
    local kind = this.UndeadKinds[this.undeadKindOf(_kind)];
    local bro = this.spawnBrother(kind.Background, kind.Gear, -1, false, _roster);
    bro.getFlags().set("PaleUndeadKind", this.undeadKindOf(_kind));
    bro.getFlags().set("PalePermanentUndead", true);
    bro.getFlags().set("undead", true);
    try { bro.fillTalentValues(); } catch (e) { ::logError("[PaleSovereign] 常驻亡灵天赋: " + e); }
    this.addUndeadTraits(bro, kind.Skeleton, null, _purify);
    bro.fillAttributeLevelUpValues(::Const.XP.MaxLevelWithPerkpoints - 1);
    this.assignUndeadTitle(bro);
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
    this.createUndead(_item.m.PaleKind, null, false);
    ::World.Assets.updateFormation(true);
    return true;
};

// 精良防腐：战斗中受到死灵技能（BGP.heal）的治疗 +25%
local bgpHeal = ::BGP.heal;
::BGP.heal = function( _a, _amount )
{
    try
    {
        if (_amount > 0 && _a.getSkills().hasSkill("trait.pale_embalmed"))
            _amount = ::Math.floor(_amount * 1.25);
    }
    catch (e)
    {
    }
    return bgpHeal(_a, _amount);
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
    _screen.Text = "在 " + site.Name + " 选择要从盐封棺里唤起的亡灵，花费 " + this.recruitCost() + " 点防腐尸骸，每处登记地点只能征召一次。属性按种类在范围内随机，另有天赋星和 1–2 个特质，升阶后特质保留。"
        + (this.undeadTraitsPurified() ? "队伍里等级最高的亡灵法师已学会死灵精通，新唤起的亡灵不会带负面特质。" : "队伍里等级最高的亡灵法师学会死灵精通后，新唤起的亡灵不再带负面特质。");
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

// 1.6.12 亡者之城和古堡兵营的待选名单：每处 8 名（尸妖王侍卫长 2 级时 16 名），每 7 天刷新，征召后从名单移除。
// 待选亡灵放在每处地点自己的花名册里（编号存在城镇标记 PaleRecruitRoster），和要塞模组存放本地花名册的做法相同。
S.RecruitPoolDays <- 7;
S.RecruitPerPage <- 4;
S.RecruitPage <- 0;
S.RecruitTalentNames <- [
    ["Hitpoints", "生命"], ["Bravery", "决心"], ["Fatigue", "体力"], ["Initiative", "主动"],
    ["MeleeSkill", "近战"], ["RangedSkill", "远程"], ["MeleeDefense", "近防"], ["RangedDefense", "远防"]
];

S.recruitPoolSize <- function()
{
    return this.followerRank("wight_captain") >= 2 ? 16 : 8;
};

S.recruitRoster <- function( _town, _create )
{
    local flags = _town.getFlags();
    local id = flags.getAsInt("PaleRecruitRoster");
    local roster = null;
    if (id != 0)
    {
        try { roster = ::World.getRoster(id); } catch (e) { roster = null; }
    }
    if (roster == null && _create)
    {
        id = ::Math.rand(100000000, 999999999);
        roster = ::World.createRoster(id);
        flags.set("PaleRecruitRoster", id);
        flags.set("PaleRecruitDay", -100);
        flags.set("PaleRecruitSize", 0);
    }
    return roster;
};

S.clearRecruitPool <- function( _town )
{
    local roster = this.recruitRoster(_town, false);
    if (roster != null)
        roster.clear();
    _town.getFlags().set("PaleRecruitDay", -100);
    _town.getFlags().set("PaleRecruitSize", 0);
};

// 到期刷新；侍卫长升到 2 级后，本期名单当场补足到 16 名
S.recruitPool <- function( _town )
{
    local roster = this.recruitRoster(_town, true);
    local flags = _town.getFlags();
    local day = ::World.getTime().Days;
    if (day >= flags.getAsInt("PaleRecruitDay") + this.RecruitPoolDays)
    {
        roster.clear();
        flags.set("PaleRecruitDay", day);
        flags.set("PaleRecruitSize", 0);
    }
    local made = flags.getAsInt("PaleRecruitSize");
    local size = this.recruitPoolSize();
    for (local i = made; i < size; ++i)
    {
        // 新一期的前 3 名各是一种亡灵，其余随机
        local kind = i < this.UndeadKindOrder.len() ? this.UndeadKindOrder[i] : this.UndeadKindOrder[::Math.rand(0, this.UndeadKindOrder.len() - 1)];
        try { this.createUndead(kind, roster); } catch (e) { ::logError("[PaleSovereign] 待选亡灵: " + e); }
    }
    if (made < size)
        flags.set("PaleRecruitSize", size);
    local list = roster.getAll();
    if (this.undeadTraitsPurified())
        foreach (bro in list)
            this.purgeNegativeUndeadTraits(bro);
    local order = this.UndeadKindOrder;
    list.sort(function( _a, _b )
    {
        local ka = order.find(S.undeadKindOf(_a.getFlags().get("PaleUndeadKind")));
        local kb = order.find(S.undeadKindOf(_b.getFlags().get("PaleUndeadKind")));
        return ka != kb ? ka <=> kb : _a.getID() <=> _b.getID();
    });
    return list;
};

S.joinRecruitText <- function( _parts )
{
    if (_parts.len() == 0)
        return "无";
    local text = _parts[0];
    for (local i = 1; i < _parts.len(); ++i)
        text += "、" + _parts[i];
    return text;
};

S.recruitCandidateText <- function( _bro, _index )
{
    local kind = this.UndeadKinds[this.undeadKindOf(_bro.getFlags().get("PaleUndeadKind"))];
    local text = _index + ". " + _bro.getName() + "（" + kind.Name + "）";
    try
    {
        local p = _bro.getCurrentProperties();
        text += "\n生命 " + _bro.getHitpointsMax() + "　决心 " + p.getBravery() + "　体力 " + _bro.getFatigueMax() + "　主动 " + p.getInitiative()
            + "\n近战 " + p.getMeleeSkill() + "　远程 " + p.getRangedSkill() + "　近防 " + p.getMeleeDefense() + "　远防 " + p.getRangedDefense();
    }
    catch (e)
    {
    }
    local stars = [];
    try
    {
        local talents = _bro.getTalents();
        foreach (entry in this.RecruitTalentNames)
        {
            local index = ::Const.Attributes[entry[0]];
            if (index < talents.len() && talents[index] > 0)
            {
                local mark = "";
                for (local i = 0; i < talents[index]; ++i)
                    mark += "★";
                stars.push(entry[1] + mark);
            }
        }
    }
    catch (e)
    {
    }
    text += "\n天赋：" + this.joinRecruitText(stars);
    local traits = [];
    foreach (trait in _bro.getSkills().query(::Const.SkillType.Trait))
        if (!trait.isHidden())
            traits.push(trait.getName());
    text += "\n特质：" + this.joinRecruitText(traits);
    return text;
};

S.recruitCandidate <- function( _town, _bro, _price, _levels )
{
    local roster = this.recruitRoster(_town, false);
    if (roster == null || !this.canRecruitUndead(null, _price) || roster.getAll().find(_bro) == null)
        return false;
    ::World.getPlayerRoster().add(_bro);
    roster.remove(_bro);
    _bro.m.HireTime = ::Time.getVirtualTimeF();
    this.changeReserve(-_price);
    if (_levels > 0)
        this.castleTrain(_bro, _levels);
    _bro.setHitpointsPct(1.0);
    ::World.Assets.updateFormation(true);
    return true;
};

// 亡者之城（_levels = 0）与古堡兵营（升级后 _levels = 2）共用的名单页
S.recruitPoolPanel <- function( _screen, _town, _price, _levels )
{
    local list = this.recruitPool(_town);
    local per = this.RecruitPerPage;
    local page = ::Math.max(0, ::Math.min(this.RecruitPage, (list.len() - 1) / per));
    local nextDay = _town.getFlags().getAsInt("PaleRecruitDay") + this.RecruitPoolDays;
    _screen.Text += "\n\n待选亡灵 " + list.len() + " 名，每名 " + _price + " 点防腐尸骸（现有 " + this.get("Reserve") + " 点）"
        + (_levels > 0 ? "，征召后起始等级 +" + _levels : "") + "。名单每 " + this.RecruitPoolDays + " 天刷新，还有 " + ::Math.max(1, nextDay - ::World.getTime().Days) + " 天。"
        + (this.followerRank("wight_captain") >= 2 ? "尸妖王侍卫长在场，名单扩充到 16 名。" : "");
    if (list.len() == 0)
    {
        _screen.Text += "\n\n本期名单已经征召完了。";
        return;
    }
    local canRecruit = this.canRecruitUndead(null, _price);
    if (!canRecruit)
        _screen.Text += "\n\n防腐尸骸不足、常驻亡灵已达上限或战团已满，暂时无法征召。";
    local pageID = _screen.ID;
    for (local i = page * per; i < ::Math.min(list.len(), (page + 1) * per); ++i)
    {
        local bro = list[i];
        _screen.Text += "\n\n" + this.recruitCandidateText(bro, i + 1);
        if (!canRecruit)
            continue;
        local kindName = this.UndeadKinds[this.undeadKindOf(bro.getFlags().get("PaleUndeadKind"))].Name;
        this.option(_screen, "征召 " + (i + 1) + " 号 · " + kindName + "（" + _price + " 点尸骸）", function()
        {
            local name = bro.getName();
            return S.recruitCandidate(_town, bro, _price, _levels) ? name + " 从盐封棺中站起，加入了战团。" : "无法征召。";
        });
    }
    if (page > 0)
        this.option(_screen, "上一页", function() { S.RecruitPage = page - 1; return "@" + pageID; });
    if ((page + 1) * per < list.len())
        this.option(_screen, "下一页", function() { S.RecruitPage = page + 1; return "@" + pageID; });
};

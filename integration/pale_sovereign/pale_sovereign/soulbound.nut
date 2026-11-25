// 锁魂者：亡灵天灾用缚魂锁链复活亡灵强敌，战后收编进名册；缚魂镣铐
local S = ::PaleSovereign;

// 五类锁魂者。Scripts 是死者类名（复活后的 bgp_undead_ 类会去掉前缀再比对）
S.SoulboundClasses <- {
    legion = {
        Name = "古帝军团", Skeleton = true, Look = "grave_guard",
        Description = "古帝国军团的残兵被黑铁锁链重新钉进了队列。它仍记得盾牌该举多高、该与哪位同袍肩并着肩。",
        Scripts = ["skeleton_heavy", "skeleton_heavy_bodyguard", "skeleton_heavy_polearm", "rf_skeleton_heavy_elite",
            "rf_skeleton_heavy_elite_bodyguard", "rf_skeleton_medium_elite", "rf_skeleton_medium_elite_polearm",
            "rf_skeleton_legatus", "rf_skeleton_centurion", "rf_skeleton_decanus"],
        Groups = [["sword", "polearm"], ["shield", "power"], ["heavy_armor", "medium_armor"], ["tough", "trained"]],
        Excluded = ["bow", "crossbow", "throwing", "ranged", "dagger", "light_armor"],
        Weighted = ["spear", "mace"],
        Tree = [
            ["perk.shield_expert", "perk.fortified_mind"],
            ["perk.rf_rebuke", "perk.rf_entrenched"],
            ["perk.rf_phalanx", "perk.steel_brow"],
            ["perk.battle_forged", "perk.indomitable"],
            ["perk.rf_shield_sergeant", "perk.rf_strength_in_numbers"],
            ["perk.rf_line_breaker", "perk.hold_out"],
            ["perk.pale_sb_eternal_legion"]
        ]
    },
    knight = {
        Name = "堕落骑士", Skeleton = false, Look = "dread_corpse_lord",
        Description = "锈死的板甲里仍裹着一具不肯腐烂的骑士躯体。锁链勒进它的护喉，它便把那份旧日的冲锋之力交给了导师。",
        Scripts = ["zombie_knight", "zombie_knight_bodyguard", "rf_zombie_hero", "rf_zombie_hero_bodyguard"],
        Groups = [["sword", "axe"], ["power", "shield"], ["heavy_armor", "medium_armor"], ["unstoppable", "tough"]],
        Excluded = ["bow", "crossbow", "throwing", "ranged", "dagger", "light_armor", "swift"],
        Weighted = ["hammer", "mace", "flail"],
        Tree = [
            ["perk.rf_formidable_approach", "perk.rf_dismantle"],
            ["perk.rf_death_dealer", "perk.rf_sweeping_strikes"],
            ["perk.battle_forged", "perk.rf_man_of_steel"],
            ["perk.killing_frenzy", "perk.rf_vanquisher"],
            ["perk.colossus", "perk.rf_unstoppable"],
            ["perk.reach_advantage", "perk.rf_the_rush_of_battle"],
            ["perk.pale_sb_death_ride"]
        ]
    },
    barrow = {
        Name = "墓穴恶鬼", Skeleton = false, Look = "fallen_hero",
        Description = "墓冢里爬出的北地亡者，须发上还挂着冰霜。锁链没能磨掉它的狂怒，只是替这份狂怒指定了方向。",
        Scripts = ["rf_draugr_huskarl", "rf_draugr_huskarl_bodyguard", "rf_draugr_hero"],
        Groups = [["axe", "cleaver"], ["power", "swift"], ["medium_armor", "heavy_armor"], ["vicious", "unstoppable"]],
        Excluded = ["bow", "crossbow", "throwing", "ranged", "dagger"],
        Weighted = ["hammer", "flail", "spear"],
        Tree = [
            ["perk.rf_feral_rage", "perk.colossus"],
            ["perk.overwhelm", "perk.rf_exploit_opening"],
            ["perk.rf_formidable_approach", "perk.rf_menacing"],
            ["perk.rf_vanquisher", "perk.berserk"],
            ["perk.killing_frenzy", "perk.rf_bloodlust"],
            ["perk.rf_savage_strength", "perk.battle_forged"],
            ["perk.pale_sb_barrow_lord"]
        ]
    },
    hex = {
        Name = "禁咒师", Skeleton = true, Look = "skeleton_king",
        Description = "祭司与先知的禁咒刻在它的骨头上。它不再为自己的神祇吟唱，而是用那些古老的音节扼住生者的胆气。",
        Scripts = ["skeleton_priest", "rf_draugr_shaman"],
        Groups = [["polearm", "dagger"], ["swift", "shield"], ["light_armor", "medium_armor"], ["tactician", "fast"]],
        Excluded = ["bow", "crossbow", "throwing", "ranged", "heavy_armor"],
        Weighted = ["spear", "mace"],
        Tree = [
            ["perk.pale_sb_barrow_chant", "perk.fortified_mind"],
            ["perk.rf_terrifying_visage", "perk.rf_menacing"],
            ["perk.pale_sb_necro_attune", "perk.rally_the_troops"],
            ["perk.pale_sb_blinding_hex", "perk.fearsome"],
            ["perk.inspiring_presence", "perk.rf_exude_confidence"],
            ["perk.anticipation", "perk.dodge"],
            ["perk.pale_sb_hex_domain"]
        ]
    },
    blood = {
        Name = "血族", Skeleton = false, Look = "tomb_blademaster",
        Description = "暗夜的捕食者被锁链拴在了导师的阴影里。它依旧渴血，只是现在由别人决定它该咬向谁的喉咙。",
        Scripts = ["vampire", "vampire_low", "rf_vampire_lord"],
        Groups = [["sword", "cleaver"], ["swift", "power"], ["light_armor", "medium_armor"], ["agile", "fast"]],
        Excluded = ["bow", "crossbow", "throwing", "ranged", "shield", "heavy_armor"],
        Weighted = ["dagger", "axe"],
        Tree = [
            ["perk.pale_sb_blood_thirst", "perk.dodge"],
            ["perk.pale_sb_night_walker", "perk.footwork"],
            ["perk.rf_exploit_opening", "perk.duelist"],
            ["perk.rf_double_strike", "perk.nimble"],
            ["perk.rf_formidable_approach", "perk.rf_between_the_ribs"],
            ["perk.backstabber", "perk.killing_frenzy"],
            ["perk.pale_sb_blood_feast"]
        ]
    }
};
S.SoulboundOrder <- ["legion", "knight", "barrow", "hex", "blood"];
S.SoulboundStatKeys <- ["Hitpoints", "MeleeSkill", "MeleeDefense", "RangedDefense", "Initiative", "Stamina"];
S.SoulboundStatNames <- ["生命", "近战技能", "近战防御", "远程防御", "主动性", "体力"];
S.SoulboundStatMult <- 0.8;

// 锁魂者专属特技
S.SoulPerks <- {
    eternal_legion = { Name = "永恒军团", Icon = "skills/pale_sb_eternal_legion",
        Description = "每有 1 名相邻的友方亡灵，受到的伤害 −8%，最多 −32%。" },
    death_ride = { Name = "亡骑冲阵", Icon = "skills/pale_sb_death_ride",
        Description = "每场战斗的第一次攻击伤害 +30%；命中时目标士气下降一级。" },
    barrow_lord = { Name = "墓穴之主", Icon = "skills/pale_sb_barrow_lord",
        Description = "每回合开始时恢复 25 点生命。生命每比上限低 10%，造成的伤害 +10%。" },
    hex_domain = { Name = "禁咒领域", Icon = "skills/pale_sb_hex_domain",
        Description = "每回合开始时，3 格内所有敌人的近战技能、远程技能、决心各 −10，持续到它们下一回合结束。" },
    blood_feast = { Name = "血宴", Icon = "skills/pale_sb_blood_feast",
        Description = "每击杀 1 名敌人，本场战斗造成的伤害 +5%、主动性 +20，可无限叠加。" },
    barrow_chant = { Name = "墓穴挽歌", Icon = "skills/pale_sb_barrow_chant",
        Description = "每回合开始时，3 格内的敌人受挽歌影响直到其下一回合结束：士气每低于稳定一级，造成的伤害 −10%。" },
    necro_attune = { Name = "死灵共鸣", Icon = "skills/pale_sb_necro_attune",
        Description = "此人在场时，战团复活的亡灵生命上限 +10。" },
    blinding_hex = { Name = "致盲禁咒", Icon = "skills/pale_sb_blinding_hex",
        Description = "攻击命中后目标陷入致盲：近战技能、远程技能 −15，持续到其下一回合结束。" },
    blood_thirst = { Name = "血之渴", Icon = "skills/pale_sb_blood_thirst",
        Description = "攻击造成生命伤害时，恢复造成伤害 35% 的生命。" },
    night_walker = { Name = "夜行", Icon = "skills/pale_sb_night_walker",
        Description = "夜战时主动性 +20。" }
};

local perkDefs = [];
foreach (key, def in S.SoulPerks)
{
    perkDefs.push({
        ID = "perk.pale_sb_" + key,
        Script = "scripts/skills/perks/perk_pale_sb_" + key,
        Name = def.Name,
        Tooltip = def.Description,
        Icon = def.Icon + ".png",
        IconDisabled = def.Icon + "_sw.png"
    });
}
::DynamicPerks.Perks.addPerks(perkDefs);

// Register each Soulbound class's curated perks as an exclusive DynamicPerks perk group (weight 0).
local exclusiveCol = ::DynamicPerks.PerkGroupCategories.findById("pgc.rf_exclusive_1");
foreach (cls in S.SoulboundOrder)
{
    try
    {
        local group = ::new("scripts/mods/mod_pale_sovereign/perk_groups/pg_pale_sb_" + cls);
        if (::DynamicPerks.PerkGroups.findById(group.getID()) == null)
            ::DynamicPerks.PerkGroups.add(group);
        if (exclusiveCol != null && exclusiveCol.getGroups().find(group.getID()) == null)
            exclusiveCol.addPerkGroup(group.getID());
    }
    catch (e)
    {
        ::logError("[PaleSovereign] register soulbound perk group " + cls + ": " + e);
    }
}

// ---------------------------------------------------------------------------
// 识别
// ---------------------------------------------------------------------------
S.soulClassOfScript <- function( _script )
{
    if (_script == null || _script == "")
        return null;
    local fileName = this.scriptBase(_script);
    if (fileName.find("bgp_undead_") == 0)
        fileName = fileName.slice(11);
    foreach (key in this.SoulboundOrder)
        if (this.SoulboundClasses[key].Scripts.find(fileName) != null)
            return key;
    return null;
};

S.soulClassOfCorpse <- function( _corpse )
{
    local info = ::BGP.Necro.getInfo(_corpse);
    return info == null || info.IsHuman ? null : this.soulClassOfScript(info.Script);
};

S.isSoulbound <- function( _bro )
{
    return _bro != null && _bro.getFlags().has("PaleSoulbound");
};

// 死亡记录里加上是否冠军，锁魂复生时据此恢复冠军词条
local makeDeathInfo = ::BGP.Necro.makeDeathInfo;
::BGP.Necro.makeDeathInfo = function( _actor )
{
    local info = makeDeathInfo(_actor);
    try { info.IsChampion <- _actor.getSkills().hasSkill("racial.champion"); } catch (e) { info.IsChampion <- false; }
    return info;
};

// ---------------------------------------------------------------------------
// 战斗中：锁魂复生
// ---------------------------------------------------------------------------
S.bindSoul <- function( _entity, _class, _info )
{
    _entity.getFlags().set("PaleSoulbound", _class);
    if (_info != null && "IsChampion" in _info && _info.IsChampion)
    {
        try { _entity.makeMiniboss(); } catch (e) {}
    }
    _entity.getSkills().update();
    _entity.setHitpoints(_entity.getHitpointsMax());
    if (this.Battle != null)
    {
        this.Battle.SoulUsed = true;
        this.Battle.Soulbound.push({ Entity = _entity, Class = _class });
    }
};

S.hasAttunedSoul <- function()
{
    foreach (bro in ::World.getPlayerRoster().getAll())
        if (bro.isPlacedOnMap() && bro.isAlive() && !bro.isDying() && bro.getSkills().hasSkill("perk.pale_sb_necro_attune"))
            return true;
    return false;
};

local raiseSoul = ::BGP.Necro.raise;
::BGP.Necro.raise = function( _actor, _tile )
{
    local entity = raiseSoul(_actor, _tile);
    if (entity != null && S.Battle != null && _actor != null && _actor.isPlayerControlled() && S.hasAttunedSoul())
    {
        entity.getBaseProperties().Hitpoints += 10;
        entity.getSkills().update();
        entity.setHitpoints(::Math.min(entity.getHitpointsMax(), entity.getHitpoints() + 10));
    }
    return entity;
};

// 战斗胜利时（单位还在场上）记下存活的锁魂者
S.pickLegacyPerk <- function( _entity )
{
    local options = [];
    foreach (skill in _entity.getSkills().m.Skills)
    {
        if (skill.isGarbage() || !skill.isType(::Const.SkillType.Perk) || !::MSU.isNull(skill.getItem()))
            continue;
        local id = skill.getID();
        if (id.find("perk.pale_") == 0 || id.find("perk.bgp_") == 0)
            continue;
        local script = "";
        try { script = ::IO.scriptFilenameByHash(skill.ClassNameHash); } catch (e) { script = ""; }
        if (script != "")
            options.push({ Script = script, Name = skill.getName() });
    }
    return options.len() == 0 ? { Script = "", Name = "" } : options[::Math.rand(0, options.len() - 1)];
};

S.captureSoulbound <- function()
{
    if (this.Battle == null || !("Soulbound" in this.Battle))
        return;
    local list = this.soulboundPending();
    local added = 0;
    foreach (entry in this.Battle.Soulbound)
    {
        local entity = entry.Entity;
        if (entity == null || ::MSU.isNull(entity) || !entity.isAlive() || entity.isDying())
            continue;
        local props = entity.getBaseProperties();
        local stats = [];
        foreach (key in this.SoulboundStatKeys)
            stats.push(::Math.max(1, ::Math.floor(props[key] * this.SoulboundStatMult)));
        local items = [];
        foreach (slot in [::Const.ItemSlot.Mainhand, ::Const.ItemSlot.Offhand, ::Const.ItemSlot.Head, ::Const.ItemSlot.Body])
        {
            local item = entity.getItems().getItemAtSlot(slot);
            if (item == null)
                continue;
            try { items.push(::IO.scriptFilenameByHash(item.ClassNameHash)); } catch (e) {}
        }
        local legacy = this.pickLegacyPerk(entity);
        list.push({ Class = entry.Class, Name = entity.getName(), Stats = stats,
            Legacy = legacy.Script, LegacyName = legacy.Name, Items = items });
        ++added;
    }
    this.Battle.Soulbound = [];
    if (added > 0)
    {
        this.saveSoulboundPending(list);
        this.set("SBNotice", 1);
    }
};

// ---------------------------------------------------------------------------
// 待收编记录（存在 World.Flags 里，跟随存档）
// ---------------------------------------------------------------------------
S.soulboundPending <- function()
{
    local flags = ::World.Flags;
    local count = flags.getAsInt("Pale.SB.Count");
    local list = [];
    for (local i = 0; i < count; ++i)
    {
        local key = "Pale.SB." + i + ".";
        local stats = [];
        foreach (part in split(flags.get(key + "Stats"), ","))
            stats.push(part.tointeger());
        local itemText = flags.get(key + "Items");
        local items = typeof itemText == "string" && itemText != "" ? split(itemText, ";") : [];
        local legacy = flags.get(key + "Legacy");
        local legacyName = flags.get(key + "LegacyName");
        list.push({ Class = flags.get(key + "Class"), Name = flags.get(key + "Name"), Stats = stats,
            Legacy = typeof legacy == "string" ? legacy : "", LegacyName = typeof legacyName == "string" ? legacyName : "", Items = items });
    }
    return list;
};

S.saveSoulboundPending <- function( _list )
{
    local flags = ::World.Flags;
    local old = flags.getAsInt("Pale.SB.Count");
    for (local i = 0; i < old; ++i)
        foreach (field in ["Class", "Name", "Stats", "Legacy", "LegacyName", "Items"])
            flags.remove("Pale.SB." + i + "." + field);
    foreach (i, rec in _list)
    {
        local key = "Pale.SB." + i + ".";
        local stats = "";
        foreach (j, value in rec.Stats)
            stats += (j == 0 ? "" : ",") + value;
        local items = "";
        foreach (j, path in rec.Items)
            items += (j == 0 ? "" : ";") + path;
        flags.set(key + "Class", rec.Class);
        flags.set(key + "Name", rec.Name);
        flags.set(key + "Stats", stats);
        flags.set(key + "Legacy", rec.Legacy);
        flags.set(key + "LegacyName", rec.LegacyName);
        flags.set(key + "Items", items);
    }
    flags.set("Pale.SB.Count", _list.len());
};

S.dropSoulbound <- function( _index )
{
    local list = this.soulboundPending();
    if (_index < 0 || _index >= list.len())
        return "这名锁魂者已不在名单上。";
    local name = list[_index].Name;
    list.remove(_index);
    this.saveSoulboundPending(list);
    return "你松开了锁链。" + name + " 的魂火晃了晃，熄灭在夜风里。";
};

S.recruitSoulbound <- function( _index )
{
    local list = this.soulboundPending();
    if (_index < 0 || _index >= list.len())
        return "这名锁魂者已不在名单上。";
    if (::World.getPlayerRoster().getSize() >= ::World.Assets.getBrothersMax())
        return "战团编制已满，暂时无法收编。";
    local rec = list[_index];
    if (!(rec.Class in this.SoulboundClasses))
        return "这份记录已损坏。";
    local def = this.SoulboundClasses[rec.Class];
    local bro = this.spawnBrother("pale_sb_" + rec.Class + "_background", null, -1, false);
    local flags = bro.getFlags();
    flags.set("PalePermanentUndead", true);
    flags.set("undead", true);
    flags.set("PaleSoulbound", rec.Class);
    bro.setTitle(rec.Name);
    bro.m.MoraleState = ::Const.MoraleState.Ignore;

    local props = bro.getBaseProperties();
    foreach (i, key in this.SoulboundStatKeys)
        if (i < rec.Stats.len())
            props[key] = rec.Stats[i];
    props.Bravery = 120;
    props.ActionPoints = 9;
    try { bro.fillTalentValues(); } catch (e) { ::logError("[PaleSovereign] 锁魂者天赋: " + e); }
    bro.m.Attributes = [];
    bro.fillAttributeLevelUpValues(::Const.XP.MaxLevelWithPerkpoints - 1);

    local items = bro.getItems();
    foreach (item in items.getAllItems())
        items.unequip(item);
    foreach (path in rec.Items)
    {
        try { items.equip(::new(path)); } catch (e) { ::logWarning("Pale Sovereign: soulbound item " + path + " failed: " + e); }
    }

    if (rec.Legacy != "")
    {
        try
        {
            local perk = ::new(rec.Legacy);
            if (!bro.getSkills().hasSkill(perk.getID()))
            {
                perk.m.IsRefundable = false;
                bro.getSkills().add(perk);
            }
            flags.set("PaleLegacy", rec.LegacyName);
            flags.set("PaleLegacyScript", rec.Legacy);
        }
        catch (e)
        {
            ::logWarning("Pale Sovereign: soulbound legacy " + rec.Legacy + " failed: " + e);
        }
    }

    local background = bro.getBackground();
    background.buildDescription(true);
    bro.getSkills().update();
    local tree = background.createPerkTreeBlueprint();
    tree.setActor(bro);
    bro.m.PerkTree = tree;
    tree.build();

    bro.getSkills().update();
    bro.setHitpointsPct(1.0);
    this.applyUndeadLook(bro);
    ::World.Assets.updateFormation(true);
    list.remove(_index);
    this.saveSoulboundPending(list);
    return "锁链在 " + rec.Name + " 的脊骨上收紧最后一圈。它跪下，又站起，成了战团的一员。\n\n（" + def.Name + "：属性为生前的 80%"
        + (rec.LegacyName != "" ? "，保留生前特技【" + rec.LegacyName + "】" : "") + "）";
};

// Backfill missing talent stars and legacy 13-perk template trees on existing Soulbound brothers.
S.hasAnyTalent <- function( _bro )
{
    local talents = _bro.getTalents();
    if (talents == null || talents.len() == 0)
        return false;
    foreach (v in talents)
        if (v > 0)
            return true;
    return false;
};

S.repairSoulboundBro <- function( _bro )
{
    if (!this.isSoulbound(_bro))
        return false;
    local changed = false;
    if (!this.hasAnyTalent(_bro))
    {
        try
        {
            _bro.fillTalentValues();
            _bro.m.Attributes = [];
            _bro.fillAttributeLevelUpValues(::Const.XP.MaxLevelWithPerkpoints - 1);
            changed = true;
        }
        catch (e)
        {
            ::logError("[PaleSovereign] repair soulbound talents: " + e);
        }
    }
    local tree = null;
    try { tree = _bro.getPerkTree(); } catch (e) { tree = null; }
    if (tree == null || tree.getPerks().len() <= 20)
    {
        try
        {
            local bg = _bro.getBackground();
            if (bg != null && ::MSU.isKindOf(bg, "pale_soulbound_background"))
            {
                _bro.getSkills().update();
                local nextTree = bg.createPerkTreeBlueprint();
                nextTree.setActor(_bro);
                _bro.m.PerkTree = nextTree;
                nextTree.build();
                changed = true;
            }
        }
        catch (e)
        {
            ::logError("[PaleSovereign] repair soulbound perk tree: " + e);
        }
    }
    if (changed)
        try { _bro.getSkills().update(); } catch (e) {}
    return changed;
};

S.repairSoulboundRoster <- function()
{
    local roster = ::World.getPlayerRoster();
    if (roster == null)
        return 0;
    local fixed = 0;
    foreach (bro in roster.getAll())
        if (this.repairSoulboundBro(bro))
            ++fixed;
    if (fixed > 0)
        ::logInfo("[PaleSovereign] Repaired " + fixed + " existing Soulbound brother(s) (talents / perk trees).");
    return fixed;
};

S.soulboundPanel <- function( _screen )
{
    local list = this.soulboundPending();
    if (list.len() == 0)
    {
        _screen.Text = "锁链都已收起，没有等待收编的亡魂。";
        this.option(_screen, "翻阅亡者账簿", @() "@camp");
        return;
    }
    _screen.Text = "战场上被锁链拴住的亡魂没有散去，它们跟在马车后面，等待导师的裁决。收编后属性为生前的 80%，并保留 1 个生前特技。"
        + "\n战团编制　" + ::World.getPlayerRoster().getSize() + " / " + ::World.Assets.getBrothersMax();
    foreach (i, rec in list)
    {
        if (i >= 4)
            break;
        local index = i;
        local entry = rec;
        local className = entry.Class in this.SoulboundClasses ? this.SoulboundClasses[entry.Class].Name : "?";
        local stats = "";
        foreach (j, value in entry.Stats)
            if (j < this.SoulboundStatNames.len())
                stats += (j == 0 ? "" : "　") + this.SoulboundStatNames[j] + " " + value;
        _screen.Text += "\n\n" + entry.Name + "（" + className + "）\n" + stats
            + (entry.LegacyName != "" ? "\n生前特技　" + entry.LegacyName : "");
        this.option(_screen, "收编 " + entry.Name + "（" + className + "）", @() S.recruitSoulbound(index));
    }
    if (list.len() > 4)
        _screen.Text += "\n\n另有 " + (list.len() - 4) + " 名锁魂者排在后面。";
    this.option(_screen, "放走 " + list[0].Name, @() S.dropSoulbound(0));
    this.option(_screen, "稍后再决定", @() "@camp");
};

// ---------------------------------------------------------------------------
// 缚魂镣铐
// ---------------------------------------------------------------------------
// 固定 1 条缚魂锁链，另从下面六种里任选一种
S.ShackleMaterials <- [
    { ID = "misc.golden_chalice", Name = "黄金餐杯", Count = 1 },
    { ID = "misc.ancient_gold_coins", Name = "古代金币", Count = 1 },
    { ID = "misc.jeweled_crown", Name = "宝石王冠", Count = 1 },
    { ID = "misc.gemstones", Name = "宝石", Count = 1 },
    { ID = "misc.lindwurm_hoard", Name = "蠕龙珍宝", Count = 1 },
    { ID = "misc.signet_ring", Name = "纹章戒指", Count = 3 }
];

S.shackleMaterialsAvailable <- function()
{
    return this.ShackleMaterials.filter(@(_, mat) ::PaleSovereign.countItems(mat.ID) >= mat.Count);
};

S.canForgeShackle <- function()
{
    return this.oath() != this.Oath.None
        && this.countItems("misc.pale_chain") > 0 && this.shackleMaterialsAvailable().len() > 0;
};

S.forgeShackle <- function( _material )
{
    if (!this.canForgeShackle() || this.countItems(_material.ID) < _material.Count)
        return "材料已经不够了。";
    local stash = ::World.Assets.getStash();
    if (!stash.hasEmptySlot())
        return "物品栏已满。";
    if (!this.takeItems("misc.pale_chain", 1))
        return "没有可用的缚魂锁链。";
    if (!this.takeItems(_material.ID, _material.Count))
    {
        stash.add(::new(this.ItemDir + "misc/pale_chain_item"));
        return "材料已经不够了。";
    }
    stash.add(::new(this.ItemDir + "accessory/pale_soul_shackle"));
    return "你把锁链截成几段，与" + _material.Name + "一同投进营火。熔化的金子渗进链环，冷却后成了一副刻满符文的镣铐。\n\n（消耗 1 条缚魂锁链、" + _material.Count + " 件" + _material.Name + "，获得【缚魂镣铐】）";
};

S.shacklePanel <- function( _screen )
{
    _screen.Text = "打造缚魂镣铐需要 1 条缚魂锁链，另加下列材料中的一种：黄金餐杯、古代金币、宝石王冠、宝石、蠕龙珍宝各 1 件，或纹章戒指 3 枚。\n\n缚魂锁链　" + this.countItems("misc.pale_chain");
    if (this.canForgeShackle())
    {
        foreach (mat in this.shackleMaterialsAvailable())
        {
            local material = mat;
            this.option(_screen, "用 " + material.Count + " 件" + material.Name + "打造（现有 " + this.countItems(material.ID) + "）", @() S.forgeShackle(material));
        }
    }
    else
        _screen.Text += "\n\n材料不足，暂时无法打造。";
    this.option(_screen, "翻阅亡者账簿", @() "@camp");
};

S.Mod.hook("scripts/entity/tactical/actor", function(q)
{
    q.kill = @(__original) function( _killer = null, _skill = null, _fatality = ::Const.FatalityType.None, _silent = false )
    {
        if (S.Battle != null && this.isAlive() && !this.isDying() && this.isPlacedOnMap() && S.isUndead(this))
        {
            local shackle = this.getSkills().getSkillByID("effects.pale_shackle");
            if (shackle != null && !shackle.m.Spent)
            {
                shackle.m.Spent = true;
                this.setHitpoints(::Math.max(1, ::Math.floor(this.getHitpointsMax() * 0.3)));
                this.setDirty(true);
                if (!this.isHiddenToPlayer())
                    ::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(this) + " 身上的镣铐骤然收紧，把它重新拽了起来。");
                return;
            }
        }
        return __original(_killer, _skill, _fatality, _silent);
    };
});

// ---------------------------------------------------------------------------
// 接入：战斗开始时给天灾导师加技能；营地账簿与世界事件
// ---------------------------------------------------------------------------
S.Mod.hook("scripts/skills/skill_container", function(q)
{
    q.onCombatStarted = @(__original) function()
    {
        local actor = this.getActor();
        if (S.Battle != null && S.isChief(actor) && S.oath() == S.Oath.Scourge && !this.hasSkill("actives.pale_soul_bind"))
            this.add(::new(S.SkillDir + "actives/pale_soul_bind"));
        __original();
    };
});

local worldEvent = S.worldEvent;
S.worldEvent = function()
{
    if (this.get("SBNotice") != 0 && this.chief() != null && ::World.State.m.LastEnteredTown == null)
    {
        if (this.soulboundPending().len() == 0)
            this.set("SBNotice", 0);
        else if (this.openEvent("soulbound"))
        {
            this.set("SBNotice", 0);
            return;
        }
    }
    return worldEvent.call(this);
};

// ---------------------------------------------------------------------------
// 炼化（天灾）：在亡灵营地献祭一名 6 级以上的常驻亡灵，得到 1 枚古代魂玉
// ---------------------------------------------------------------------------
S.RefineLevel <- 6;

S.refineTargets <- function()
{
    local list = this.undead().filter(@(_, bro) bro.isAlive() && bro.getLevel() >= ::PaleSovereign.RefineLevel);
    list.sort(@(_a, _b) _b.getLevel() <=> _a.getLevel());
    return list;
};

S.canRefine <- function()
{
    return this.oath() == this.Oath.Scourge && this.refineTargets().len() > 0;
};

S.refineUndead <- function( _bro )
{
    if (!this.canRefine() || this.refineTargets().find(_bro) == null)
        return "炼化条件已改变。";
    local stash = ::World.Assets.getStash();
    local need = 1 + _bro.getItems().getAllItems().len();
    if (stash.getNumberOfEmptySlots() < need)
        return "仓库空位不足（需要 " + need + " 格存放魂玉与卸下的装备），请先清理仓库。";
    local name = _bro.getName();
    local level = _bro.getLevel();
    stash.add(::new(this.ItemDir + "misc/pale_jade_item"));
    _bro.getItems().transferToStash(stash);
    ::World.getPlayerRoster().remove(_bro);
    ::World.Assets.updateFormation(true);
    ::World.State.updateTopbarAssets();
    return "你让 " + name + " 跪进法阵中央。魂火被一缕缕抽出躯壳，凝在你掌心，冷却成一枚幽碧的石头。躯壳随之塌成一堆灰白的骨渣。\n\n（" + name + "（" + level + " 级）永久离开战团，获得 1 枚古代魂玉；它身上的装备已放回仓库）";
};

S.refinePanel <- function( _screen )
{
    _screen.Text = "炼化会把一名常驻亡灵的魂火凝成古代魂玉，躯壳随之化为骨渣，无法挽回。只有 " + this.RefineLevel + " 级以上的常驻亡灵才有足够的魂火。";
    if (!this.isAscended())
        _screen.Text += "\n\n（飞升前，每次炼化都会令导师虚弱 2 天：决心与疲劳上限 −15%，虚弱消退前无法再次炼化）";
    if ("isRefineWeak" in this && this.isRefineWeak())
    {
        local left = ::Math.max(1, ::Math.ceil((::World.Flags.getAsFloat("Pale.RefineWeakUntil") - (::World.getTime().Days + ::World.getTime().Hours / 24.0)) * 24.0));
        _screen.Text += "\n\n导师尚在炼化后的虚弱期中，约 " + left + " 小时后才能再次炼化。";
    }
    else if (!this.canRefine())
        _screen.Text += "\n\n目前没有达到 " + this.RefineLevel + " 级、可供炼化的常驻亡灵。";
    else
    {
        foreach (i, bro in this.refineTargets())
        {
            if (i >= 5)
                break;
            local target = bro;
            this.option(_screen, "炼化 " + target.getName() + "（" + target.getLevel() + " 级）", function()
            {
                S.RefineTarget = ::MSU.asWeakTableRef(target);
                return "@refine_confirm";
            });
        }
    }
    this.option(_screen, "翻阅亡者账簿", @() "@camp");
};

// 二次确认：选中的亡灵存在 S.RefineTarget（弱引用，只在本次打开账簿期间有效）
S.RefineTarget <- null;

S.refineConfirmPanel <- function( _screen )
{
    local target = this.RefineTarget == null || ::MSU.isNull(this.RefineTarget) ? null : this.RefineTarget.get();
    if (target == null || !this.canRefine() || this.refineTargets().find(target) == null)
    {
        _screen.Text = "炼化的人选已经不在了。";
        this.option(_screen, "返回炼化名单", @() "@refine");
        return;
    }
    local background = target.getBackground();
    _screen.Text = "你确定要炼化 " + target.getName() + " 吗？\n\n"
        + background.m.Name + "　" + target.getLevel() + " 级"
        + (::PaleSovereign.isSoulbound(target) ? "　锁魂者" : "")
        + "\n\n炼化后它将永久离开战团，无法复活或召回。身上的装备会放回仓库，你获得 1 枚古代魂玉。"
        + (this.isAscended() ? "" : "\n\n注意：抽取魂火会令导师虚弱 2 天（决心与疲劳上限 −15%），虚弱结束前不能再次炼化。");
    this.option(_screen, "确认炼化 " + target.getName(), function()
    {
        S.RefineTarget = null;
        return S.refineUndead(target);
    });
    this.option(_screen, "再想想", function()
    {
        S.RefineTarget = null;
        return "@refine";
    });
};

local campPanel = S.campPanel;
S.campPanel = function( _event, _screen )
{
    local pending = this.soulboundPending().len();
    if (pending > 0)
        this.option(_screen, "锁魂者待收编（" + pending + "）", @() "@soulbound");
    if (this.canForgeShackle())
        this.option(_screen, "打造缚魂镣铐", @() "@shackle");
    if (this.canRefine())
        this.option(_screen, "炼化常驻亡灵 · 换取古代魂玉", @() "@refine");
    return campPanel.call(this, _event, _screen);
};

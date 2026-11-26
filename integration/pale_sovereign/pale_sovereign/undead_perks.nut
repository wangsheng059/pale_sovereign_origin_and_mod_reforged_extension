// Permanent undead exclusive perk groups (drawn from the undead pet quirk pool) with promotion retention.
local S = ::PaleSovereign;

S.UndeadPerks <- {
    healthy = {
        Name = "强韧腐躯",
        Icon = "ui/perks/pale_ud_healthy",
        Description = "盐痂与腐肉层层叠压，比常人更经得住劈砍。生命上限 +25。"
    },
    rot_stench = {
        Name = "腐臭",
        Icon = "ui/perks/bgp_quirk_rot_stench",
        Description = "靠近它的活人都忍不住干呕。自己回合开始时，相邻的每个敌人疲劳 +5。"
    },
    soften_blows = {
        Name = "卸力",
        Icon = "ui/perks/pale_ud_soften_blows",
        Description = "空心骨节顺着来袭的刀势偏转卸劲。每回合首次受到攻击时，受到的伤害 −25%（眩晕时失效）。"
    },
    undying_flesh = {
        Name = "不朽之躯",
        Icon = "ui/perks/bgp_quirk_undying_flesh",
        Description = "腐肉与枯骨不知疼痛，也不会轻易散架。受到的所有伤害 −10%。"
    },
    plague = {
        Name = "尸毒",
        Icon = "ui/perks/bgp_quirk_plague",
        Description = "爪牙与兵刃上裹着阴冷尸毒。攻击命中敌人后，敌人陷入「尸毒」：行动点 −2、造成的伤害 −15%，持续 2 回合（不叠加、不刷新；免疫中毒的敌人不受影响）。"
    },
    regenerative = {
        Name = "骨髓再生",
        Icon = "ui/perks/pale_ud_regenerative",
        Description = "游离的魂火不断修补骨缝裂口。每回合开始时恢复 8% 最大生命。"
    },
    soul_siphon = {
        Name = "灵魂虹吸",
        Icon = "ui/perks/bgp_quirk_soul_siphon",
        Description = "每夺走一条性命，魂火就更炽烈一分。击杀敌人时回复 20 点生命与 20 点疲劳。"
    },
    necro_pact = {
        Name = "死灵契约",
        Icon = "ui/perks/bgp_quirk_necro_pact",
        Description = "契约越深，出手越狠。按自身等级提高武器基础伤害：最小伤害 +⌊(等级 + 1) ÷ 2⌋、最大伤害 +等级。"
    },
    unlife = {
        Name = "死而复生",
        Icon = "ui/perks/bgp_quirk_unlife",
        Description = "已经死过一次的东西，很难再死第二次。每场战斗一次：受到致命伤害时不死，生命回到上限的 30%，并清除所有持续伤害效果（如流血、中毒）。"
    }
};

S.UndeadPerkGroups <- {
    zombie = {
        ID = "pg.pale_undead_zombie",
        Name = "腐尸本能",
        Icon = "ui/perk_groups/pale_undead_zombie.png",
        Description = "常驻行尸专属特技组（取自亡灵宠物特质池）。本组已学会的特技在常驻亡灵升阶时会永久保留。",
        Tree = [
            ["perk.pale_ud_healthy"],
            ["perk.pale_ud_rot_stench"],
            ["perk.pale_ud_undying_flesh"],
            ["perk.pale_ud_plague"],
            ["perk.pale_ud_soul_siphon"],
            ["perk.pale_ud_necro_pact"],
            ["perk.pale_ud_unlife"]
        ]
    },
    skeleton = {
        ID = "pg.pale_undead_skeleton",
        Name = "枯骨本能",
        Icon = "ui/perk_groups/pale_undead_skeleton.png",
        Description = "常驻骷髅专属特技组（取自亡灵宠物特质池）。本组已学会的特技在常驻亡灵升阶时会永久保留。",
        Tree = [
            ["perk.pale_ud_soften_blows"],
            ["perk.pale_ud_undying_flesh"],
            ["perk.pale_ud_plague"],
            ["perk.pale_ud_regenerative"],
            ["perk.pale_ud_soul_siphon"],
            ["perk.pale_ud_necro_pact"],
            ["perk.pale_ud_unlife"]
        ]
    }
};

local udPerkDefs = [];
foreach (key, def in S.UndeadPerks)
{
    udPerkDefs.push({
        ID = "perk.pale_ud_" + key,
        Script = "scripts/skills/perks/perk_pale_ud_" + key,
        Name = def.Name,
        Tooltip = def.Description + "\n\n常驻亡灵专属特技：学会后在升阶时永久保留（其他特技升阶时会重置）。",
        Icon = def.Icon + ".png",
        IconDisabled = def.Icon + "_sw.png"
    });
}
::DynamicPerks.Perks.addPerks(udPerkDefs);

// Register permanent undead exclusive perk groups in AfterHooks after DynamicPerks VeryLate initializes PerkGroupIDs.
S.registerUndeadPerkGroups <- function()
{
    local exclusiveCol = ::DynamicPerks.PerkGroupCategories.findById("pgc.rf_exclusive_1");
    foreach (kind in ["zombie", "skeleton"])
    {
        try
        {
            local group = ::new("scripts/mods/mod_pale_sovereign/perk_groups/pg_pale_undead_" + kind);
            if (::DynamicPerks.PerkGroups.findById(group.getID()) == null)
                ::DynamicPerks.PerkGroups.add(group);
            if (exclusiveCol != null && exclusiveCol.getGroups().find(group.getID()) == null)
                exclusiveCol.addPerkGroup(group.getID());
        }
        catch (e)
        {
            ::logError("[PaleSovereign] register undead perk group " + kind + ": " + e);
        }
    }
};

S.undeadPerkGroupID <- function( _background )
{
    if (_background == null || !::MSU.isKindOf(_background, "pale_undead_background") || ::MSU.isKindOf(_background, "pale_soulbound_background"))
        return null;
    return _background.m.PaleSkeleton ? "pg.pale_undead_skeleton" : "pg.pale_undead_zombie";
};

S.isRetainedUndeadPerk <- function( _skill )
{
    if (_skill == null || !_skill.isType(::Const.SkillType.Perk))
        return false;
    if ("PaleRetainOnPromote" in _skill.m && _skill.m.PaleRetainOnPromote)
        return true;
    return _skill.getID().find("perk.pale_ud_") == 0;
};

S.retainedUndeadPerkKeys <- function( _bro )
{
    local keys = [];
    if (_bro == null || ::MSU.isNull(_bro))
        return keys;
    local flags = _bro.getFlags();
    if (!flags.has("PaleRetainedPerks"))
        return keys;
    local raw = flags.get("PaleRetainedPerks");
    if (typeof raw != "string" || raw == "")
        return keys;
    foreach (chunk in split(raw, ","))
        foreach (part in split(chunk, ";"))
            if (part in this.UndeadPerks && keys.find(part) == null)
                keys.push(part);
    return keys;
};

S.saveRetainedUndeadPerkKeys <- function( _bro, _keys )
{
    local flags = _bro.getFlags();
    if (_keys.len() == 0)
    {
        flags.remove("PaleRetainedPerks");
        return;
    }
    local text = "";
    foreach (i, key in _keys)
        text += (i == 0 ? "" : ",") + key;
    flags.set("PaleRetainedPerks", text);
};

// Re-apply promoted-retained permanent undead perks (after promotion, deserialize, or recall).
S.restoreRetainedUndeadPerks <- function( _bro )
{
    if (_bro == null || ::MSU.isNull(_bro) || this.isSoulbound(_bro))
        return;
    local keys = this.retainedUndeadPerkKeys(_bro);
    if (keys.len() == 0)
        return;
    local skills = _bro.getSkills();
    local tree = null;
    try { tree = _bro.getPerkTree(); } catch (e) { tree = null; }
    local groupID = this.undeadPerkGroupID(this.getUndeadBackground(_bro));
    if (tree != null && groupID != null && !tree.hasPerkGroup(groupID))
        try { tree.addPerkGroup(groupID); } catch (e) {}
    foreach (key in keys)
    {
        local id = "perk.pale_ud_" + key;
        local perk = skills.getSkillByID(id);
        if (perk == null)
        {
            try
            {
                perk = ::new("scripts/skills/perks/perk_pale_ud_" + key);
                skills.add(perk);
            }
            catch (e)
            {
                ::logError("[PaleSovereign] restore retained undead perk " + key + ": " + e);
                continue;
            }
        }
        try { perk.m.IsRefundable = false; } catch (e) {}
    }
};

// Backfill the permanent undead exclusive perk group onto existing permanent undead in loaded saves.
S.ensureUndeadPerkGroups <- function()
{
    local roster = ::World.getPlayerRoster();
    if (roster == null)
        return 0;
    local fixed = 0;
    foreach (bro in roster.getAll())
    {
        if (!this.isUndead(bro) || this.isSoulbound(bro))
            continue;
        local groupID = this.undeadPerkGroupID(this.getUndeadBackground(bro));
        if (groupID == null)
            continue;
        local tree = null;
        try { tree = bro.getPerkTree(); } catch (e) { tree = null; }
        if (tree != null && !tree.hasPerkGroup(groupID))
        {
            try
            {
                tree.addPerkGroup(groupID);
                ++fixed;
            }
            catch (e)
            {
                ::logError("[PaleSovereign] backfill undead perk group on " + bro.getName() + ": " + e);
            }
        }
    }
    if (fixed > 0)
        ::logInfo("[PaleSovereign] Backfilled permanent undead perk group on " + fixed + " brother(s).");
    return fixed;
};

// Hook Modular Vanilla's lethal-hit checkpoint for perk.pale_ud_unlife (same mechanism as quirk.bgp_unlife).
S.Mod.hook("scripts/entity/tactical/actor", function(q)
{
    q.MV_onBeforeDeathConfirmed = @(__original) function( _attacker, _skill, _hitInfo )
    {
        __original(_attacker, _skill, _hitInfo);
        if (this.getHitpoints() > 0)
            return;
        try
        {
            local perk = this.getSkills().getSkillByID("perk.pale_ud_unlife");
            if (perk != null)
                perk.tryCheatDeath();
        }
        catch (e)
        {
            ::logError("[PaleSovereign] pale_ud_unlife cheat death failed: " + e);
        }
    };
});

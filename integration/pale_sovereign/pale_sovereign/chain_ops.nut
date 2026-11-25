local S = ::PaleSovereign;

// 1.7.0 缚魂锁链重构：定向强化躯体、标记牵制、剥离吞魂、双生魂链、锁魂召返；注魂（吞魂 / 承誓）50% 析出魂玉

// ---------------- 注魂：强化躯体定向化，吞魂 / 承誓 50% 得魂玉 ----------------
// 按强敌种类固定 3 项属性：A 重装 / 督军 / 巨魔 / 蠕龙；B 剑圣 / 骑士 / 血族 / 荣誉卫队；C 祭司 / 梦魇 / 神兽
S.SoulBodyStats <- {
    A = ["Hitpoints", "Stamina", "MeleeDefense"],
    B = ["MeleeSkill", "MeleeDefense", "Initiative"],
    C = ["Bravery", "Hitpoints", "MeleeDefense"]
};
S.SoulBodyGroup <- ["A", "B", "A", "B", "A", "A", "C", "A", "A", "A", "A", "A", "C", "B", "B", "B", "B", "C"];
S.soulBodyKeys <- function( _species )
{
    local group = _species > 0 && _species < this.SoulBodyGroup.len() ? this.SoulBodyGroup[_species] : "A";
    return this.SoulBodyStats[group];
};
S.soulBodyGain <- function()
{
    return (this.isAscended() && this.oath() == this.Oath.Champion ? 4 : 3) + (this.get("SoulChampionKill") != 0 ? 1 : 0);
};
S.soulBodyText <- function()
{
    local names = "";
    foreach (i, key in this.soulBodyKeys(this.get("SoulSpecies")))
        names += (i == 0 ? "" : "、") + this.AttributeNames[key];
    return names + " 各 +" + this.soulBodyGain() + (this.get("SoulChampionKill") != 0 ? "（冠军亲手斩杀，+1）" : "");
};

S.SoulJadeNote <- false;
S.soulJadeText <- function()
{
    if (!this.SoulJadeNote)
        return "";
    this.SoulJadeNote = false;
    return "\n\n（残魂消散时析出 1 枚古代魂玉）";
};

local resolveSoulChain = S.resolveSoul;
S.resolveSoul = function( _choice )
{
    if (_choice == "body")
    {
        if (!this.canUseSoul())
            return false;
        local pet = this.mainPet();
        local gain = this.soulBodyGain();
        foreach (key in this.soulBodyKeys(this.get("SoulSpecies")))
            pet.m.Attributes[key] += gain;
        this.removeMaterial("chain");
        this.set("SoulInfusions", this.get("SoulInfusions") + 1);
        this.set("PendingSoul", 0);
        this.set("SoulChampionKill", 0);
        pet.updateCompanion();
        return true;
    }
    local ok = resolveSoulChain.call(this, _choice);
    if (ok)
    {
        this.set("SoulChampionKill", 0);
        if ((_choice == "soul" || _choice == "inherit") && ::Math.rand(1, 100) <= 50)
        {
            this.pendingItem("misc/pale_jade_item");
            this.SoulJadeNote = true;
        }
    }
    return ok;
};

// ---------------- 标记牵制；冠军亲手斩杀被标记者 ----------------
local markSoulChain = S.markSoul;
S.markSoul = function( _target )
{
    local ok = markSoulChain.call(this, _target);
    if (ok && !_target.getSkills().hasSkill("effects.pale_chain_hold"))
        _target.getSkills().add(::new(this.SkillDir + "effects/pale_chain_hold_effect"));
    return ok;
};

S.KillHooks.push(function( _killer, _victim )
{
    local mark = this.Battle == null ? null : this.Battle.Mark;
    if (mark != null && mark.Target == _victim.getID() && _killer != null && !::MSU.isNull(_killer) && this.isChampionActor(_killer))
        mark.ChampionKill <- true;
});

local saveSoulChain = S.saveSoul;
S.saveSoul = function( _mark )
{
    saveSoulChain.call(this, _mark);
    this.set("SoulChampionKill", "ChampionKill" in _mark && _mark.ChampionKill ? 1 : 0);
};

// ---------------- 剥离吞魂 ----------------
S.petSouls <- function( _pet )
{
    local ret = [];
    for (local species = 1; species < this.Souls.len(); ++species)
        if (this.petGet(_pet, "Species." + species) != 0)
            ret.push(species);
    return ret;
};

S.stripSoulPanel <- function( _event, _screen )
{
    local pet = this.mainPet();
    _screen.Text = "锁链缠住冠军体内的一缕残魂，硬生生把它扯出来，腾出位置给更好的灵魂。\n\n（消耗 1 条缚魂锁链，移除 1 个吞魂特质并返还 1 次吞魂次数。" + this.resourceLine() + "）";
    if (pet == null)
        return;
    foreach (species in this.petSouls(pet))
    {
        if (species == 4)
            continue;
        local index = species;
        local soul = this.Souls[species];
        this.option(_screen, "剥离【" + soul.Name + "】", function()
        {
            if (S.petGet(pet, "Species." + index) == 0 || !S.removeMaterial("chain"))
                return null;
            S.petSet(pet, "Species." + index, 0);
            S.petSet(pet, "Devours", ::Math.max(0, S.petGet(pet, "Devours") - 1));
            pet.updateCompanion();
            return "黑铁锁链从冠军的胸腔里拖出一缕挣扎的残魂，在火光里散成了灰。\n\n（" + pet.m.Name + " 失去【" + soul.Name + "】，吞魂 " + S.petGet(pet, "Devours") + " / " + S.devourCap(pet) + "）";
        });
    }
};

// ---------------- 双生魂链 ----------------
S.twinPet <- function()
{
    local id = this.get("TwinID");
    if (id == 0)
        return null;
    local reserve = this.reservePet();
    return reserve != null && reserve.m.PaleID == id ? reserve : null;
};

S.twinPanel <- function( _event, _screen )
{
    local pet = this.mainPet();
    local reserve = this.reservePet();
    local chains = this.countItems("misc.pale_chain");
    local twin = this.twinPet();
    local mode = this.get("TwinMode");
    _screen.Text = "两口棺椁之间缠上一条锁链，候补冠军的残魂便能借给主冠军，或在主冠军倒下时立刻接替它。\n\n"
        + "【借魂】主冠军额外获得候补棺椁的第 1 个吞魂特质，不占吞魂上限。\n【替战】主冠军阵亡后，候补棺椁立刻挂上导师的饰品栏，导师可以当场放出它接战（每场 1 次）。\n\n"
        + "锚定消耗 2 条锁链；切换效果或改换候补消耗 1 条。\n" + this.resourceLine();
    if (pet == null || reserve == null)
    {
        _screen.Text += "\n\n需要主冠军装在导师饰品栏，并在营地账簿登记 1 口候补棺椁。";
        return;
    }
    if (twin != null)
        _screen.Text += "\n\n当前锚定：" + twin.m.Name + "（" + (mode == 1 ? "借魂" : "替战") + "）";
    foreach (choice in [1, 2])
    {
        if (twin != null && mode == choice)
            continue;
        local value = choice;
        local cost = twin == null && this.get("TwinID") == 0 ? 2 : 1;
        if (chains >= cost)
            this.option(_screen, (value == 1 ? "借魂" : "替战") + " · 锚定 " + reserve.m.Name + "（" + cost + " 条锁链）", function()
            {
                if (S.countItems("misc.pale_chain") < cost)
                    return null;
                for (local i = 0; i < cost; ++i)
                    S.removeMaterial("chain");
                S.set("TwinID", S.petID(reserve));
                S.set("TwinMode", value);
                return "锁链在两口棺椁的铜箍之间绕了三圈。\n\n（" + reserve.m.Name + " 锚定为" + (value == 1 ? "借魂" : "替战") + "）";
            });
    }
};

// 借魂：放出主冠军时加上候补的第 1 个吞魂特质（不写进存档）
local applyJadePetChain = S.applyJadePet;
S.applyJadePet = function( _pet, _entity )
{
    applyJadePetChain.call(this, _pet, _entity);
    if (this.get("TwinMode") != 1 || !::MSU.isEqual(this.mainPet(), _pet))
        return;
    local twin = this.twinPet();
    if (twin == null)
        return;
    foreach (species in this.petSouls(twin))
    {
        if (this.petGet(_pet, "Species." + species) != 0)
            continue;
        local trait = ::new(this.SkillDir + "effects/pale_pet_trait");
        trait.configure(species);
        _entity.getSkills().add(trait);
        break;
    }
};

// 替战：主冠军阵亡后把候补棺椁挂到导师身上
local releaseItemChain = ::BGP.NecroPet.releaseItem;
::BGP.NecroPet.releaseItem = function( _e )
{
    local wasMain = false;
    try
    {
        local item = _e.m.Item;
        if (typeof item == "instance")
            item = item.get();
        wasMain = S.isActive() && S.Battle != null && item != null && item == S.mainPet();
    }
    catch (e)
    {
        wasMain = false;
    }
    releaseItemChain(_e);
    if (!wasMain || S.get("TwinMode") != 2 || ("TwinUsed" in S.Battle && S.Battle.TwinUsed))
        return;
    local twin = S.twinPet();
    local chief = S.chief();
    if (twin == null || chief == null || !chief.isAlive() || !chief.isPlacedOnMap())
        return;
    local items = chief.getItems();
    if (items.getItemAtSlot(::Const.ItemSlot.Accessory) != null)
        return;
    ::World.Assets.getStash().remove(twin);
    if (!items.equip(twin))
    {
        ::World.Assets.getStash().add(twin);
        return;
    }
    local unleash = chief.getSkills().getSkillByID("actives.unleash_companion");
    if (unleash != null)
    {
        unleash.m.IsUsed = false;
        unleash.m.IsHidden = false;
    }
    chief.getSkills().update();
    S.Battle.TwinUsed <- true;
    S.set("ReservePetID", 0);
    S.set("TwinID", 0);
    S.set("TwinMode", 0);
    ::Tactical.EventLog.log("双生魂链一紧，" + twin.m.Name + " 的棺椁落到了导师手边。");
};

// ---------------- 锁魂召返 ----------------
S.RecallCost <- { Chain = 1, Reserve = 4 };
S.RecallFields <- ["Name", "Title", "Background", "Kind", "Level", "XP", "Stats", "Traits", "Talents", "Flags", "Kills", "Soulbound", "ExtraPerks", "ChampionRacial", "LegacyScript"];
S.RecallStatKeys <- ["Hitpoints", "Stamina", "Bravery", "Initiative", "MeleeSkill", "RangedSkill", "MeleeDefense", "RangedDefense", "ActionPoints"];
S.RecallFlagKeys <- ["PaleUndeadKind", "PaleMiddleBranch", "PaleHeadVariant", "PaleBodyVariant", "PaleDetailVariant", "PaleLeader", "PaleLimitBreak", "PaleGraftCount", "PaleStripCount", "PaleSoulbound", "PaleLegacy", "PaleLegacyScript", "PaleCaptiveChampion", "PaleGilded", "PaleGemEyes", "PaleWash", "PaleFormerLiving", "PaleFormerGraverobber", "PaleLoreOrigin", "PaleLoreForm", "PaleLoreCamp", "PaleLoreVer", "PaleTitleTrait"];

S.canRecall <- function( _bro )
{
    if (!this.isUndead(_bro) || _bro.getSkills().hasSkill("trait.pale_soul_scar"))
        return false;
    return this.isSoulbound(_bro) || this.getUndeadTier(_bro) >= 2;
};

S.snapshotBro <- function( _bro )
{
    local b = _bro.getBaseProperties();
    local stats = [];
    foreach (key in this.RecallStatKeys)
        stats.push(b[key]);
    local traits = [];
    // Snapshot pure Trait skills only so background/special/status skills are excluded.
    foreach (trait in this.pureTraits(_bro, true))
    {
        if (trait.isGarbage() || ("PaleShared" in trait.m))
            continue;
        try { traits.push(::IO.scriptFilenameByHash(trait.ClassNameHash)); } catch (e) {}
    }
    local flags = [];
    foreach (key in this.RecallFlagKeys)
        if (_bro.getFlags().has(key))
            flags.push(key + "=" + _bro.getFlags().get(key));
    local kills = 0;
    try { kills = _bro.getLifetimeStats().Kills; } catch (e) { kills = 0; }
    local background = "";
    try { background = this.scriptBase(::IO.scriptFilenameByHash(_bro.getBackground().ClassNameHash)); } catch (e) { background = ""; }
    local basePerks = ::Math.min(_bro.getLevel(), ::Const.XP.MaxLevelWithPerkpoints) - 1;
    local totalPerks = _bro.m.PerkPoints + _bro.m.PerkPointsSpent;
    local extraPerks = ::Math.max(0, totalPerks - basePerks);
    local legacyScript = "";
    if (_bro.getFlags().has("PaleLegacyScript"))
    {
        local v = _bro.getFlags().get("PaleLegacyScript");
        if (typeof v == "string")
            legacyScript = v;
    }
    if (legacyScript == "" && this.isSoulbound(_bro))
    {
        local tree = null;
        try { tree = _bro.getPerkTree(); } catch (e) { tree = null; }
        foreach (skill in _bro.getSkills().m.Skills)
        {
            if (skill.isGarbage() || !skill.isType(::Const.SkillType.Perk) || !::MSU.isNull(skill.getItem()))
                continue;
            local id = skill.getID();
            if (id.find("perk.pale_") == 0 || id == this.VisageID || (tree != null && tree.hasPerk(id)))
                continue;
            try { legacyScript = ::IO.scriptFilenameByHash(skill.ClassNameHash); break; } catch (e) {}
        }
    }
    return {
        Name = _bro.getName(), Title = _bro.getTitle(), Background = background,
        Kind = _bro.getFlags().has("PaleUndeadKind") ? _bro.getFlags().get("PaleUndeadKind") : "skeleton",
        Level = _bro.getLevel(), XP = _bro.getXP(), Stats = this.joinList(stats), Traits = this.joinList(traits, ";"),
        Talents = this.joinList(_bro.getTalents()), Flags = this.joinList(flags, ";"), Kills = kills,
        Soulbound = this.isSoulbound(_bro) ? "1" : "", ExtraPerks = extraPerks,
        ChampionRacial = _bro.getSkills().hasSkill("racial.champion") ? "1" : "",
        LegacyScript = legacyScript
    };
};

S.joinList <- function( _list, _sep = "," )
{
    local text = "";
    foreach (i, value in _list)
        text += (i == 0 ? "" : _sep) + value;
    return text;
};

S.splitList <- function( _text, _sep = "," )
{
    return typeof _text == "string" && _text != "" ? split(_text, _sep) : [];
};

S.pendingList <- function( _prefix )
{
    local flags = ::World.Flags;
    local count = flags.getAsInt("Pale." + _prefix + ".Count");
    local list = [];
    for (local i = 0; i < count; ++i)
    {
        local rec = {};
        foreach (field in this.RecallFields)
        {
            local value = flags.get("Pale." + _prefix + "." + i + "." + field);
            rec[field] <- typeof value == "bool" ? "" : value;
        }
        list.push(rec);
    }
    return list;
};

S.savePendingList <- function( _prefix, _list )
{
    local flags = ::World.Flags;
    local old = flags.getAsInt("Pale." + _prefix + ".Count");
    for (local i = 0; i < old; ++i)
        foreach (field in this.RecallFields)
            flags.remove("Pale." + _prefix + "." + i + "." + field);
    foreach (i, rec in _list)
        foreach (field in this.RecallFields)
            flags.set("Pale." + _prefix + "." + i + "." + field, field in rec ? rec[field] : "");
    flags.set("Pale." + _prefix + ".Count", _list.len());
};

// 按快照重建一名常驻亡灵；装备已在战场上丢失
S.rebuildUndead <- function( _rec )
{
    local background = typeof _rec.Background == "string" && _rec.Background != "" ? _rec.Background : this.UndeadKinds[this.undeadKindOf(_rec.Kind)].Background;
    local bro = this.spawnBrother(background, null, -1, false);
    local flags = bro.getFlags();
    flags.set("PalePermanentUndead", true);
    flags.set("undead", true);
    foreach (entry in this.splitList(_rec.Flags, ";"))
    {
        local at = entry.find("=");
        if (at == null)
            continue;
        local key = entry.slice(0, at);
        local value = entry.slice(at + 1);
        local number = null;
        try { number = value.tointeger(); } catch (e) { number = null; }
        flags.set(key, number != null && (number + "") == value ? number : value);
    }
    local skills = bro.getSkills();
    // Clear pure Trait skills only so the rebuilt undead keeps its background intact.
    foreach (trait in this.pureTraits(bro, true))
        if (trait.getID() != "trait.player_character")
            skills.removeByID(trait.getID());
    skills.collectGarbage();
    foreach (script in this.splitList(_rec.Traits, ";"))
    {
        try
        {
            local trait = ::new(script);
            if (!skills.hasSkill(trait.getID()))
                skills.add(trait);
        }
        catch (e)
        {
        }
    }
    local props = bro.getBaseProperties();
    foreach (i, value in this.splitList(_rec.Stats))
        if (i < this.RecallStatKeys.len())
            props[this.RecallStatKeys[i]] = value.tointeger();
    local talents = this.splitList(_rec.Talents);
    if (talents.len() > 0)
    {
        local own = bro.getTalents();
        own.resize(::Const.Attributes.COUNT, 0);
        foreach (i, value in talents)
            if (i < own.len())
                own[i] = value.tointeger();
    }
    if (!this.hasAnyTalent(bro))
        try { bro.fillTalentValues(); } catch (e) {}
    local level = 1;
    try { level = typeof _rec.Level == "integer" ? _rec.Level : _rec.Level.tointeger(); } catch (e) { level = 1; }
    bro.m.Level = ::Math.max(1, level);
    try { bro.m.XP = typeof _rec.XP == "integer" ? _rec.XP : _rec.XP.tointeger(); } catch (e) { bro.m.XP = ::Const.LevelXP[bro.m.Level - 1]; }
    bro.m.LevelUps = 0;
    bro.m.LevelUpsSpent = 0;
    local extraPerks = 0;
    if ("ExtraPerks" in _rec)
        try { extraPerks = typeof _rec.ExtraPerks == "integer" ? _rec.ExtraPerks : (_rec.ExtraPerks == "" ? 0 : _rec.ExtraPerks.tointeger()); } catch (e) { extraPerks = 0; }
    bro.m.PerkPoints = ::Math.min(bro.m.Level, ::Const.XP.MaxLevelWithPerkpoints) - 1 + ::Math.max(0, extraPerks);
    bro.m.PerkPointsSpent = 0;
    bro.m.Attributes = [];
    bro.fillAttributeLevelUpValues(::Const.XP.MaxLevelWithPerkpoints - 1);
    local bg = bro.getBackground();
    bg.buildDescription(true);
    local tree = bg.createPerkTreeBlueprint();
    tree.setActor(bro);
    bro.m.PerkTree = tree;
    tree.build();
    bro.resetPerkTier();
    if (("ChampionRacial" in _rec && (_rec.ChampionRacial == "1" || _rec.ChampionRacial == 1)) || flags.has("PaleCaptiveChampion"))
    {
        if (!skills.hasSkill("racial.champion"))
            try { skills.add(::new("scripts/skills/racial/champion_racial")); } catch (e) {}
    }
    local legacy = "LegacyScript" in _rec && typeof _rec.LegacyScript == "string" ? _rec.LegacyScript : "";
    if (legacy == "" && flags.has("PaleLegacyScript") && typeof flags.get("PaleLegacyScript") == "string")
        legacy = flags.get("PaleLegacyScript");
    if (legacy != "")
    {
        try
        {
            local perk = ::new(legacy);
            if (!skills.hasSkill(perk.getID()))
            {
                perk.m.IsRefundable = false;
                skills.add(perk);
            }
        }
        catch (e) {}
    }
    try { bro.getLifetimeStats().Kills = typeof _rec.Kills == "integer" ? _rec.Kills : _rec.Kills.tointeger(); } catch (e) {}
    bro.setName(_rec.Name);
    bro.setTitle(_rec.Title);
    bro.m.MoraleState = ::Const.MoraleState.Ignore;
    this.restoreTierSkills(bro);
    this.applyUndeadLook(bro);
    skills.update();
    ::World.Assets.updateFormation(true);
    return bro;
};

// 阵亡时记下快照（召返用，以及活人转化在 living_bond.nut 里读 Battle.FallenLiving）
S.Mod.hook("scripts/entity/tactical/player", function(q)
{
    q.onDeath = @(__original) function( _killer, _skill, _tile, _fatality )
    {
        if (S.Battle != null && S.isActive())
        {
            try
            {
                if (S.canRecall(this) && _fatality != ::Const.FatalityType.Smashed)
                {
                    if (!("FallenUndead" in S.Battle))
                        S.Battle.FallenUndead <- [];
                    S.Battle.FallenUndead.push(S.snapshotBro(this));
                }
                S.onLivingDeath(this, _fatality);
            }
            catch (e)
            {
                ::logError("[PaleSovereign] death snapshot: " + e);
            }
        }
        return __original(_killer, _skill, _tile, _fatality);
    };
});

S.onLivingDeath <- function( _bro, _fatality ) {};

S.VictoryHooks.push(function()
{
    if (!("FallenUndead" in this.Battle) || this.Battle.FallenUndead.len() == 0)
        return;
    this.savePendingList("Recall", this.Battle.FallenUndead);
    this.set("RecallNotice", 1);
});

S.recallPanel <- function( _event, _screen )
{
    local list = this.pendingList("Recall");
    _screen.Text = "锁链还能够到那几缕没散尽的魂火。现在拘回来，它们能带着生前的一切回到队列里；等下一场仗开打，就来不及了。\n\n"
        + "（每名消耗 " + this.RecallCost.Chain + " 条缚魂锁链、" + this.RecallCost.Reserve + " 点防腐尸骸。召返者以 10% 生命回到名册，保留等级、属性、特质与升阶，特技点重新分配，装备已遗失；附带【裂魂印记】，不能再次召返）\n" + this.resourceLine();
    foreach (i, rec in list)
    {
        local index = i;
        local entry = rec;
        this.option(_screen, "召返 " + entry.Name + "（" + entry.Level + " 级）", function()
        {
            local pending = S.pendingList("Recall");
            if (index >= pending.len() || S.countItems("misc.pale_chain") < S.RecallCost.Chain || S.get("Reserve") < S.RecallCost.Reserve
                || ::World.getPlayerRoster().getSize() >= ::World.Assets.getBrothersMax())
                return "锁链或尸骸不够，或者名册已满。";
            S.removeMaterial("chain");
            S.changeReserve(-S.RecallCost.Reserve);
            local rec = pending.remove(index);
            S.savePendingList("Recall", pending);
            local bro = S.rebuildUndead(rec);
            bro.getSkills().add(::new("scripts/skills/traits/pale_undead_soul_scar_trait"));
            bro.getSkills().update();
            bro.setHitpointsPct(0.1);
            return "锁链收紧，那缕魂火被硬生生拖回一副新拼的骨架里。" + bro.getName() + " 晃了晃，重新站进队列。\n\n（" + bro.getName() + " 回到名册，生命 10%，获得【裂魂印记】）";
        });
    }
    if (list.len() > 0)
        this.option(_screen, "放走这些残魂", function() { S.savePendingList("Recall", []); return "你松开锁链，那几缕魂火在夜风里散尽了。"; });
};

// 新一场战斗开始时，上一场没召返的残魂散去
local beginBattleChain = S.beginBattle;
S.beginBattle = function( _night )
{
    beginBattleChain.call(this, _night);
    if (::World.Flags.getAsInt("Pale.Recall.Count") > 0)
        this.savePendingList("Recall", []);
    this.set("RecallNotice", 0);
};

S.addPage("x_strip_soul", "剥离吞魂", "chain_strip_soul", @(_event, _screen) S.stripSoulPanel(_event, _screen));
S.addPage("x_twin", "双生魂链", "chain_twin", @(_event, _screen) S.twinPanel(_event, _screen));
S.addPage("x_recall", "锁魂召返", "chain_recall", @(_event, _screen) S.recallPanel(_event, _screen));

local campPanelChain = S.campPanel;
S.campPanel = function( _event, _screen )
{
    local pending = ::World.Flags.getAsInt("Pale.Recall.Count");
    if (pending > 0)
        this.option(_screen, "锁魂召返（" + pending + "）", @() "@x_recall");
    if (this.oath() == this.Oath.Champion)
    {
        local pet = this.mainPet();
        if (pet != null && this.petGet(pet, "Devours") > 0 && this.countItems("misc.pale_chain") > 0)
            this.option(_screen, "剥离吞魂 · 1 条锁链", @() "@x_strip_soul");
        if (pet != null && this.reservePet() != null)
            this.option(_screen, "双生魂链", @() "@x_twin");
    }
    return campPanelChain.call(this, _event, _screen);
};

local worldEventChain = S.worldEvent;
S.worldEvent = function()
{
    if (this.get("RecallNotice") != 0 && this.chief() != null && ::World.State.m.LastEnteredTown == null)
    {
        if (::World.Flags.getAsInt("Pale.Recall.Count") == 0)
            this.set("RecallNotice", 0);
        else if (this.openEvent("x_recall"))
        {
            this.set("RecallNotice", 0);
            return;
        }
    }
    return worldEventChain.call(this);
};

// ---------------- 1.7.4 敌阵精英提示 ----------------
// 冠军路线每轮开始时，给可被缚魂锁链标记的敌人挂「可缚之魂」提示状态，并在战斗记录里说明一次（中途增援也会提示）
S.inheritPreview <- function( _actor )
{
    local parts = [];
    if (_actor.getSkills().hasSkill("racial.champion"))
        parts.push("冠军加成");
    local weapon = _actor.getItems().getItemAtSlot(::Const.ItemSlot.Mainhand);
    if (weapon != null && weapon.isItemType(::Const.Items.ItemType.Named))
        parts.push("具名武器【" + weapon.getName() + "】");
    local text = "";
    foreach (i, part in parts)
        text += (i == 0 ? "" : "、") + part;
    return text;
};

S.hintSoulElite <- function( _actor )
{
    if (this.Battle == null || !this.isActive() || this.oath() != this.Oath.Champion || !_actor.isPlacedOnMap()
        || _actor.getSkills().hasSkill("effects.pale_soul_elite") || _actor.getSkills().hasSkill("effects.pale_bound_soul"))
        return;
    local chief = this.chief();
    if (chief == null || _actor.isAlliedWith(chief) || this.soulSpecies(::IO.scriptFilenameByHash(_actor.ClassNameHash)) == 0)
        return;
    _actor.getSkills().add(::new(this.SkillDir + "effects/pale_soul_elite_effect"));
    ::Tactical.EventLog.log("[color=#bcad8c]可缚之魂：[/color]" + ::Const.UI.getColorizedEntityName(_actor)
        + "的灵魂可以被缚魂锁链锚定。等它的生命降到 " + this.markThreshold() + "% 以下，让导师使用「缚魂锁链」。");
};

S.Mod.hook("scripts/entity/tactical/actor", function(q)
{
    q.onRoundStart = @(__original) function()
    {
        __original();
        try { S.hintSoulElite(this); } catch (e) { ::logError("[PaleSovereign] soul elite hint: " + e); }
    };
});

local markSoulHint = S.markSoul;
S.markSoul = function( _target )
{
    local ok = markSoulHint.call(this, _target);
    if (ok)
        _target.getSkills().removeByID("effects.pale_soul_elite");
    return ok;
};

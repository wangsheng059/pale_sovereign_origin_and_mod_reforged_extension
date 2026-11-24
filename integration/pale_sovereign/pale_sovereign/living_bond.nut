local S = ::PaleSovereign;

// 1.7.0 活人与亡灵的双向联动：生死转化、心理适应、战场互补、后勤门面

// ---------------- 背景分类 ----------------
S.ProDeathBackgrounds <- ["background.graverobber", "background.gravedigger", "background.cultist", "background.converted_cultist",
    "background.anatomist", "background.bgp_necromancer", "background.killer_on_the_run", "background.executioner", "background.executioner_southern"];
S.PiousBackgrounds <- ["background.monk", "background.flagellant", "background.monk_turned_flagellant", "background.pacified_flagellant",
    "background.witchhunter", "background.pilgrim"];

S.backgroundID <- function( _bro )
{
    try { return _bro.getBackground().getID(); } catch (e) { return ""; }
};

S.isLivingBro <- function( _bro )
{
    return _bro != null && !::MSU.isNull(_bro) && !_bro.getFlags().has("undead") && !this.isChief(_bro);
};

S.isProDeath <- function( _bro )
{
    return this.isLivingBro(_bro) && this.ProDeathBackgrounds.find(this.backgroundID(_bro)) != null;
};

S.isPious <- function( _bro )
{
    return this.isLivingBro(_bro) && this.PiousBackgrounds.find(this.backgroundID(_bro)) != null;
};

// 免疫亡灵相关的掉心情：亲死背景，或拥有见怪不怪 / 生前死契 / 堕落圣徒
S.AcclimatedTraits <- ["trait.pale_acclimated", "trait.pale_death_indenture", "trait.pale_fallen_saint"];
S.isAcclimated <- function( _bro )
{
    if (this.isProDeath(_bro))
        return true;
    foreach (id in this.AcclimatedTraits)
        if (_bro.getSkills().hasSkill(id))
            return true;
    return false;
};

// 亡灵相关的坏心情一律走这里
S.undeadMood <- function( _bro, _value, _reason )
{
    if (!this.isLivingBro(_bro) || this.isAcclimated(_bro))
        return false;
    _bro.worsenMood(_value, _reason);
    return true;
};

S.hasLivingNeighbour <- function( _actor )
{
    if (_actor == null || !::Tactical.isActive() || !_actor.isPlacedOnMap())
        return false;
    foreach (tile in this.area(_actor.getTile()).slice(1))
        if (tile.IsOccupiedByActor)
        {
            local other = tile.getEntity();
            if (other != null && other.isAlive() && other.isAlliedWith(_actor) && !other.getFlags().has("undead")
                && other.getFaction() == ::Const.Faction.Player)
                return true;
        }
    return false;
};

S.neighbours <- function( _actor )
{
    local ret = [];
    if (_actor == null || !::Tactical.isActive() || !_actor.isPlacedOnMap())
        return ret;
    foreach (tile in this.area(_actor.getTile()).slice(1))
        if (tile.IsOccupiedByActor)
        {
            local other = tile.getEntity();
            if (other != null && other.isAlive() && !other.isDying() && other.isAlliedWith(_actor))
                ret.push(other);
        }
    return ret;
};

// ---------------- 后勤门面 ----------------
S.countBackgrounds <- function( _ids )
{
    local n = 0;
    foreach (bro in this.humans())
        if (this.isLivingBro(bro) && _ids.find(this.backgroundID(bro)) != null)
            ++n;
    return n;
};

// 盗墓贼 / 掘墓人（含生前是盗墓贼的转化亡灵）：每名战后采集 +1 点，最多 +2
S.graverobberHarvestBonus = function()
{
    local n = this.countBackgrounds(["background.graverobber", "background.gravedigger"]);
    foreach (bro in this.undead())
        if (bro.getFlags().has("PaleFormerGraverobber"))
            ++n;
    return ::Math.min(2, n);
};

// 解剖师 / 炼金术士：肢体替换与优质拼装 −1 点（最低 2 点）
S.anatomistDiscount = function()
{
    return this.countBackgrounds(["background.anatomist", "background.alchemist"]) > 0 ? 1 : 0;
};

// 铁匠 / 学徒：打造锁链的冷却 −2 天
S.smithCooldownHours <- function()
{
    return 240 - (this.countBackgrounds(["background.apprentice", "background.blacksmith", "background.rf_blacksmith"]) > 0 ? 48 : 0);
};

// 邪教徒：每名使导师开局决心 +2，最多 +6
S.cultistResolve <- function()
{
    return 2 * ::Math.min(3, this.countBackgrounds(["background.cultist", "background.converted_cultist"]));
};

// ---------------- 战斗：心理与战术协同 ----------------
S.Mod.hook("scripts/skills/skill_container", function(q)
{
    q.onCombatStarted = @(__original) function()
    {
        local actor = this.getActor();
        if (S.Battle != null && actor.getFaction() == ::Const.Faction.Player && !this.hasSkill("effects.pale_living_bond"))
            this.add(::new(S.SkillDir + "effects/pale_living_bond_effect"));
        __original();
    };
});

// 见怪不怪 / 亲死 / 堕落圣徒：友方常驻亡灵与仆从阵亡不再触发士气检定
S.Mod.hook("scripts/entity/tactical/actor", function(q)
{
    q.onOtherActorDeath = @(__original) function( ... )
    {
        local victim = vargv.len() > 1 ? vargv[1] : null;
        if (S.Battle != null && victim != null && !::MSU.isNull(victim) && S.isLivingBro(this) && S.isAcclimated(this)
            && victim.isAlliedWith(this) && victim.getFlags().has("undead"))
            return;
        local args = [this];
        args.extend(vargv);
        return __original.acall(args);
    };
});

// 胜仗计数：凡人背景的活人与常驻亡灵并肩打满 8 场胜仗后适应（大地图小事件授予【见怪不怪】）
S.AcclimationWins <- 8;
S.VictoryHooks.push(function()
{
    if (this.Battle.UndeadDeployed <= 0)
        return;
    foreach (bro in this.humans())
    {
        if (!this.isLivingBro(bro) || !bro.isPlacedOnMap() || this.isAcclimated(bro))
            continue;
        local flags = bro.getFlags();
        flags.set("PaleUndeadWins", (flags.has("PaleUndeadWins") ? flags.getAsInt("PaleUndeadWins") : 0) + 1);
    }
});

S.acclimationCandidates <- function()
{
    return this.humans().filter(@(_, bro) S.isLivingBro(bro) && !S.isAcclimated(bro)
        && bro.getFlags().has("PaleUndeadWins") && bro.getFlags().getAsInt("PaleUndeadWins") >= S.AcclimationWins);
};

// ---------------- 生死转化 ----------------
S.ConvertLevel <- 8;
S.ConvertCost <- { Reserve = 5, Indenture = 2, Ritual = 3 };

S.statOf <- function( _rec, _key )
{
    local values = this.splitList(_rec.Stats);
    local index = this.RecallStatKeys.find(_key);
    return index == null || index >= values.len() ? 0 : values[index].tointeger();
};

S.convertKind <- function( _rec )
{
    if (this.statOf(_rec, "RangedSkill") > this.statOf(_rec, "MeleeSkill"))
        return "archer";
    return this.statOf(_rec, "Initiative") >= 110 ? "skeleton" : "zombie";
};

S.convertBranch <- function( _kind, _rec )
{
    if (_kind == "archer")
        return this.RangedTierChoices.archer[0];
    if (_kind == "zombie")
        return "fallen_hero";
    return this.statOf(_rec, "Initiative") >= 120 ? "bone_blade" : "grave_guard";
};

// 生前可继承的特质：亡灵特质池里出现过的原版特质
S.signatureTrait <- function( _rec, _kind )
{
    local pool = clone this.UndeadTraitPool.Both;
    pool.extend(_kind == "zombie" ? this.UndeadTraitPool.Zombie : this.UndeadTraitPool.Skeleton);
    foreach (script in this.splitList(_rec.Traits, ";"))
    {
        local name = this.scriptBase(script);
        if (pool.find(name) == null)
            continue;
        try
        {
            local trait = ::new(script);
            if (!this.isNegativeUndeadTrait(trait.getID()))
                return trait;
        }
        catch (e)
        {
        }
    }
    return null;
};

S.moodWave <- function( _name )
{
    foreach (bro in this.humans())
    {
        if (!this.isLivingBro(bro))
            continue;
        if (this.isProDeath(bro))
            bro.improveMood(1.0, "看着" + _name + "重新站进了亡者的队列");
        else
            this.undeadMood(bro, 1.0, "看着" + _name + "变成了亡灵");
    }
};

// _rec 为 snapshotBro 的快照；_tier2 为 true 时转为中阶常驻亡灵
S.convertToUndead <- function( _rec, _tier2 )
{
    local kind = this.convertKind(_rec);
    local bro = this.createUndead(kind, null, true);
    local skills = bro.getSkills();
    foreach (trait in skills.query(::Const.SkillType.Trait))
        skills.removeByID(trait.getID());
    skills.collectGarbage();
    local signature = this.signatureTrait(_rec, kind);
    if (signature != null)
        skills.add(signature);
    skills.add(::new("scripts/skills/traits/pale_undead_former_comrade_trait"));
    local talents = this.splitList(_rec.Talents);
    local own = bro.getTalents();
    foreach (i, value in talents)
        if (i < own.len() && value.tointeger() >= 2)
            own[i] = value.tointeger();
    local level = 1;
    try { level = typeof _rec.Level == "integer" ? _rec.Level : _rec.Level.tointeger(); } catch (e) { level = 1; }
    local target = ::Math.max(3, ::Math.floor(level * 0.7));
    if (_tier2)
    {
        local branch = this.convertBranch(kind, _rec);
        if (kind != "archer")
            this.castleTrain(bro, target - 1 + this.tierLevelsSpent());
        this.FreeTier = true;
        try { this.tierPromote(bro, branch); } catch (e) { ::logError("[PaleSovereign] convert promotion: " + e); }
        this.FreeTier = false;
        if (kind == "archer")
            this.castleTrain(bro, target - 1);
    }
    else
        this.castleTrain(bro, target - 1);
    bro.setName(_rec.Name);
    if (typeof _rec.Title == "string" && _rec.Title != "")
        bro.setTitle(_rec.Title);
    try { bro.getLifetimeStats().Kills = typeof _rec.Kills == "integer" ? _rec.Kills : _rec.Kills.tointeger(); } catch (e) {}
    if (_rec.Background == "graverobber_background" || _rec.Background == "gravedigger_background")
        bro.getFlags().set("PaleFormerGraverobber", true);
    bro.getFlags().set("PaleFormerLiving", _rec.Background);
    this.applyUndeadLook(bro);
    skills.update();
    bro.setHitpointsPct(1.0);
    ::World.Assets.updateFormation(true);
    this.moodWave(_rec.Name);
    return bro;
};

// 阵亡回收：8 级以上活人战死（未被爆头或砸烂），战后可以转化
S.onLivingDeath = function( _bro, _fatality )
{
    if (!this.isLivingBro(_bro) || _fatality == ::Const.FatalityType.Decapitated || _fatality == ::Const.FatalityType.Smashed)
        return;
    local indenture = _bro.getSkills().hasSkill("trait.pale_death_indenture");
    if (_bro.getLevel() < this.ConvertLevel && !indenture)
        return;
    if (!("FallenLiving" in this.Battle))
        this.Battle.FallenLiving <- [];
    local rec = this.snapshotBro(_bro);
    rec.Flags = indenture ? "Indenture=1" : "";
    this.Battle.FallenLiving.push(rec);
};

S.VictoryHooks.push(function()
{
    if (!("FallenLiving" in this.Battle) || this.Battle.FallenLiving.len() == 0)
        return;
    local list = this.pendingList("Convert");
    list.extend(this.Battle.FallenLiving);
    this.savePendingList("Convert", list);
    this.set("ConvertNotice", 1);
});

S.convertPanel <- function( _event, _screen )
{
    local list = this.pendingList("Convert");
    _screen.Text = "战死的老兵还没有凉透。只要导师点头，他们可以带着生前的名字和本事，换一副不会疼的身体回到队列里。\n\n"
        + "（转为中阶常驻亡灵：清除全部永久伤势，保留名字、击杀数、约 70% 的等级与较高的天赋星，继承 1 个生前特质，并获得【旧日同袍】。"
        + "每名消耗 " + this.ConvertCost.Reserve + " 点防腐尸骸 + 1 枚古代魂玉或 1 条缚魂锁链；签过【生前死契】的只要 " + this.ConvertCost.Indenture + " 点防腐尸骸）\n" + this.resourceLine();
    foreach (i, rec in list)
    {
        local index = i;
        local entry = rec;
        local indenture = typeof entry.Flags == "string" && entry.Flags.find("Indenture") != null;
        local label = entry.Name + "（" + entry.Level + " 级）";
        if (indenture)
            this.option(_screen, "转化 " + label + " · " + this.ConvertCost.Indenture + " 点尸骸（生前死契）", @() S.convertPending(index, "indenture"));
        else
        {
            if (this.countItems("misc.pale_jade") > 0)
                this.option(_screen, "转化 " + label + " · 5 点尸骸 + 1 枚魂玉", @() S.convertPending(index, "jade"));
            if (this.countItems("misc.pale_chain") > 0)
                this.option(_screen, "转化 " + label + " · 5 点尸骸 + 1 条锁链", @() S.convertPending(index, "chain"));
        }
    }
    if (list.len() > 0)
        this.option(_screen, "让他们入土为安", function() { S.savePendingList("Convert", []); return "你合上了他们的眼睛。这一回，死人就留在土里。"; });
};

S.convertPending <- function( _index, _pay )
{
    local list = this.pendingList("Convert");
    if (_index >= list.len() || ::World.getPlayerRoster().getSize() >= ::World.Assets.getBrothersMax())
        return "名册已满，或这名老兵已不在名单上。";
    local reserve = _pay == "indenture" ? this.ConvertCost.Indenture : this.ConvertCost.Reserve;
    if (this.get("Reserve") < reserve || (_pay == "jade" && this.countItems("misc.pale_jade") < 1) || (_pay == "chain" && this.countItems("misc.pale_chain") < 1))
        return "材料不够。";
    this.changeReserve(-reserve);
    if (_pay == "jade")
        this.removeMaterial("jade");
    else if (_pay == "chain")
        this.removeMaterial("chain");
    local rec = list.remove(_index);
    this.savePendingList("Convert", list);
    local bro = this.convertToUndead(rec, true);
    return "黑气灌进冷透的躯体，断掉的筋骨一节节接回原处。" + bro.getName() + " 睁开眼，眼窝里亮起了魂火，第一件事是去摸自己用惯的兵器。\n\n（"
        + bro.getName() + " 转为【" + bro.getBackground().getName() + "】，" + bro.getLevel() + " 级，获得【旧日同袍】。其余活人兄弟的心情随之起伏）";
};

// 新一场战斗开始时，上一场没转化的遗体下葬
local beginBattleBond = S.beginBattle;
S.beginBattle = function( _night )
{
    beginBattleBond.call(this, _night);
    if (::World.Flags.getAsInt("Pale.Convert.Count") > 0)
        this.savePendingList("Convert", []);
    this.set("ConvertNotice", 0);
};

// 生前契约仪式：带永久伤势的活人自愿入殓，转为低阶常驻亡灵
S.injuredLiving <- function()
{
    return this.humans().filter(@(_, bro) S.isLivingBro(bro) && bro.getSkills().query(::Const.SkillType.PermanentInjury).len() > 0);
};

S.ritualPanel <- function( _event, _screen )
{
    _screen.Text = "有些伤一辈子也好不了。导师可以替愿意的人了结这副残躯，让他换一副不会疼的身体，继续跟着老弟兄们走。\n\n"
        + "（转为低阶常驻亡灵：清除全部永久伤势，保留名字、击杀数、约 70% 的等级与较高的天赋星，继承 1 个生前特质，并获得【旧日同袍】。"
        + "每名消耗 " + this.ConvertCost.Ritual + " 点防腐尸骸，身上的装备放回仓库）\n" + this.resourceLine();
    if (this.get("Reserve") < this.ConvertCost.Ritual)
        return;
    this.pagedUnits(_screen, this.injuredLiving(), this.EmbalmPage,
        @(bro) bro.getName() + "（" + bro.getLevel() + " 级，永久伤势 " + bro.getSkills().query(::Const.SkillType.PermanentInjury).len() + " 处）",
        function( bro )
        {
            if (!S.changeReserve(-S.ConvertCost.Ritual))
                return null;
            local rec = S.snapshotBro(bro);
            bro.getItems().transferToStash(::World.Assets.getStash());
            ::World.getPlayerRoster().remove(bro);
            local undead = S.convertToUndead(rec, false);
            return "他躺上油布时没有出声。黑气退去以后，" + undead.getName() + " 坐了起来，不再瘸，也不再咳。\n\n（" + undead.getName() + " 转为常驻亡灵，" + undead.getLevel() + " 级，获得【旧日同袍】）";
        });
};

S.addPage("x_convert", "阵亡回收", "soul_muster", @(_event, _screen) S.convertPanel(_event, _screen));
S.addPage("x_ritual", "生前契约仪式", "mortuary", @(_event, _screen) S.ritualPanel(_event, _screen));

local campPanelBond = S.campPanel;
S.campPanel = function( _event, _screen )
{
    local pending = ::World.Flags.getAsInt("Pale.Convert.Count");
    if (pending > 0)
        this.option(_screen, "阵亡回收（" + pending + "）", @() "@x_convert");
    if (this.oath() != this.Oath.None && this.injuredLiving().len() > 0)
        this.option(_screen, "生前契约仪式", function() { S.EmbalmPage = 0; return "@x_ritual"; });
    return campPanelBond.call(this, _event, _screen);
};

local worldEventBond = S.worldEvent;
S.worldEvent = function()
{
    if (this.get("ConvertNotice") != 0 && this.chief() != null && ::World.State.m.LastEnteredTown == null)
    {
        if (::World.Flags.getAsInt("Pale.Convert.Count") == 0)
            this.set("ConvertNotice", 0);
        else if (this.openEvent("x_convert"))
        {
            this.set("ConvertNotice", 0);
            return;
        }
    }
    return worldEventBond.call(this);
};

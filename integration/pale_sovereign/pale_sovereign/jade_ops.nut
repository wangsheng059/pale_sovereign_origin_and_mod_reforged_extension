local S = ::PaleSovereign;

// 1.7.0 古代魂玉的双路线用途：冠军「魂玉铭刻」「灵阶突破」；天灾「魂玉统领」「锁魂者破限」；炼化的虚弱期

// ---------------- 冠军：魂玉铭刻 ----------------
S.InscriptionOrder <- ["dread", "resonance", "pact", "edge"];
S.Inscriptions <- {
    dread = { Name = "玉骨威压", Desc = "勇士出棺或击杀敌人时，2 格内的非亡灵敌人做一次 −10 的士气检定（导师在 4 格内时 −15），失败者 2 回合内造成的伤害 −50%。" },
    resonance = { Name = "苍白共鸣", Desc = "勇士每回合第一次攻击猎物时命中 +15、穿甲 +15 个百分点，命中后返还 2 行动点。" },
    pact = { Name = "守墓死契", Desc = "勇士在导师 2 格内时，导师受到的生命伤害有 35% 转由勇士承受；每替导师分担一次，勇士获得 1 层护主之怒（伤害 +10%、近战技能 +5，最多 3 层，持续到战斗结束）。" },
    edge = { Name = "裂魂锋芒", Desc = "勇士攻击生命不高于 50% 或带猎物标记的目标时穿甲 +15 个百分点；击杀敌人时恢复 15% 最大生命，头、身护甲各修复 25 点。" }
};
S.inscriptionCap <- @() this.isAscended() ? 4 : 3;
S.inscriptionCount <- function( _pet )
{
    local n = 0;
    foreach (key in this.InscriptionOrder)
        if (this.petGet(_pet, "Inscribe." + key) != 0)
            ++n;
    return n;
};

// ---------------- 冠军：灵阶突破 ----------------
S.BreakCost <- { Marrow = 2, Shell = 3, MarrowLimit = 5 };
S.canBreakthrough <- @(_pet) this.isLich(_pet) || this.petGet(_pet, "Devours") >= 1;
S.canJadeShell <- @(_pet) this.petGet(_pet, "Devours") >= 2 || this.isAscended();

S.jadeChampionPanel <- function( _event, _screen )
{
    local pet = this.mainPet();
    local jade = this.countItems("misc.pale_jade");
    if (pet == null)
    {
        _screen.Text = "先把勇士的棺椁装进导师的饰品栏。";
        return;
    }
    _screen.Text = "魂玉不再只是磨成粉抹进骨缝。把它刻进勇士的骨头，它会记住一种杀戮的方式；把它熔进骨髓，它会跨过生前的极限。\n\n"
        + pet.m.Name + "　铭刻 " + this.inscriptionCount(pet) + " / " + this.inscriptionCap()
        + "　玉髓重铸 " + this.petGet(pet, "Breakthrough") + " / " + this.BreakCost.MarrowLimit
        + "　不朽玉壳 " + (this.petGet(pet, "JadeShell") != 0 ? "已成" : "未成") + "\n" + this.resourceLine();
    if (this.inscriptionCount(pet) < this.inscriptionCap())
        foreach (key in this.InscriptionOrder)
        {
            if (this.petGet(pet, "Inscribe." + key) != 0)
                continue;
            local inscription = key;
            local def = this.Inscriptions[key];
            _screen.Text += "\n\n【" + def.Name + "】" + def.Desc;
            if (jade >= 1)
                this.option(_screen, "铭刻【" + def.Name + "】· 1 枚魂玉", function()
                {
                    if (S.inscriptionCount(pet) >= S.inscriptionCap() || !S.removeMaterial("jade"))
                        return null;
                    S.petSet(pet, "Inscribe." + inscription, 1);
                    return "你用骨针把魂玉的碎屑一点点刻进勇士的颅骨。碧光沿着刻痕亮了一夜才慢慢沉下去。\n\n（" + pet.m.Name + " 获得铭刻【" + S.Inscriptions[inscription].Name + "】）";
                });
        }
    if (!this.canBreakthrough(pet))
        _screen.Text += "\n\n灵阶突破需要勇士已晋升尸妖王，或至少吞魂 1 次。";
    else
    {
        local marrow = this.petGet(pet, "Breakthrough");
        if (marrow < this.BreakCost.MarrowLimit && jade >= this.BreakCost.Marrow)
            this.option(_screen, "一阶·玉髓重铸（" + marrow + " / 5）· 2 枚魂玉：生命 +20、伤害 +10%、行动点 +1", function()
            {
                if (S.petGet(pet, "Breakthrough") >= S.BreakCost.MarrowLimit || S.countItems("misc.pale_jade") < S.BreakCost.Marrow)
                    return null;
                for (local i = 0; i < S.BreakCost.Marrow; ++i)
                    S.removeMaterial("jade");
                S.petSet(pet, "Breakthrough", S.petGet(pet, "Breakthrough") + 1);
                pet.m.Attributes.Hitpoints += 20;
                pet.updateCompanion();
                return "两枚魂玉在铁钵里熔成碧色的浆，顺着骨缝灌进勇士的髓腔。它的骨头发出一阵低沉的鸣响。\n\n（永久生命 +20、伤害 +10%、行动点 +1，已重铸 " + S.petGet(pet, "Breakthrough") + " / 5 次）";
            });
        if (this.petGet(pet, "JadeShell") == 0)
        {
            if (!this.canJadeShell(pet))
                _screen.Text += "\n\n二阶·不朽玉壳需要勇士至少吞魂 2 次，或导师已飞升。";
            else if (jade >= this.BreakCost.Shell)
                this.option(_screen, "二阶·不朽玉壳 · 3 枚魂玉：每场第一次致命伤改为锁定 20% 生命", function()
                {
                    if (S.countItems("misc.pale_jade") < S.BreakCost.Shell)
                        return null;
                    for (local i = 0; i < S.BreakCost.Shell; ++i)
                        S.removeMaterial("jade");
                    S.petSet(pet, "JadeShell", 1);
                    return "魂玉碾成的碧粉在勇士的骨架外结了一层薄壳，摸上去像冷玉。\n\n（每场战斗第一次受到致命伤害时免于死亡，生命锁定为 20%，清除眩晕、定身、流血，并在 1 回合内受到的伤害 −50%）";
                });
        }
    }
};

// 放出冠军时挂上铭刻与突破效果
S.applyJadePet <- function( _pet, _entity )
{
    local skills = _entity.getSkills();
    local keys = this.InscriptionOrder.filter(@(_, key) S.petGet(_pet, "Inscribe." + key) != 0);
    if (keys.len() > 0 && !skills.hasSkill("effects.pale_inscription"))
    {
        local effect = ::new(this.SkillDir + "effects/pale_inscription_effect");
        effect.setKeys(keys);
        skills.add(effect);
        if (keys.find("pact") != null)
        {
            local chief = this.chief();
            if (chief != null && chief.isPlacedOnMap())
            {
                local pact = chief.getSkills().getSkillByID("effects.pale_grave_pact");
                if (pact == null)
                {
                    pact = ::new(this.SkillDir + "effects/pale_grave_pact_effect");
                    chief.getSkills().add(pact);
                }
                pact.setChampion(_entity);
            }
        }
        if (keys.find("dread") != null)
            effect.terrify();
    }
    local marrow = this.petGet(_pet, "Breakthrough");
    if (marrow > 0 && !skills.hasSkill("effects.pale_breakthrough"))
    {
        local effect = ::new(this.SkillDir + "effects/pale_breakthrough_effect");
        effect.m.Stacks = marrow;
        skills.add(effect);
    }
    if (this.petGet(_pet, "JadeShell") != 0 && !skills.hasSkill("effects.pale_jade_shell"))
        skills.add(::new(this.SkillDir + "effects/pale_jade_shell_effect"));
};

local applyPetProgressJade = S.applyPetProgress;
S.applyPetProgress = function( _pet, _entity )
{
    applyPetProgressJade.call(this, _pet, _entity);
    if (_pet.m.PaleID != 0)
        this.applyJadePet(_pet, _entity);
};

// ---------------- 天灾：魂玉统领 ----------------
S.LeaderCost <- 3;
S.LeaderLevel <- 7;
S.LeaderAuras <- [
    null,
    { Name = "执念共鸣", Desc = "2 格内的友方常驻亡灵共享统领的第 1 个正面亡灵专属特质；已拥有或互斥时改为伤害 +8%。" },
    { Name = "噬生回流", Desc = "2 格内的友方常驻亡灵与召唤物每击杀一名敌人，击杀者恢复 12 生命、统领恢复 8 生命；范围内常驻亡灵受到的死灵治疗 +25%。" },
    { Name = "死兆导引", Desc = "统领 3 格内被尸弹命中、或处于衰弱术 / 尸毒 / 岁月诅咒的敌人，受到友方亡灵的伤害 +15%，受到尸爆的伤害 +25%。" }
];
S.leaderCap <- @() this.isAscended() ? 4 : 2;
S.leaderAura <- function( _bro )
{
    return _bro.getFlags().has("PaleLeader") ? _bro.getFlags().getAsInt("PaleLeader") : 0;
};
S.leaders <- @() this.undead().filter(@(_, bro) S.leaderAura(bro) > 0);

S.leaderPanel <- function( _event, _screen )
{
    local jade = this.countItems("misc.pale_jade");
    _screen.Text = "把三枚魂玉嵌进一名老练亡灵的胸腔，它就成了亡者队列里的一枚灵核，身边的同类会跟着它的魂火一起燃烧。\n\n"
        + "（册封需 " + this.LeaderCost + " 枚魂玉、目标 " + this.LeaderLevel + " 级以上；统领 8 项属性各 +2、生命再 +10。全团最多 " + this.leaderCap() + " 名，当前 " + this.leaders().len() + " 名。切换光环 1 枚魂玉）\n" + this.resourceLine();
    for (local i = 1; i < this.LeaderAuras.len(); ++i)
        _screen.Text += "\n\n【" + this.LeaderAuras[i].Name + "】" + this.LeaderAuras[i].Desc;
    foreach (bro in this.leaders())
    {
        local leader = bro;
        _screen.Text += "\n\n统领：" + leader.getName() + "（" + this.LeaderAuras[this.leaderAura(leader)].Name + "）";
        if (jade >= 1)
            this.option(_screen, "为 " + leader.getName() + " 切换光环 · 1 枚魂玉", function() { S.PickUnitID = leader.getID(); S.PickValue = "switch"; return "@x_leader_aura"; });
    }
    if (this.leaders().len() < this.leaderCap() && jade >= this.LeaderCost)
    {
        local units = this.undead().filter(@(_, bro) S.leaderAura(bro) == 0 && bro.getLevel() >= S.LeaderLevel && !S.isSoulbound(bro));
        this.pagedUnits(_screen, units, this.EmbalmPage, @(bro) "册封 " + bro.getName() + "（" + bro.getLevel() + " 级）",
            function( bro ) { S.PickUnitID = bro.getID(); S.PickValue = "crown"; return "@x_leader_aura"; });
    }
};

S.leaderAuraPanel <- function( _event, _screen )
{
    local bro = this.findUndeadByID(this.PickUnitID);
    if (bro == null)
    {
        _screen.Text = "人选已经不在了。";
        return;
    }
    local crown = this.PickValue == "crown";
    _screen.Text = "为 " + bro.getName() + " 选定光环。" + (crown ? "（册封消耗 3 枚魂玉）" : "（切换消耗 1 枚魂玉）");
    for (local i = 1; i < this.LeaderAuras.len(); ++i)
    {
        if (!crown && this.leaderAura(bro) == i)
            continue;
        local aura = i;
        this.option(_screen, "【" + this.LeaderAuras[i].Name + "】", function()
        {
            local cost = crown ? S.LeaderCost : 1;
            if (S.countItems("misc.pale_jade") < cost || (crown && (S.leaders().len() >= S.leaderCap() || S.leaderAura(bro) != 0)))
                return null;
            for (local n = 0; n < cost; ++n)
                S.removeMaterial("jade");
            if (crown)
            {
                local b = bro.getBaseProperties();
                foreach (key in S.Attributes)
                    b[key] += 2;
                b.Hitpoints += 10;
                bro.getSkills().update();
            }
            bro.getFlags().set("PaleLeader", aura);
            return (crown ? "三枚魂玉被嵌进 " + bro.getName() + " 的胸腔，它的魂火变成了碧色。\n\n（" + bro.getName() + " 成为魂玉统领：8 项属性各 +2、生命再 +10，光环【" : "统领胸腔里的魂玉换了颜色。\n\n（光环改为【")
                + S.LeaderAuras[aura].Name + "】）";
        });
    }
};

// ---------------- 天灾：锁魂者破限 ----------------
S.limitBreaks <- function( _bro )
{
    return _bro.getFlags().has("PaleLimitBreak") ? _bro.getFlags().getAsInt("PaleLimitBreak") : 0;
};

S.limitPanel <- function( _event, _screen )
{
    local jade = this.countItems("misc.pale_jade");
    _screen.Text = "锁魂者只带着生前八成的力量回来。用魂玉补上缺掉的那一截残魂，它们还能再往前走一步。\n\n"
        + "一阶·补魂（1 枚魂玉）：6 项主属性各 +3、生命再 +15，并获得 1 个特技点。\n二阶·玉魂不灭（2 枚魂玉，需 9 级）：再得 1 个特技点；每场第一次被击倒时，只要导师在场就以 35% 生命站起（带缚魂镣铐时改为 50% 生命、恢复 25 疲劳，并在 2 回合内受到的伤害 −50%）。\n" + this.resourceLine();
    foreach (bro in this.undead())
    {
        if (!this.isSoulbound(bro))
            continue;
        local unit = bro;
        local stage = this.limitBreaks(unit);
        if (stage == 0 && jade >= 1)
            this.option(_screen, unit.getName() + " · 补魂（1 枚魂玉）", function()
            {
                if (S.limitBreaks(unit) != 0 || !S.removeMaterial("jade"))
                    return null;
                local props = unit.getBaseProperties();
                foreach (key in S.SoulboundStatKeys)
                    props[key] += 3;
                props.Hitpoints += 15;
                unit.m.PerkPoints += 1;
                unit.getFlags().set("PaleLimitBreak", 1);
                unit.getSkills().update();
                return "魂玉碎在锁魂者的胸骨上，缺掉的残魂一点点补了回来。\n\n（" + unit.getName() + " 6 项主属性各 +3、生命再 +15，获得 1 个特技点）";
            });
        else if (stage == 1 && jade >= 2 && unit.getLevel() >= 9)
            this.option(_screen, unit.getName() + " · 玉魂不灭（2 枚魂玉）", function()
            {
                if (S.limitBreaks(unit) != 1 || S.countItems("misc.pale_jade") < 2)
                    return null;
                S.removeMaterial("jade");
                S.removeMaterial("jade");
                unit.m.PerkPoints += 1;
                unit.getFlags().set("PaleLimitBreak", 2);
                unit.getSkills().update();
                return "两枚魂玉沉进锁魂者的颅腔，它眼里的魂火再也不会被一刀砍灭。\n\n（" + unit.getName() + " 获得 1 个特技点与【玉魂不灭】）";
            });
        else if (stage == 1 && unit.getLevel() < 9)
            _screen.Text += "\n\n" + unit.getName() + " 需要 9 级才能二阶破限。";
    }
};

S.addPage("x_jade_champion", "魂玉铭刻与灵阶突破", "jade_inscriptions", @(_event, _screen) S.jadeChampionPanel(_event, _screen));
S.addPage("x_leader", "魂玉统领", "jade_leader", @(_event, _screen) S.leaderPanel(_event, _screen));
S.addPage("x_leader_aura", "魂玉统领", "jade_leader", @(_event, _screen) S.leaderAuraPanel(_event, _screen), "@x_leader");
S.addPage("x_limit", "锁魂者破限", "jade_limit", @(_event, _screen) S.limitPanel(_event, _screen));

local campPanelJade = S.campPanel;
S.campPanel = function( _event, _screen )
{
    if (this.oath() == this.Oath.Champion && this.mainPet() != null)
        this.option(_screen, "魂玉铭刻与灵阶突破", @() "@x_jade_champion");
    if (this.oath() == this.Oath.Scourge && this.undead().len() > 0)
        this.option(_screen, "册封魂玉统领", function() { S.EmbalmPage = 0; return "@x_leader"; });
    if (this.oath() == this.Oath.Scourge && this.undead().filter(@(_, bro) S.isSoulbound(bro)).len() > 0)
        this.option(_screen, "锁魂者破限", @() "@x_limit");
    return campPanelJade.call(this, _event, _screen);
};

// ---------------- 炼化：虚弱期 ----------------
S.isRefineWeak <- function()
{
    local now = ::World.getTime().Days + ::World.getTime().Hours / 24.0;
    return !this.isAscended() && ::World.Flags.getAsFloat("Pale.RefineWeakUntil") > now;
};

local canRefineJade = S.canRefine;
S.canRefine = function()
{
    return !this.isRefineWeak() && canRefineJade.call(this);
};

local refineJade = S.refineUndead;
S.refineUndead = function( _bro )
{
    local before = this.countItems("misc.pale_jade");
    local result = refineJade.call(this, _bro);
    if (this.countItems("misc.pale_jade") > before && !this.isAscended())
    {
        ::World.Flags.set("Pale.RefineWeakUntil", ::World.getTime().Days + ::World.getTime().Hours / 24.0 + 2.0);
        local chief = this.chief();
        if (chief != null)
            chief.getSkills().update();
        result += "\n\n（抽取魂火耗尽了导师的心神：2 天内决心与疲劳值上限 −15%，虚弱消退前不能再次炼化。飞升后不再有这个代价）";
    }
    return result;
};

// ---------------- 战斗：统领光环 ----------------
S.isLeaderActor <- function( _actor )
{
    return this.tierActorOnMap(_actor) && _actor.getSkills().hasSkill("effects.pale_jade_leader");
};

S.fieldLeaders <- function( _aura )
{
    local ret = [];
    foreach (bro in ::World.getPlayerRoster().getAll())
        if (this.isLeaderActor(bro) && this.leaderAura(bro) == _aura)
            ret.push(bro);
    return ret;
};

S.nearLeader <- function( _actor, _aura, _range )
{
    if (!this.tierActorOnMap(_actor))
        return null;
    foreach (leader in this.fieldLeaders(_aura))
        if (leader.getID() != _actor.getID() && leader.getTile().getDistanceTo(_actor.getTile()) <= _range)
            return leader;
    return null;
};

S.firstPositivePaleTrait <- function( _bro )
{
    foreach (trait in _bro.getSkills().query(::Const.SkillType.Trait))
    {
        local id = trait.getID();
        if (id.find("trait.pale_") == 0 && !this.isNegativeUndeadTrait(id) && !("PaleShared" in trait.m))
            return trait;
    }
    return null;
};

S.refreshLeaderAuras <- function()
{
    if (this.Battle == null || !::Tactical.isActive())
        return;
    local anyLeader = false;
    foreach (bro in ::World.getPlayerRoster().getAll())
        if (this.isLeaderActor(bro))
            anyLeader = true;
    if (!anyLeader && !("HadLeaders" in this.Battle))
        return;
    this.Battle.HadLeaders <- true;
    foreach (faction in ::Tactical.Entities.getAllInstances())
    {
        foreach (actor in faction)
        {
            if (!this.tierActorOnMap(actor))
                continue;
            local skills = actor.getSkills();
            if (this.isFriendlyUndead(actor) && this.isUndead(actor))
            {
                // 执念共鸣
                local leader = this.nearLeader(actor, 1, 2);
                local shared = skills.getSkillsByFunction(@(skill) "PaleShared" in skill.m);
                local trait = leader == null ? null : this.firstPositivePaleTrait(leader);
                local wantID = trait == null ? null : trait.getID();
                foreach (skill in shared)
                    if (skill.getID() != wantID && skill.getID() != "effects.pale_leader_echo")
                        skill.removeSelf();
                local echo = skills.getSkillByID("effects.pale_leader_echo");
                local needEcho = false;
                if (trait != null)
                {
                    local owned = skills.getSkillByID(wantID);
                    local blocked = false;
                    foreach (other in skills.query(::Const.SkillType.Trait))
                        if (this.traitExcludes(other, wantID) || this.traitExcludes(trait, other.getID()))
                            blocked = true;
                    if (owned == null && !blocked)
                    {
                        try
                        {
                            local copy = ::new(::IO.scriptFilenameByHash(trait.ClassNameHash));
                            copy.m.PaleShared <- true;
                            copy.m.IsSerialized = false;
                            skills.add(copy);
                        }
                        catch (e)
                        {
                            needEcho = true;
                        }
                    }
                    else if (owned == null || !("PaleShared" in owned.m))
                        needEcho = true;
                }
                if (needEcho && echo == null)
                {
                    skills.add(::new(this.SkillDir + "effects/pale_leader_echo_effect"));
                }
                else if (!needEcho && echo != null)
                    echo.removeSelf();
            }
            else
            {
                local chief = this.chief();
                if (chief == null || actor.isAlliedWith(chief))
                    continue;
                // 死兆导引
                local doomed = this.nearLeader(actor, 3, 3) != null && (skills.hasSkill("effects.pale_shot_mark") || skills.hasSkill("effects.pale_weaken")
                    || skills.hasSkill("effects.pale_corpse_poison") || skills.hasSkill("effects.bgp_curse_of_ages"));
                local mark = skills.getSkillByID("effects.pale_doom_mark");
                if (doomed && mark == null)
                    skills.add(::new(this.SkillDir + "effects/pale_doom_mark_effect"));
                else if (!doomed && mark != null)
                    mark.removeSelf();
            }
        }
    }
};

S.clearLeaderShares <- function()
{
    foreach (bro in ::World.getPlayerRoster().getAll())
    {
        local skills = bro.getSkills();
        foreach (skill in skills.getSkillsByFunction(@(skill) "PaleShared" in skill.m))
            skill.removeSelf();
        skills.collectGarbage();
        skills.removeByID("effects.pale_leader_echo");
    }
};

S.Mod.hook("scripts/skills/skill_container", function(q)
{
    q.onCombatStarted = @(__original) function()
    {
        local actor = this.getActor();
        if (S.Battle != null && S.isUndead(actor) && S.leaderAura(actor) > 0 && !this.hasSkill("effects.pale_jade_leader"))
            this.add(::new(S.SkillDir + "effects/pale_jade_leader_effect"));
        if (S.Battle != null && S.isUndead(actor) && S.limitBreaks(actor) >= 2 && !this.hasSkill("effects.pale_jade_undying"))
            this.add(::new(S.SkillDir + "effects/pale_jade_undying_effect"));
        __original();
    };
    q.onMovementFinished = @(__original) function()
    {
        __original();
        S.refreshLeaderAuras();
    };
    q.onTurnStart = @(__original) function()
    {
        __original();
        S.refreshLeaderAuras();
    };
});

// 噬生回流：击杀者与统领回血；死兆导引与尸弹标记
S.KillHooks <- [];
S.onPaleKill <- function( _killer, _victim )
{
    if (_killer == null || ::MSU.isNull(_killer) || !_killer.isAlive() || !this.isFriendlyUndead(_killer))
        return;
    local leader = this.nearLeader(_killer, 2, 2);
    if (leader == null && this.leaderAura(_killer) == 2 && this.isLeaderActor(_killer))
        leader = _killer;
    if (leader == null)
        return;
    _killer.setHitpoints(::Math.min(_killer.getHitpointsMax(), _killer.getHitpoints() + 12));
    leader.setHitpoints(::Math.min(leader.getHitpointsMax(), leader.getHitpoints() + 8));
    this.playActorArt("leader_echo", _killer, 26, 0.95);
    _killer.setDirty(true);
    leader.setDirty(true);
};
S.KillHooks.push(S.onPaleKill);

S.Mod.hook("scripts/entity/tactical/actor", function(q)
{
    q.kill = @(__original) function( _killer = null, _skill = null, _fatality = ::Const.FatalityType.None, _silent = false )
    {
        // 不朽玉壳（冠军）与玉魂不灭（锁魂者）：先于死亡判定
        if (S.Battle != null && this.isAlive() && !this.isDying() && this.isPlacedOnMap() && S.preventPaleDeath(this))
            return;
        local wasAlive = this.isAlive() && !this.isDying() && this.isPlacedOnMap() && S.Battle != null;
        local result = __original(_killer, _skill, _fatality, _silent);
        if (wasAlive && (!this.isAlive() || this.isDying()))
            foreach (hook in S.KillHooks)
            {
                try { hook.call(S, _killer, this); } catch (e) { ::logError("[PaleSovereign] kill hook: " + e); }
            }
        return result;
    };
});

S.preventPaleDeath <- function( _actor )
{
    local skills = _actor.getSkills();
    local shell = skills.getSkillByID("effects.pale_jade_shell");
    if (shell != null && !shell.m.Spent)
    {
        shell.m.Spent = true;
        _actor.setHitpoints(::Math.max(1, ::Math.floor(_actor.getHitpointsMax() * 0.2)));
        local cleanse = ["effects.stunned", "effects.rooted", "effects.net", "effects.bleeding"];
        foreach (skill in skills.getSkillsByFunction(@(sk) cleanse.find(sk.getID()) != null))
            skill.removeSelf();
        skills.collectGarbage();
        skills.add(::new(this.SkillDir + "effects/pale_jade_guard_effect"));
        skills.update();
        _actor.setDirty(true);
        ::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(_actor) + " 的玉壳碎了，替它挡下了致命一击。");
        return true;
    }
    local undying = skills.getSkillByID("effects.pale_jade_undying");
    local chief = this.chief();
    if (undying != null && !undying.m.Spent && chief != null && chief.isAlive() && chief.isPlacedOnMap())
    {
        undying.m.Spent = true;
        this.playActorArt("jade_undying", _actor, 25, 1.10);
        local shackle = skills.getSkillByID("effects.pale_shackle");
        local merged = shackle != null && !shackle.m.Spent;
        if (merged)
            shackle.m.Spent = true;
        _actor.setHitpoints(::Math.max(1, ::Math.floor(_actor.getHitpointsMax() * (merged ? 0.5 : 0.35))));
        if (merged)
        {
            _actor.setFatigue(::Math.max(0, _actor.getFatigue() - 25));
            local guard = ::new(this.SkillDir + "effects/pale_jade_guard_effect");
            guard.m.Turns = 2;
            skills.add(guard);
        }
        skills.update();
        _actor.setDirty(true);
        ::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(_actor) + " 眼里的魂火没有熄灭，它又站了起来。");
        return true;
    }
    return false;
};

// 噬生回流：范围内常驻亡灵受到的死灵治疗 +25%
local bgpHealLeader = ::BGP.heal;
::BGP.heal = function( _a, _amount )
{
    try
    {
        if (_amount > 0 && S.Battle != null && S.isUndead(_a) && S.nearLeader(_a, 2, 2) != null)
            _amount = ::Math.floor(_amount * 1.25);
    }
    catch (e)
    {
    }
    return bgpHealLeader(_a, _amount);
};

// 尸弹命中留下 2 回合标记（死兆导引用）
S.Mod.hook("scripts/skills/actives/pale_corpse_shot", function(q)
{
    q.onTargetHit = @(__original) function( _skill, _targetEntity, _bodyPart, _damageInflictedHitpoints, _damageInflictedArmor )
    {
        __original(_skill, _targetEntity, _bodyPart, _damageInflictedHitpoints, _damageInflictedArmor);
        if (_skill == this && _targetEntity != null && !::MSU.isNull(_targetEntity) && _targetEntity.isAlive())
        {
            local mark = _targetEntity.getSkills().getSkillByID("effects.pale_shot_mark");
            if (mark == null)
                _targetEntity.getSkills().add(::new(S.SkillDir + "effects/pale_shot_mark_effect"));
            else
                mark.m.Turns = 2;
        }
    };
});

S.Mod.hook("scripts/states/world_state", function(q)
{
    q.onCombatFinished = @(__original) function()
    {
        if (S.isActive())
        {
            try { S.clearLeaderShares(); } catch (e) { ::logError("[PaleSovereign] clear leader shares: " + e); }
        }
        return __original();
    };
});

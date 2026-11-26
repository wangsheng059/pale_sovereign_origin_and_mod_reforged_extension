local S = ::PaleSovereign;

// 1.6.30 防腐尸骸 × 角色养成：营地的肢体替换、优质拼装，以及古堡盐窖的六种临时防腐秘仪
S.LimbCost <- 4;
S.GraftCost <- 6;
S.GraftLimit <- 2;
// 1.7.0 解剖师 / 炼金术士在队时各 −1 点（最低 2 点），见 living_bond.nut
S.limbCost <- @() ::Math.max(2, this.LimbCost - this.anatomistDiscount());
S.graftCost <- @() ::Math.max(2, this.GraftCost - this.anatomistDiscount());
S.anatomistDiscount <- @() 0;
S.EmbalmPageSize <- 4;
S.EmbalmPage <- 0;
S.EmbalmUnit <- 0;

// 临时秘仪：Single / All 为指定 1 名 / 全体常驻亡灵的花费，Battles 为参战场数
S.Rites <- [
    { Key = "armor", Icon = "skills/pale_rite_armor.png", Name = "厚骨覆甲", Single = 3, All = 6, Battles = 3,
        Effect = "每场战斗开局头部与身体各获得 +40 临时护甲（先于装备承受伤害）；战斗全程受到攻击的穿甲比例减少 15 个百分点（如 30% → 15%），免疫爆头额外伤害" },
    { Key = "infuse", Icon = "skills/pale_rite_infuse.png", Name = "死气灌注", Single = 4, All = 8, Battles = 3,
        Effect = "开局获得 3 层【充盈死气】。近战或远程攻击命中敌人时消耗 1 层，额外造成 8 + 导师决心 × 10% 点无视护甲伤害，目标疲劳 +10 并进行一次低难度士气检定" },
    { Key = "poison", Icon = "skills/pale_rite_poison.png", Name = "恶臭涂抹", Single = 3, All = 6, Battles = 3,
        Effect = "近战或远程命中非亡灵敌人时附加 2 回合【尸毒】：行动点 −2，每回合疲劳恢复 −5" },
    { Key = "imprint", Icon = "skills/pale_rite_imprint.png", Name = "残忆拓印", Single = 2, All = 4, Battles = 3,
        Effect = "战斗经验 +40%；1–6 级的常驻亡灵再 +20%（共 +60%）" },
    { Key = "fumigate", Icon = "skills/pale_rite_fumigate.png", Name = "尸脂熏蒸", Single = 3, All = 6, Battles = 3,
        Effect = "远程防御 +15；免疫火焰（燃烧地面、燃烧瓶等燃烧伤害）与酸液（酸液瓶、林德蠕龙酸液）；自己回合开始和结束时，在相邻敌人脚下铺开持续 2 回合的【苍白冷焰】（只灼伤非亡灵敌人，在其中结束回合受到 15–30 点火焰伤害）" },
    { Key = "tendon", Icon = "skills/pale_rite_tendon.png", Name = "韧筋接驳", Single = 2, All = 4, Battles = 3,
        Effect = "获得探路者的移动消耗；已有探路者时每格行动点再 −1（最低 1）、疲劳再减半；免疫击退与抓取；挣脱投网、藤蔓等的行动点消耗减半" }
];

S.RiteFlavor <- [
    "防腐师把浸过盐卤的碎骨片一层层压进它的胸廓与颅壳，再用铜丝缠紧。骨片冰冷坚硬，像是给这具躯壳又套了一层看不见的甲。",
    "导师把一捧研碎的尸骸撒进魂火，火苗变得又黑又稠。防腐师用骨针把这团死气一点点缝进亡灵的骨缝，等着下一次挥击时倾泻出去。",
    "腌了多年的尸油被熬成黏稠的黑膏，抹在刃口与箭簇上，散发出令人作呕的甜腥气。被它划开的活人，连喘气都会变得艰难。",
    "防腐师在尸骸的颅骨上刻下细密的纹路，再把它与亡灵的头骨相抵，低声念诵。死者生前记住的那些劈砍、闪躲和喘息，正一缕缕渗进新的魂火。",
    "盐窖深处点起了尸脂与防腐草药，浓烟又冷又重，贴着地面流淌。亡灵在烟里站了一整夜，骨隙间渗满了驱不散的黑雾，连火焰都舔不进去。",
    "从尸骸上剥下的肌腱经过粗盐鞣制，坚韧得像牛皮绳。防腐师把它们重新捆扎在磨损的关节上，亡灵抬脚落脚都稳了许多。"
];

S.riteFlag <- @(_key) "PaleRite." + _key;

S.riteCharges <- function( _bro, _key )
{
    local flags = _bro.getFlags();
    return flags.has(this.riteFlag(_key)) ? flags.getAsInt(this.riteFlag(_key)) : 0;
};

S.riteSummary <- function( _bro )
{
    local parts = [];
    foreach (rite in this.Rites)
    {
        local left = this.riteCharges(_bro, rite.Key);
        if (left > 0)
            parts.push(rite.Name + " " + left);
    }
    return parts.len() == 0 ? "" : "（" + parts.reduce(@(a, b) a + "、" + b) + "）";
};

S.applyRite <- function( _index, _target )
{
    local rite = this.Rites[_index];
    local units = _target == null ? this.undead() : [_target];
    local cost = _target == null ? rite.All : rite.Single;
    if (units.len() == 0)
        return "没有可以接受秘仪的常驻亡灵。";
    if (!this.changeReserve(-cost))
        return "防腐尸骸不足（需要 " + cost + " 点，库存 " + this.get("Reserve") + " 点）。";
    foreach (bro in units)
        bro.getFlags().set(this.riteFlag(rite.Key), rite.Battles);
    ::World.State.updateTopbarAssets();
    return this.RiteFlavor[_index] + "\n\n（消耗 " + cost + " 点防腐尸骸。"
        + (_target == null ? "全体 " + units.len() + " 名常驻亡灵" : _target.getName())
        + "获得【" + rite.Name + "】，持续接下来参战的 " + rite.Battles + " 场战斗；已有同名秘仪的改为重新计数。防腐尸骸剩余 " + this.get("Reserve") + " 点）";
};

// ---------------- 营地：肢体替换 / 优质拼装 ----------------

S.negativeTraitsOf <- function( _bro )
{
    return _bro.getSkills().query(::Const.SkillType.Trait).filter(@(_, trait) S.isNegativeUndeadTrait(trait.getID()));
};

S.limbTargets <- function()
{
    local units = this.undead().filter(@(_, bro) bro.isAlive() && S.negativeTraitsOf(bro).len() > 0);
    units.sort(@(a, b) b.getLevel() <=> a.getLevel());
    return units;
};

S.graftCandidates <- function( _bro )
{
    local kind = this.UndeadKinds[this.undeadKindOf(_bro.getFlags().get("PaleUndeadKind"))];
    local pool = clone this.UndeadTraitPool.Both;
    pool.extend(kind.Skeleton ? this.UndeadTraitPool.Skeleton : this.UndeadTraitPool.Zombie);
    local skills = _bro.getSkills();
    local owned = skills.query(::Const.SkillType.Trait);
    local ret = [];
    foreach (script in pool)
    {
        if (script.find("pale_undead_") != 0)
            continue;
        local trait = null;
        try { trait = ::new("scripts/skills/traits/" + script); } catch (e) { trait = null; }
        if (trait == null || this.isNegativeUndeadTrait(trait.getID()) || skills.hasSkill(trait.getID()))
            continue;
        local fits = true;
        foreach (other in owned)
            if (this.traitExcludes(other, trait.getID()) || this.traitExcludes(trait, other.getID()))
                fits = false;
        if (fits)
            ret.push(trait);
    }
    return ret;
};

S.graftCount <- function( _bro )
{
    return _bro.getFlags().has("PaleGraftCount") ? _bro.getFlags().getAsInt("PaleGraftCount") : 0;
};

S.graftTargets <- function()
{
    local units = this.undead().filter(@(_, bro) bro.isAlive() && S.graftCount(bro) < S.GraftLimit && S.graftCandidates(bro).len() > 0);
    units.sort(@(a, b) b.getLevel() <=> a.getLevel());
    return units;
};

S.findUndeadByID <- function( _id )
{
    foreach (bro in this.undead())
        if (bro.getID() == _id)
            return bro;
    return null;
};

S.pagedUnits <- function( _screen, _units, _page, _label, _pick )
{
    local size = this.EmbalmPageSize;
    local page = ::Math.min(_page, ::Math.max(0, (_units.len() - 1) / size));
    for (local i = page * size; i < ::Math.min(_units.len(), (page + 1) * size); ++i)
    {
        local target = _units[i];
        this.option(_screen, _label(target), @() _pick(target));
    }
    if (page > 0)
        this.option(_screen, "上一页", function() { S.EmbalmPage = page - 1; return "@" + _screen.ID; });
    if ((page + 1) * size < _units.len())
        this.option(_screen, "下一页", function() { S.EmbalmPage = page + 1; return "@" + _screen.ID; });
};

S.limbRosterPanel <- function( _screen )
{
    local units = this.limbTargets();
    _screen.Text = "防腐师把几具保存最好的尸骸摊在油布上，挑出完整的指骨、肋骨与筋肉，等着替换常驻亡灵身上那些早已朽坏的部分。"
        + "\n\n（选一名常驻亡灵，消耗 " + this.limbCost() + " 点防腐尸骸，永久移除它的 1 个负面特质。防腐尸骸 " + this.get("Reserve") + " / " + this.reserveLimit() + "）";
    if (units.len() == 0)
        _screen.Text += "\n\n目前没有带负面特质的常驻亡灵。";
    else if (this.get("Reserve") < this.limbCost())
        _screen.Text += "\n\n防腐尸骸不足。";
    else
        this.pagedUnits(_screen, units, this.EmbalmPage,
            @(bro) bro.getName() + "（" + bro.getLevel() + " 级，负面特质 " + S.negativeTraitsOf(bro).len() + " 个）",
            function( bro ) { S.EmbalmUnit = bro.getID(); return "@limb_pick"; });
    this.option(_screen, "合上油布", @() "@camp");
};

S.limbPickPanel <- function( _screen )
{
    local bro = this.findUndeadByID(this.EmbalmUnit);
    if (bro == null || this.negativeTraitsOf(bro).len() == 0)
    {
        _screen.Text = "这名常驻亡灵已经没有需要替换的部位。";
        this.option(_screen, "返回选择亡灵", @() "@limb_roster");
        return;
    }
    _screen.Text = bro.getName() + " 静静躺在油布上，任由防腐师拆开它的躯壳。要替换掉哪一处朽坏？\n\n（消耗 " + this.limbCost() + " 点防腐尸骸，防腐尸骸 " + this.get("Reserve") + " 点）";
    foreach (trait in this.negativeTraitsOf(bro))
    {
        local id = trait.getID();
        local name = trait.getName();
        this.option(_screen, "替换【" + name + "】", function()
        {
            if (!bro.getSkills().hasSkill(id) || !S.changeReserve(-S.limbCost()))
                return "防腐尸骸不足，或这个特质已经不在了。";
            local skills = bro.getSkills();
            skills.removeByID(id);
            skills.collectGarbage();
            local flags = bro.getFlags();
            if (flags.has("PaleTitleTrait") && flags.get("PaleTitleTrait") == id)
                S.assignUndeadTitle(bro);
            skills.update();
            ::World.State.updateTopbarAssets();
            return "防腐师剜掉朽坏的部分，把从尸骸上取下的骨肉嵌了进去，用浸过松脂的麻线一圈圈缝牢。魂火在新换的部位上停留了片刻，便接纳了它。\n\n（"
                + bro.getName() + " 永久失去【" + name + "】。消耗 " + S.limbCost() + " 点防腐尸骸，剩余 " + S.get("Reserve") + " 点）";
        });
    }
    this.option(_screen, "返回选择亡灵", @() "@limb_roster");
};

S.graftRosterPanel <- function( _screen )
{
    local units = this.graftTargets();
    _screen.Text = "最好的料子从不拿去填坑。防腐师从库存里翻出几具骨相端正、筋肉完整的尸骸，打算拆下来，拼进一名常驻亡灵的躯壳。"
        + "\n\n（选一名常驻亡灵，消耗 " + this.graftCost() + " 点防腐尸骸，随机获得 1 个它还没有、且与现有特质不冲突的正面亡灵特质。每名常驻亡灵限 " + this.GraftLimit + " 次。防腐尸骸 " + this.get("Reserve") + " / " + this.reserveLimit() + "）";
    if (units.len() == 0)
        _screen.Text += "\n\n目前没有还能拼装的常驻亡灵。";
    else if (this.get("Reserve") < this.graftCost())
        _screen.Text += "\n\n防腐尸骸不足。";
    else
        this.pagedUnits(_screen, units, this.EmbalmPage,
            @(bro) bro.getName() + "（" + bro.getLevel() + " 级，已拼装 " + S.graftCount(bro) + " / " + S.GraftLimit + "）",
            function( bro )
            {
                local picks = S.graftCandidates(bro);
                if (picks.len() == 0 || S.graftCount(bro) >= S.GraftLimit || !S.changeReserve(-S.graftCost()))
                    return "防腐尸骸不足，或它已经无法再拼装。";
                local trait = picks[::Math.rand(0, picks.len() - 1)];
                bro.getSkills().add(trait);
                bro.getFlags().set("PaleGraftCount", S.graftCount(bro) + 1);
                bro.getSkills().update();
                ::World.State.updateTopbarAssets();
                return "拆下的骨节与筋肉被一件件嵌进它的躯壳，防腐师用铜丝和松脂把接缝封死。魂火沿着新拼上的部位烧了一圈，像是在辨认，又像是在吞咽。\n\n（"
                    + bro.getName() + " 获得【" + trait.getName() + "】。已拼装 " + S.graftCount(bro) + " / " + S.GraftLimit + " 次。消耗 " + S.graftCost() + " 点防腐尸骸，剩余 " + S.get("Reserve") + " 点）";
            });
    this.option(_screen, "合上油布", @() "@camp");
};

local campPanelEmbalm = S.campPanel;
S.campPanel = function( _event, _screen )
{
    if (this.undead().len() > 0)
    {
        this.option(_screen, "肢体替换 · " + this.limbCost() + " 点防腐尸骸移除 1 个负面特质", function() { S.EmbalmPage = 0; return "@limb_roster"; });
        this.option(_screen, "优质拼装 · " + this.graftCost() + " 点防腐尸骸注入 1 个正面特质", function() { S.EmbalmPage = 0; return "@graft_roster"; });
    }
    return campPanelEmbalm.call(this, _event, _screen);
};

S.EmbalmScreens <- ["limb_roster", "limb_pick", "graft_roster", "castle_salt",
    "castle_rite_0", "castle_rite_1", "castle_rite_2", "castle_rite_3", "castle_rite_4", "castle_rite_5"];

local renderEmbalm = S.renderEvent;
S.renderEvent = function( _event, _screen )
{
    if (this.EmbalmScreens.find(_screen.ID) == null)
        return renderEmbalm.call(this, _event, _screen);
    local title = "防腐工坊";
    local art = "reserve_workshop";
    if (_screen.ID == "limb_roster" || _screen.ID == "limb_pick")
    {
        title = "肢体替换";
        if (_screen.ID == "limb_roster")
            this.limbRosterPanel(_screen);
        else
            this.limbPickPanel(_screen);
    }
    else if (_screen.ID == "graft_roster")
    {
        title = "优质拼装";
        this.graftRosterPanel(_screen);
    }
    else
    {
        title = "古堡";
        art = "reserve_salt";
        if ("castlePanel" in S)
            this.castlePanel(_screen);
        else
            _screen.Text = "这里没有已完工的古堡。";
    }
    _event.m.Title = title;
    _event.m.PaleArt = art;
    _screen.Text = "[img]gfx/ui/events/pale/" + art + ".jpg[/img]" + _screen.Text;
    this.option(_screen, "返回营地", @() null);
};

// ---------------- 战斗：秘仪效果 ----------------

// 开局为参战的常驻亡灵扣 1 场次数并挂上本场的秘仪效果
S.startRites <- function( _actor )
{
    local active = [];
    local flags = _actor.getFlags();
    foreach (rite in this.Rites)
    {
        local left = this.riteCharges(_actor, rite.Key);
        if (left <= 0)
            continue;
        active.push(rite.Key);
        if (left - 1 > 0)
            flags.set(this.riteFlag(rite.Key), left - 1);
        else
            flags.remove(this.riteFlag(rite.Key));
    }
    if (active.len() == 0)
        return;
    local skills = _actor.getSkills();
    skills.removeByID("effects.pale_embalm_rite");
    local effect = ::new(this.SkillDir + "effects/pale_embalm_rite_effect");
    effect.m.Rites = active;
    skills.add(effect);
    effect.setupBattle();
};

// ---------------- 尸脂熏蒸：苍白冷焰地块 ----------------
// 复用原版地块效果流程（Tactical.State.spawnEffectOnTile），伤害照重铸的火焰地块：15–30，护甲伤害同值，10% 穿甲，燃烧类型
S.ColdfireTimeout <- 2;

S.coldfireCanBurn <- function( _entity )
{
    if (_entity == null || ::MSU.isNull(_entity) || !_entity.isAlive() || _entity.isDying() || _entity.getFlags().has("undead"))
        return false;
    // 不灼伤玩家一方的活人（冷焰只铺在敌人脚下，防止我方踩进去误伤）
    local faction = _entity.getFaction();
    if (faction == ::Const.Faction.Player || faction == ::Const.Faction.PlayerAnimals)
        return false;
    try { return !::World.FactionManager.isAllied(::Const.Faction.Player, faction); } catch (e) { return true; }
};

S.onApplyColdfire <- function( _tile, _entity )
{
    if (!::PaleSovereign.coldfireCanBurn(_entity) || _entity.getCurrentProperties().IsImmuneToFire)
        return;
    ::PaleSovereign.playBattleArt("coldfire", _tile, 8, 1.0);
    local damage = ::Math.rand(15, 30);
    local hit = clone ::Const.Tactical.HitInfo;
    hit.DamageRegular = damage * _entity.getCurrentProperties().DamageReceivedFireMult;
    hit.DamageArmor = damage;
    hit.DamageDirect = 0.1;
    try { hit.DamageType = ::Const.Damage.DamageType.Burning; } catch (e) {}
    hit.BodyPart = ::Const.BodyPart.Body;
    hit.BodyDamageMult = 1.0;
    hit.FatalityChanceMult = 0.0;
    hit.Injuries = ::Const.Injury.Burning;
    hit.IsPlayingArmorSound = false;
    if (!_entity.isHiddenToPlayer())
        ::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(_entity) + " 被苍白冷焰灼伤");
    _entity.onDamageReceived(_entity, null, hit);
};

S.spawnColdfire <- function( _tile )
{
    local effect = _tile.Properties.Effect;
    if (effect != null && effect.Type == "pale_coldfire")
    {
        effect.Timeout = ::Time.getRound() + this.ColdfireTimeout;
        return;
    }
    if (effect != null || _tile.Type == ::Const.Tactical.TerrainType.ShallowWater || _tile.Type == ::Const.Tactical.TerrainType.DeepWater)
        return;
    local coldfire = {
        Type = "pale_coldfire",
        Tooltip = "苍白冷焰在这里无声燃烧，只灼烧活人的血肉",
        IsPositive = false,
        IsAppliedAtRoundStart = false,
        IsAppliedAtTurnEnd = true,
        IsAppliedOnMovement = false,
        IsAppliedOnEnter = false,
        IsByPlayer = true,
        Timeout = ::Time.getRound() + this.ColdfireTimeout,
        Callback = this.onApplyColdfire,
        function Applicable( _a )
        {
            return ::PaleSovereign.coldfireCanBurn(_a);
        }
    };
    local particles = this.makeFieldParticles(_tile, "coldfire", ::Const.Tactical.FireParticles);
    ::Tactical.State.spawnEffectOnTile(_tile, "pale_coldfire", coldfire, particles);
};

S.spreadColdfire <- function( _actor )
{
    if (!::Tactical.isActive() || _actor == null || !_actor.isAlive() || !_actor.isPlacedOnMap())
        return;
    local tile = _actor.getTile();
    local spread = 0;
    for (local i = 0; i < 6; ++i)
    {
        if (!tile.hasNextTile(i))
            continue;
        local next = tile.getNextTile(i);
        if (!next.IsOccupiedByActor || next.getEntity() == null || next.getEntity().isAlliedWith(_actor)
            || !this.coldfireCanBurn(next.getEntity()))
            continue;
        try { this.spawnColdfire(next); ++spread; } catch (e) { ::logError("[PaleSovereign] 苍白冷焰: " + e); }
    }
    if (spread > 0 && !_actor.isHiddenToPlayer())
        ::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(_actor) + " 骨隙间渗出的黑雾在 " + spread + " 名敌人脚下燃起苍白冷焰");
};

// 厚骨覆甲：临时天然护甲写在基础属性里，战后按旗标还原（防止遗留到存档）
S.restoreRiteArmor <- function( _actor )
{
    local flags = _actor.getFlags();
    if (!flags.has("PaleRiteArmor"))
        return;
    local b = _actor.getBaseProperties();
    foreach (i, part in ["Head", "Body"])
    {
        local index = ::Const.BodyPart[part];
        b.Armor[index] = flags.getAsInt("PaleRiteArmor" + part);
        b.ArmorMax[index] = flags.getAsInt("PaleRiteArmorMax" + part);
    }
    flags.remove("PaleRiteArmor");
    _actor.getSkills().update();
};

S.riteAcidBlocked <- function( _actor )
{
    if (_actor == null || ::MSU.isNull(_actor))
        return false;
    local rite = _actor.getSkills().getSkillByID("effects.pale_embalm_rite");
    return rite != null && rite.hasRite("fumigate");
};

S.Mod.hook("scripts/skills/skill_container", function(q)
{
    q.onCombatStarted = @(__original) function()
    {
        local actor = this.getActor();
        if (S.isActive() && actor.isPlayerControlled() && S.isUndead(actor))
        {
            S.restoreRiteArmor(actor);
            try { S.startRites(actor); } catch (e) { ::logError("[PaleSovereign] 防腐秘仪开局: " + e); }
        }
        __original();
    };

    q.add = @(__original) function( _skill, ... )
    {
        if (_skill != null && (_skill.getID() == "effects.lindwurm_acid" || _skill.getID() == "effects.acid")
            && S.riteAcidBlocked(this.getActor()))
            return;
        local args = [this, _skill];
        args.extend(vargv);
        return __original.acall(args);
    };
});

S.Mod.hook("scripts/states/world_state", function(q)
{
    q.onCombatFinished = @(__original) function()
    {
        local result = __original();
        if (S.isActive())
            foreach (bro in S.undead())
                S.restoreRiteArmor(bro);
        return result;
    };
});

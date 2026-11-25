local S = ::PaleSovereign;

// Other installed mods extend these arrays. Use their actual length as the projectile index.
S.CorpseProjectile <- ::Const.ProjectileSprite.len();
::Const.ProjectileSprite.push("pale_fx_missile");
::Const.ProjectileDecals.push(::Const.ProjectileDecals[::Const.ProjectileType.Rock]);
::Const.ProjectileType.PaleCorpse <- S.CorpseProjectile;
::Const.ProjectileType.COUNT = ::Math.max(::Const.ProjectileType.COUNT, S.CorpseProjectile + 1);

local function highResolutionBrush( _name )
{
    local brush = "pale_hd_" + _name.slice(5);
    return ::doesBrushExist(brush) ? brush : null;
}

S.playBattleArt <- function( _key, _tile, _height = 32, _scale = 1.0, _delay = 0 )
{
    if (this.Battle == null || _tile == null || !::Tactical.isActive() || !_tile.IsVisibleForPlayer
        || (_tile.IsOccupiedByActor && _tile.getEntity().isHiddenToPlayer()))
        return;
    if (_delay > 0)
    {
        local battle = this.Battle;
        ::Time.scheduleEvent(::TimeUnit.Virtual, _delay, function( _unused ) {
            if (S.Battle == battle)
                S.playBattleArt(_key, _tile, _height, _scale);
        }, null);
        return;
    }
    local brush = "pale_fx_" + _key;
    local detailed = highResolutionBrush(brush);
    if (detailed != null)
    {
        brush = detailed;
        _scale *= 0.5;
    }
    ::Tactical.spawnSpriteEffect(brush, ::createColor("#ffffff"), _tile, 0, _height,
        _scale * 0.70, _scale, 40, 150, 230);
};

S.playActorArt <- function( _key, _actor, _height = 32, _scale = 1.0 )
{
    if (this.Battle == null || _actor == null || ::MSU.isNull(_actor) || !::Tactical.isActive()
        || !_actor.isPlacedOnMap() || _actor.isHiddenToPlayer())
        return;
    local tile = _actor.getTile();
    if (!tile.IsVisibleForPlayer)
        return;
    if (!("PaleArtPulses" in _actor.m))
        _actor.m.PaleArtPulses <- {};
    local pulses = _actor.m.PaleArtPulses;
    local now = ::Time.getVirtualTimeF();
    if (_key in pulses && now - pulses[_key] < 0.55)
        return;
    pulses[_key] <- now;
    this.playBattleArt(_key, tile, _height, _scale);
};

S.makeFieldParticles <- function( _tile, _key, _source )
{
    if (_source.len() == 0)
        return [];
    local fx = _source[0];
    local brush = "pale_fx_" + _key;
    local detailed = highResolutionBrush(brush);
    local stages = [];
    foreach (i, data in fx.Stages)
    {
        local stage = clone data;
        if (detailed != null)
        {
            stage.ScaleMin *= 0.5;
            stage.ScaleMax *= 0.5;
        }
        stage.ColorMin = ::createColor(i == fx.Stages.len() - 1 && i > 0 ? "ffffff00" : "ffffff7a");
        stage.ColorMax = ::createColor(i == fx.Stages.len() - 1 && i > 0 ? "ffffff00" : "ffffffa6");
        stages.push(stage);
    }
    return [{ Entity = true, Brushes = [detailed == null ? brush : detailed], Tile = _tile, Delay = fx.Delay,
        Quantity = fx.Quantity, Lifetime = fx.LifeTimeQuantity, Rate = fx.SpawnRate, Stages = stages }];
};

local marks = {
    ["effects.pale_weaken"] = "weak", ["effects.pale_blind"] = "blind",
    ["effects.pale_bone_break_status"] = "fracture", ["effects.pale_grave_blade_status"] = "wound",
    ["effects.pale_stench_status"] = "stench", ["effects.pale_hex_domain"] = "domain",
    ["effects.pale_chant"] = "dirge", ["effects.pale_banshee"] = "wail",
    ["effects.pale_prey"] = "prey", ["effects.pale_bound_soul"] = "bound",
    ["effects.bgp_curse_of_ages"] = "age", ["effects.bgp_fly_swarm"] = "flies",
    ["effects.bgp_undead_poison"] = "venom",
    ["effects.pale_corpse_poison"] = "corpse_poison", ["effects.pale_chain_hold"] = "chain_hold",
    ["effects.pale_doom_mark"] = "doom_mark", ["effects.pale_daunted"] = "daunted",
    ["effects.pale_barrow_dread"] = "barrow_dread", ["effects.pale_jade_miasma"] = "jade_miasma",
    ["effects.pale_jade_guard"] = "jade_guard", ["effects.pale_bone_ward"] = "bone_ward",
    ["effects.pale_shot_mark"] = "shot_mark"
};

// Status marks are displayed exclusively in the native HP-bar IconMini row (never pinned onto actor faces).
// Keep the brief application pulse VFX when a mark is first applied.
local function attachMark( _skill )
{
    local id = _skill.getID();
    if (S.Battle == null || !(id in marks) || _skill.m.PaleArtAttached || _skill.m.IsHidden || _skill.isGarbage())
        return;
    local actor = _skill.getContainer().getActor();
    if (actor == null || !actor.isPlacedOnMap() || !actor.isAlive() || actor.isDying())
        return;
    local key = marks[id];
    if (!("PaleArtMarks" in actor.m))
        actor.m.PaleArtMarks <- {};
    local counts = actor.m.PaleArtMarks;
    local wasActive = key in counts && counts[key] > 0;
    counts[key] <- wasActive ? counts[key] + 1 : 1;
    _skill.m.PaleArtAttached = true;
    if (!wasActive)
        S.playBattleArt("mark_" + key, actor.getTile(), 54, 0.80);
}

local function detachMark( _skill )
{
    if (!_skill.m.PaleArtAttached)
        return;
    _skill.m.PaleArtAttached = false;
    local actor = _skill.getContainer().getActor();
    if (actor == null || !("PaleArtMarks" in actor.m))
        return;
    local key = marks[_skill.getID()];
    local counts = actor.m.PaleArtMarks;
    if (!(key in counts) || --counts[key] > 0)
        return;
    delete counts[key];
}

foreach (name in ["pale_weaken_effect", "pale_blind_effect", "pale_hex_domain_effect", "pale_chant_effect",
    "pale_banshee_effect", "pale_prey_effect", "pale_tier_status", "pale_bound_soul_effect",
    "bgp_curse_of_ages_effect", "bgp_fly_swarm_effect", "bgp_undead_poison_effect",
    "pale_corpse_poison_effect", "pale_chain_hold_effect", "pale_doom_mark_effect", "pale_daunted_effect",
    "pale_barrow_dread_effect", "pale_jade_miasma_effect", "pale_jade_guard_effect", "pale_bone_ward_effect", "pale_shot_mark_effect"])
{
    S.Mod.hook("scripts/skills/effects/" + name, function(q) {
        q.create = @(__original) function() {
            __original();
            this.m.PaleArtAttached <- false;
            if (S.Battle != null && this.m.ID == "effects.bgp_undead_poison")
                this.m.Overlay = "";
        };
        q.onAdded = @(__original) function() {
            __original();
            local id = this.getID();
            if (S.Battle != null && id in marks)
            {
                this.m.IconMini = "pale_mark_" + marks[id];
                if (id.find("effects.bgp_") == 0)
                    this.m.Icon = "skills/pale_mark_" + marks[id] + ".png";
            }
            attachMark(this);
        };
        q.onRemoved = @(__original) function() { detachMark(this); __original(); };
        q.onDeath = @(__original) function( _fatalityType ) { detachMark(this); __original(_fatalityType); };
        q.onCombatFinished = @(__original) function() { detachMark(this); __original(); };
    });
}

// Fly Swarm stays in the skill container even when there are no adjacent infesting minions.
S.Mod.hook("scripts/skills/effects/bgp_fly_swarm_effect", function(q) {
    q.onUpdate = @(__original) function( _properties ) {
        __original(_properties);
        if (S.Battle == null)
            return;
        if (this.m.Count > 0)
            attachMark(this);
        else
            detachMark(this);
    };
});

// These shared skills keep their original timing, targeting and return values in every origin.
local casts = {
    bgp_necro_raise_skill = "raise", bgp_necro_eternal_command_skill = "command",
    bgp_necro_possess_skill = "possess", bgp_necro_infusion_skill = "infuse",
    bgp_necro_flesh_reforge_skill = "stitch", bgp_corpse_explosion_skill = "burst",
    bgp_necro_bind_skill = "coffin"
};
foreach (name, art in casts)
{
    local brush = art;
    S.Mod.hook("scripts/skills/actives/" + name, function(q) {
        q.onUse = @(__original) function( _user, _tile ) {
            local result = __original(_user, _tile);
            if (result && S.Battle != null)
                S.playBattleArt(brush, _tile);
            return result;
        };
    });
}

S.Mod.hook("scripts/skills/effects/bgp_curse_of_ages_effect", function(q) {
    q.refresh = @(__original) function( _decay = null ) {
        __original(_decay);
        if (this.m.PaleArtAttached)
            S.playBattleArt("mark_age", this.getContainer().getActor().getTile(), 44);
    };
});

S.Mod.hook("scripts/skills/actives/bgp_necro_curse_of_ages_skill", function(q) {
    q.spawnIcon = @(__original) function( _brush, _tile ) {
        if (S.Battle == null || _brush != "status_effect_67")
            return __original(_brush, _tile);
    };
});

// Vanilla special.morale_check leaves MoraleState.Ignore on the default white-flag mini icon
// (status_effect_02_mini) with a missing Icon PNG and null tooltip. Give it a dedicated bastion
// status icon and tooltip while preserving all other morale states (and UndeadCurse's isHidden).
S.Mod.hook("scripts/skills/special/morale_check", function(q) {
    local applyUnbreakableVisual = function( _skill )
    {
        local c = _skill.getContainer();
        if (c == null)
            return;
        local actor = c.getActor();
        if (actor == null || actor.getMoraleState() != ::Const.MoraleState.Ignore)
            return;
        _skill.m.Icon = "skills/pale_unbreakable_status.png";
        _skill.m.IconDisabled = "skills/pale_unbreakable_status_sw.png";
        _skill.m.IconMini = "pale_unbreakable_mini";
        _skill.m.IsHidden = false;
    };

    q.onAdded = @(__original) function() {
        __original();
        applyUnbreakableVisual(this);
    };

    q.onUpdate = @(__original) function( _properties ) {
        __original(_properties);
        applyUnbreakableVisual(this);
    };

    q.getTooltip = @(__original) function() {
        local ret = __original();
        if (ret != null)
            return ret;
        local c = this.getContainer();
        local actor = c != null ? c.getActor() : null;
        if (actor != null && actor.getMoraleState() == ::Const.MoraleState.Ignore)
        {
            return [
                {
                    id = 1,
                    type = "title",
                    text = this.getName()
                },
                {
                    id = 2,
                    type = "description",
                    text = "这个角色不受士气检定影响，绝不会动摇或溃逃。"
                },
                {
                    id = 10,
                    type = "text",
                    icon = "ui/icons/morale.png",
                    text = "免疫士气下降、动摇、崩溃与溃逃"
                }
            ];
        }
        return ret;
    };
});

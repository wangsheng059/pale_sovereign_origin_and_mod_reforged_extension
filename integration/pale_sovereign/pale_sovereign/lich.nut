local S = ::PaleSovereign;

// 1.7.7 尸妖王：放出时获得号令亡魂、冢王威压、换位；在场时导师每回合首次受击伤害 −12 并免疫爆头额外伤害与击退抓取
S.LichWardFlat <- 12;

S.applyLichSkills <- function( _entity, _chief )
{
    local skills = _entity.getSkills();
    if (!skills.hasSkill(this.tierTalentID("dead_command")))
    {
        local aura = ::new(this.SkillDir + this.TierTalents.dead_command.Script);
        aura.configure("dead_command");
        skills.add(aura);
    }
    if (!skills.hasSkill("effects.pale_barrow_dread"))
        skills.add(::new(this.SkillDir + "effects/pale_barrow_dread_effect"));
    if (!skills.hasSkill("actives.rotation"))
        skills.add(::new("scripts/skills/actives/rotation"));
    if (_chief != null && !::MSU.isNull(_chief))
    {
        local ward = _chief.getSkills().getSkillByID("effects.pale_lich_ward");
        if (ward == null)
        {
            ward = ::new(this.SkillDir + "effects/pale_lich_ward_effect");
            _chief.getSkills().add(ward);
        }
        ward.setLich(_entity);
    }
    skills.update();
    this.refreshDeadCommand();
};

// 1.6.32 高阶的复活亡灵（复活死者、召唤、锁魂复生拉起的精锐亡灵）默认带恐惧之容
S.EliteRaisedKinds <- {
    zombie_knight = true, rf_zombie_hero = true, rf_zombie_orc_warlord = true,
    skeleton_heavy = true, skeleton_heavy_polearm = true, rf_skeleton_heavy_elite = true,
    rf_skeleton_medium_elite = true, rf_skeleton_medium_elite_polearm = true,
    rf_skeleton_centurion = true, rf_skeleton_legatus = true,
    rf_draugr_hero = true, rf_draugr_huskarl = true,
    vampire = true, rf_vampire_lord = true, greater_flesh_golem = true
};

S.isEliteRaised <- function( _e )
{
    local name = null;
    try { name = _e.ClassName; } catch (e) { return false; }
    if (typeof name != "string")
        return false;
    foreach (prefix in ["bgp_undead_", "bgp_pet_"])
        if (name.find(prefix) == 0)
            return name.slice(prefix.len()) in this.EliteRaisedKinds;
    return false;
};

local oldMarkMinion = ::BGP.Necro.markMinion;
::BGP.Necro.markMinion = function( _user, _e )
{
    oldMarkMinion(_user, _e);
    try
    {
        if (_user != null && !::MSU.isNull(_user) && _user.isPlayerControlled() && S.isEliteRaised(_e))
        {
            S.grantVisage(_e, false);
            _e.getSkills().update();
        }
    }
    catch (e)
    {
        ::logError("Pale Sovereign: could not grant Terrifying Visage to a raised elite: " + e);
    }
};

// 1.6.33 我方阵营的亡灵：常驻亡灵、冠军、复活和召唤出的亡灵
S.isFriendlyUndead <- function( _actor )
{
    if (_actor == null || ::MSU.isNull(_actor))
        return false;
    local faction = _actor.getFaction();
    if (faction != ::Const.Faction.Player && faction != ::Const.Faction.PlayerAnimals)
        return false;
    return this.isPaleUndeadActor(_actor);
};

// 冢王威压标记的猎物：可以同时有多个，不挤掉导师标记的那一个
S.addPrey <- function( _target )
{
    if (this.Battle == null || _target == null || ::MSU.isNull(_target))
        return;
    local effect = _target.getSkills().getSkillByID("effects.pale_prey");
    if (effect == null)
    {
        effect = ::new(this.SkillDir + "effects/pale_prey_effect");
        _target.getSkills().add(effect);
    }
    effect.m.Turns = 2;
};

// 1.7.0 活人与亡灵的战场联动（隐藏效果，开战时加给玩家阵营的每名成员）
// 活人：紧贴常驻亡灵时远程防御 +5；与【旧日同袍】相邻时近战防御 +3、决心 +5；
//       亲死背景每 3 名在场常驻亡灵决心 +2；凡人背景未适应时，身边只有亡灵会心悸（决心 −2）
// 常驻亡灵：相邻活人处于士气高涨时近战技能 +5
// 导师：每名邪教徒决心 +2，最多 +6
this.pale_living_bond_effect <- ::inherit("scripts/skills/skill", {
    m = {},
    function create()
    {
        this.m.ID = "effects.pale_living_bond";
        this.m.Name = "生死同袍";
        this.m.Type = ::Const.SkillType.StatusEffect;
        this.m.IsSerialized = false;
        this.m.IsRemovedAfterBattle = true;
        this.m.IsStacking = false;
        this.m.IsHidden = true;
    }

    function residentsOnField()
    {
        local n = 0;
        foreach (bro in ::World.getPlayerRoster().getAll())
            if (::PaleSovereign.isUndead(bro) && bro.isPlacedOnMap() && bro.isAlive())
                ++n;
        return n;
    }

    function onUpdate( _properties )
    {
        local S = ::PaleSovereign;
        if (S.Battle == null)
            return;
        local actor = this.getContainer().getActor();
        if (S.isChief(actor))
        {
            _properties.Bravery += S.cultistResolve();
            return;
        }
        if (actor.getFlags().has("undead"))
            return;
        if (S.isProDeath(actor))
            _properties.Bravery += 2 * (this.residentsOnField() / 3);
        local near = S.neighbours(actor);
        local undeadOnly = near.len() > 0;
        local comrade = false;
        foreach (other in near)
        {
            if (!other.getFlags().has("undead"))
                undeadOnly = false;
            if (other.getSkills().hasSkill("trait.pale_former_comrade"))
                comrade = true;
        }
        if (comrade)
            _properties.Bravery += 5;
        if (undeadOnly && !S.isAcclimated(actor))
            _properties.Bravery -= 2;
    }

    function onBeingAttacked( _attacker, _skill, _properties )
    {
        local S = ::PaleSovereign;
        local actor = this.getContainer().getActor();
        if (S.Battle == null || actor.getFlags().has("undead"))
            return;
        local shielded = false;
        local comrade = false;
        foreach (other in S.neighbours(actor))
        {
            if (S.isUndead(other))
                shielded = true;
            if (other.getSkills().hasSkill("trait.pale_former_comrade"))
                comrade = true;
        }
        if (shielded)
            _properties.RangedDefense += 5;
        if (comrade)
            _properties.MeleeDefense += 3;
    }

    function onAnySkillUsed( _skill, _targetEntity, _properties )
    {
        local S = ::PaleSovereign;
        local actor = this.getContainer().getActor();
        if (S.Battle == null || !S.isUndead(actor) || _skill == null || !_skill.isAttack() || _skill.isRanged())
            return;
        foreach (other in S.neighbours(actor))
            if (!other.getFlags().has("undead") && other.getMoraleState() == ::Const.MoraleState.Confident)
            {
                _properties.MeleeSkill += 5;
                return;
            }
    }
});

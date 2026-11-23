// 1.6.32 尸妖王的冢王威压：每回合开始时 2 格内敌人各做一次士气检定，失败的成为猎物；触及距离 +1
this.pale_barrow_dread_effect <- ::inherit("scripts/skills/skill", {
    m = { Range = 2 },
    function create()
    {
        this.m.ID = "effects.pale_barrow_dread";
        this.m.Name = "冢王威压";
        this.m.Description = "古冢之王的魂火压在每一个靠近它的活物心头。\n每回合开始时，2 格内的敌人各做一次士气检定，失败者成为猎物（亡灵宠物与仆从优先攻击；导师与冠军对其命中 +10、伤害 +20%），持续 2 回合。触及距离 +1。";
        this.m.Icon = "skills/pale_prey.png";
        this.m.IconDisabled = "skills/pale_prey_sw.png";
        this.m.Type = ::Const.SkillType.StatusEffect;
        this.m.Order = ::Const.SkillOrder.Any;
        this.m.IsSerialized = false;
        this.m.IsRemovedAfterBattle = true;
        this.m.IsStacking = false;
    }

    function getTooltip()
    {
        local ret = this.skill.getTooltip();
        ret.push({ id = 10, type = "text", icon = "ui/icons/special.png", text = "每回合开始：[color=" + ::Const.UI.Color.PositiveValue + "]2[/color] 格内敌人士气检定，失败者成为猎物" });
        ret.push({ id = 11, type = "text", icon = "ui/icons/rf_reach.png", text = "触及距离 [color=" + ::Const.UI.Color.PositiveValue + "]+1[/color]" });
        return ret;
    }

    function onUpdate( _properties )
    {
        try { _properties.Reach += 1; } catch (e) {}
    }

    function onTurnStart()
    {
        local S = ::PaleSovereign;
        if (S.Battle == null)
            return;
        local actor = this.getContainer().getActor();
        if (!actor.isPlacedOnMap())
            return;
        local tile = actor.getTile();
        local marked = 0;
        foreach (faction in ::Tactical.Entities.getAllInstances())
        {
            foreach (other in faction)
            {
                if (other == null || !other.isAlive() || other.isDying() || !other.isPlacedOnMap()
                    || other.isAlliedWith(actor) || other.getTile().getDistanceTo(tile) > this.m.Range
                    || other.getMoraleState() == ::Const.MoraleState.Ignore)
                    continue;
                local failed = false;
                try { failed = other.checkMorale(-1, 0, ::Const.MoraleCheckType.MentalAttack); } catch (e) { failed = false; }
                if (failed && other.isAlive() && !other.isDying())
                {
                    S.addPrey(other);
                    ++marked;
                }
            }
        }
        if (marked > 0 && !actor.isHiddenToPlayer())
            ::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(actor) + " 的威压让 " + marked + " 名敌人沦为猎物");
    }
});

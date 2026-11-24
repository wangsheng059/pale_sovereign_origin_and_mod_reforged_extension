// 1.7.0 魂玉统领的光环（效果由 jade_ops.nut 的 refreshLeaderAuras 与击杀钩子实现）
this.pale_jade_leader_effect <- ::inherit("scripts/skills/skill", {
    m = {},
    function create()
    {
        this.m.ID = "effects.pale_jade_leader";
        this.m.Name = "魂玉统领";
        this.m.Icon = "skills/pale_dead_command_effect.png";
        this.m.Type = ::Const.SkillType.StatusEffect;
        this.m.IsSerialized = false;
        this.m.IsRemovedAfterBattle = true;
        this.m.IsStacking = false;
    }

    function getDescription()
    {
        local S = ::PaleSovereign;
        local aura = S.leaderAura(this.getContainer().getActor());
        if (aura <= 0 || aura >= S.LeaderAuras.len())
            return "胸腔里嵌着魂玉的亡者灵核。";
        return "胸腔里嵌着魂玉的亡者灵核。\n【" + S.LeaderAuras[aura].Name + "】" + S.LeaderAuras[aura].Desc;
    }
});

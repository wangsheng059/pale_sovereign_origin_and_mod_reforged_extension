this.pale_zombie_background <- ::inherit("scripts/skills/backgrounds/pale_undead_background", {
    m = {},
    function create()
    {
        this.pale_undead_background.create();
        this.m.ID = "background.pale_zombie";
        this.m.Name = "常驻行尸";
        this.m.Icon = "ui/backgrounds/pale_zombie.png";
        this.m.BackgroundDescription = "盐痂下还留着一身结实的筋肉。它拖着脚，却能守住缺口。";
    }

    function onChangeAttributes()
    {
        return {
            Hitpoints = [20, 30], Bravery = [5, 10], Stamina = [5, 10],
            MeleeSkill = [-7, -3], RangedSkill = [-10, -5], MeleeDefense = [-3, 0],
            RangedDefense = [-3, 0], Initiative = [-30, -20]
        };
    }
});

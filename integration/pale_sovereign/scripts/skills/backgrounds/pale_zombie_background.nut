this.pale_zombie_background <- ::inherit("scripts/skills/backgrounds/pale_undead_background", {
    m = {},
    function create()
    {
        this.pale_undead_background.create();
        this.m.ID = "background.pale_zombie";
        this.m.Name = "常驻行尸";
        this.m.Icon = "ui/backgrounds/pale_zombie.png";
        this.m.BackgroundDescription = "盐痂下还留着生前结实的筋肉。它拖着僵硬的步子，却能死死钉住阵线的缺口。";
    }

    function onChangeAttributes()
    {
        return {
            Hitpoints = [20, 30], Bravery = this.getStartingBraveryAdjustment(), Stamina = [5, 10],
            MeleeSkill = [-7, -3], RangedSkill = [-10, -5], MeleeDefense = [-3, 0],
            RangedDefense = [-3, 0], Initiative = [-30, -20]
        };
    }
});

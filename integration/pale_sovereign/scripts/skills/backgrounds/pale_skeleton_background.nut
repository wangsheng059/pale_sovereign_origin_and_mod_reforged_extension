this.pale_skeleton_background <- ::inherit("scripts/skills/backgrounds/pale_undead_background", {
    m = {},
    function create()
    {
        this.pale_undead_background.create();
        this.m.ID = "background.pale_skeleton";
        this.m.Name = "常驻骷髅";
        this.m.Icon = "ui/backgrounds/pale_skeleton.png";
        this.m.BackgroundDescription = "几根浸过死灵药水与黑盐的铜索，把瘦削的枯骨捆成了一名不知疲倦的战士。";
        this.m.PaleSkeleton = true;
    }

    function onChangeAttributes()
    {
        return {
            Hitpoints = [-12, -8], Bravery = this.getStartingBraveryAdjustment(), Stamina = [0, 5],
            MeleeSkill = [-4, 0], RangedSkill = [-8, -4], MeleeDefense = [2, 5],
            RangedDefense = [0, 3], Initiative = [-5, 0]
        };
    }
});

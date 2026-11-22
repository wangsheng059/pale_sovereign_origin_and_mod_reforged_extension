// 1.6.8 常驻骷髅弓手：骷髅的远程模板，特技树固定带弓组；升阶沿用骷髅分支
this.pale_skeleton_archer_background <- ::inherit("scripts/skills/backgrounds/pale_skeleton_background", {
    m = {},
    function create()
    {
        this.pale_skeleton_background.create();
        this.m.ID = "background.pale_skeleton_archer";
        this.m.Name = "常驻骷髅弓手";
        this.m.BackgroundDescription = "指骨扣弦的姿势还和生前一模一样，空洞的眼窝里，魂火替它瞄准。";
    }

    function onChangeAttributes()
    {
        return {
            Hitpoints = [-14, -10], Bravery = this.getStartingBraveryAdjustment(), Stamina = [0, 5],
            MeleeSkill = [-10, -6], RangedSkill = [4, 8], MeleeDefense = [-2, 2],
            RangedDefense = [0, 3], Initiative = [-2, 3]
        };
    }

    function createPerkTreeBlueprint()
    {
        local tree = this.pale_skeleton_background.createPerkTreeBlueprint();
        tree.m.DynamicMap["pgc.rf_weapon"] <- ["pg.rf_bow"];
        return tree;
    }
});

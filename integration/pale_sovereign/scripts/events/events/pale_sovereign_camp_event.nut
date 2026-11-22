this.pale_sovereign_camp_event <- ::inherit("scripts/events/event", {
    m = { Page = "camp", Message = "", PaleArt = "camp", TierPage = 0, TierUnit = 0, TierBranch = "" },
    function create()
    {
        this.m.ID = "event.pale_sovereign_camp";
        this.m.Title = "亡灵主宰";
        this.m.Cooldown = 0;
        foreach (page in ["camp", "soul", "shovels", "evolve", "banner", "crown", "empty", "smith", "whispers", "mortuary", "parts", "porter", "lantern", "dice", "apprentice", "harvest", "result", "jade", "ascend", "tier_roster", "tier_branch", "tier_confirm", "castle", "castle_forge", "castle_forge_0", "castle_forge_1", "castle_forge_2", "castle_forge_3", "castle_tombs", "castle_barracks", "castle_sacrifice", "conquest_recruit", "conquest_governor", "soulbound", "shackle", "refine"])
        {
            this.m.Screens.push({
                ID = page, Text = "", Image = "", List = [], Characters = [], Options = [],
                function start( _event )
                {
                    this.Options = [];
                    ::PaleSovereign.renderEvent(_event, this);
                }
            });
        }
    }

    function onDetermineStartScreen()
    {
        return this.m.Page;
    }
});

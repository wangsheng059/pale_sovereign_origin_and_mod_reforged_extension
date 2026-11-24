// 1.7.0 原营地账簿里的部分事件改到大地图触发（与原版随机事件同池），正文和选项仍由 S.renderEvent 绘制
this.pale_story_event <- ::inherit("scripts/events/event", {
    m = { PaleKey = "", Message = "", PaleArt = "camp", Page = "" },

    function create()
    {
        this.m.ID = "event.pale_story_" + this.m.PaleKey;
        this.m.Title = "亡灵主宰";
        this.m.Cooldown = 5 * ::World.getTime().SecondsPerDay;
        this.m.Page = this.m.PaleKey;
        this.m.Screens.push({
            ID = this.m.PaleKey, Text = "", Image = "", List = [], Characters = [], Options = [],
            function start( _event )
            {
                this.Options = [];
                ::PaleSovereign.renderEvent(_event, this);
                foreach (option in this.Options)
                    if (option.Text == "返回营地")
                        option.Text = "继续上路。";
            }
        });
        this.m.Screens.push({
            ID = "result", Text = "", Image = "", List = [], Characters = [], Options = [],
            function start( _event )
            {
                this.Text = "[img]gfx/ui/events/pale/" + _event.m.PaleArt + ".jpg[/img]" + _event.m.Message;
                this.Options = [{ Text = "继续上路。", function getResult( _event ) { return 0; } }];
            }
        });
    }

    function onUpdateScore()
    {
        local S = ::PaleSovereign;
        this.m.Score = 0;
        if (!("WorldStories" in S) || !S.isActive() || S.chief() == null)
            return;
        try
        {
            if (::World.State.getCurrentTown() != null)
                return;
            this.m.Score = S.WorldStories[this.m.PaleKey]();
        }
        catch (e)
        {
            this.m.Score = 0;
            ::logError("Pale Sovereign: story " + this.m.PaleKey + " score failed: " + e);
        }
    }

    function onDetermineStartScreen()
    {
        return this.m.PaleKey;
    }
});

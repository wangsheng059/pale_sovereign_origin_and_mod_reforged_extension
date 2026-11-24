// 1.6.33 常驻亡灵大地图随机事件的共用类：正文、选项、权重与结果都在 pale_sovereign/undead_events.nut 的 S.UndeadEvents
this.pale_undead_event <- ::inherit("scripts/events/event", {
    m = { PaleKey = "", Target = null, Living = null, Town = null, Candidates = [], Message = "", Effects = [], Pools = null, Roles = null },

    function create()
    {
        this.m.ID = "event.pale_" + this.m.PaleKey;
        // 没装配件兄弟时亡灵主宰的模块不加载，事件保持空壳、权重为 0
        if (!("UndeadEvents" in ::PaleSovereign))
            return;
        local def = ::PaleSovereign.UndeadEvents[this.m.PaleKey];
        this.m.Title = def.Title;
        this.m.Cooldown = def.Cooldown * ::World.getTime().SecondsPerDay;
        this.m.Screens.push({
            ID = "A", Text = "", Image = "", List = [], Characters = [], Options = [],
            function start( _event )
            {
                local def = ::PaleSovereign.UndeadEvents[_event.m.PaleKey];
                this.Text = "[img]gfx/ui/events/pale/" + def.Image + ".jpg[/img]" + def.Text;
                this.Characters = _event.paleCharacters();
                this.Options = [];
                foreach (option in def.Options)
                {
                    if ("Usable" in option && !option.Usable(_event))
                        continue;
                    local picked = option;
                    this.Options.push({
                        Text = picked.Text,
                        function getResult( _event )
                        {
                            _event.m.Effects = [];
                            _event.m.Message = picked.Apply(_event);
                            return "B";
                        }
                    });
                }
            }
        });
        this.m.Screens.push({
            ID = "B", Text = "", Image = "", List = [], Characters = [], Options = [],
            function start( _event )
            {
                local def = ::PaleSovereign.UndeadEvents[_event.m.PaleKey];
                this.Text = "[img]gfx/ui/events/pale/" + def.Image + ".jpg[/img]" + _event.m.Message;
                this.List = _event.m.Effects;
                this.Characters = _event.paleCharacters();
                this.Options = [{ Text = "继续上路。", function getResult( _event ) { return 0; } }];
            }
        });
    }

    function paleCharacters()
    {
        local ret = [];
        local seen = {};
        local list = [this.m.Target, this.m.Living];
        if (this.m.Roles != null)
            foreach (role, bro in this.m.Roles)
                list.push(bro);
        foreach (bro in list)
            if (bro != null && !::MSU.isNull(bro) && !(bro.getID() in seen) && ret.len() < 2)
            {
                seen[bro.getID()] <- true;
                ret.push(bro.getImagePath());
            }
        return ret;
    }

    function onUpdateScore()
    {
        local S = ::PaleSovereign;
        this.m.Score = 0;
        this.m.Candidates = [];
        this.m.Pools = {};
        if (!("UndeadEvents" in S) || !S.isActive() || S.chief() == null)
            return;
        try
        {
            if (::World.State.getCurrentTown() != null)
                return;
        }
        catch (e)
        {
        }
        try
        {
            this.m.Score = S.UndeadEvents[this.m.PaleKey].Score(this);
        }
        catch (e)
        {
            this.m.Score = 0;
            ::logError("Pale Sovereign: event " + this.m.PaleKey + " score failed: " + e);
        }
    }

    function onPrepare()
    {
        local S = ::PaleSovereign;
        local def = S.UndeadEvents[this.m.PaleKey];
        if (this.m.Candidates.len() > 0)
            this.m.Target = ::MSU.Array.rand(this.m.Candidates);
        if ("Living" in def && def.Living)
            this.m.Living = S.uevtLiving(def.LivingPrefer);
        this.m.Town = S.nearTown(30);
        // 1.7.0 多角色事件：Score 时填好 m.Pools（角色 → 候选），这里为每个角色挑一个不重复的人
        this.m.Roles = {};
        if (this.m.Pools != null && "RoleOrder" in def)
        {
            local used = {};
            foreach (role in def.RoleOrder)
            {
                if (!(role in this.m.Pools))
                    continue;
                local pool = this.m.Pools[role].filter(@(_, bro) !(bro.getID() in used));
                if (pool.len() == 0)
                    continue;
                local bro = ::MSU.Array.rand(pool);
                used[bro.getID()] <- true;
                this.m.Roles[role] <- bro;
            }
            if ("MainRole" in def && def.MainRole in this.m.Roles)
                this.m.Target = this.m.Roles[def.MainRole];
        }
    }

    function role( _key )
    {
        return this.m.Roles != null && _key in this.m.Roles ? this.m.Roles[_key] : null;
    }

    function onPrepareVariables( _vars )
    {
        if (this.m.Roles != null)
            foreach (role, bro in this.m.Roles)
                _vars.push([role, bro.getName()]);
        local name = this.m.Target == null ? "" : this.m.Target.getName();
        _vars.push(["zombie", name]);
        _vars.push(["skeleton", name]);
        _vars.push(["living", this.m.Living == null ? "" : this.m.Living.getName()]);
        _vars.push(["townname", this.m.Town == null ? "附近的村镇" : this.m.Town.getName()]);
    }

    function onClear()
    {
        this.m.Target = null;
        this.m.Living = null;
        this.m.Town = null;
        this.m.Candidates = [];
        this.m.Effects = [];
        this.m.Pools = null;
        this.m.Roles = null;
    }
});

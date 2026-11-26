this.pale_sovereign_intro_event <- ::inherit("scripts/events/event", {
    m = {},
    function create()
    {
        this.m.ID = "event.pale_sovereign_intro";
        this.m.IsSpecial = true;
        this.m.Title = "亡灵主宰";
        this.m.Cooldown = 0;
        this.m.Screens.push({
            ID = "A",
            Text = "[img]gfx/ui/events/pale/intro.jpg[/img]荒冢沉重的石门在你身后缓缓合拢，终年不散的腐土湿气，终于被荒野凛冽的寒风吹散。\n\n世人都以为你的名讳早已随那场领主与圣职联手发动的围剿化作焦土与灰烬，无人知晓你是如何拖着残躯爬进这片乱葬荒冢，又在漫长的死寂里唤醒了怎样的古老秘术。昔日令诸邦战栗的伟力早已在逃亡中散佚殆尽，如今你必须重新踏足尘世，在古墓、战火与鲜血之间，一点点寻回遗失的力量与禁忌。\n\n身旁那辆破旧的马车在泥泞中吱呀作响，两名贪婪的盗墓贼正紧张地攥着缰绳，不时心虚地回头瞥向车厢深处——那里停放着一具钉满铜箍的沉重旧棺，棺内沉睡的残破荒坟守卫，正随着你指间跃动的幽蓝魂火微微震颤。\n\n圣火未能燃尽你的野心，放逐也未曾令你的法杖蒙尘。握紧手中的初生骷髅法杖吧，是铸就一尊踏碎万军的不朽勇士，还是驱使无尽尸潮吞没整片大地？亡者的时代，正待你亲手落子。",
            Image = "",
            Banner = "",
            List = [],
            Characters = [],
            Options = [
                {
                    Text = "“上路吧。亡者的时代开始了。”",
                    function getResult( _event )
                    {
                        return "B";
                    }
                }
            ],
            function start( _event )
            {
                this.Banner = "ui/banners/" + ::World.Assets.getBanner() + "s.png";
            }
        });
        // 1.6.22 开局荒坟守卫的来历
        this.m.Screens.push({
            ID = "B",
            Text = "",
            Image = "",
            Banner = "",
            List = [],
            Characters = [],
            Options = [
                {
                    Text = "“起来吧，你还有仗要打。”",
                    function getResult( _event )
                    {
                        return 0;
                    }
                }
            ],
            function start( _event )
            {
                this.Banner = "ui/banners/" + ::World.Assets.getBanner() + "s.png";
                this.Text = "[img]gfx/ui/events/pale/guard_lore.jpg[/img]" + ::PaleSovereign.GuardLoreFull + "\n\n" + ::PaleSovereign.IntroGuide;
            }
        });
    }

    function onUpdateScore()
    {
    }
});

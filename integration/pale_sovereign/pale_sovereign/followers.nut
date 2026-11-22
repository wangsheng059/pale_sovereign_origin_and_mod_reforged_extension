local S = ::PaleSovereign;

S.FollowerData <- {
    embalmer = {
        Name = "防腐师", Archetype = "Steward", Image = "ui/campfire/pale_embalmer",
        Description = "他身上的盐味和松脂味怎么也洗不掉。再破烂的尸体到了他手里，也能腌得整整齐齐，在车厢里码得严丝合缝。",
        Effects = ["每 3 具合格遗骸封存 2 点尸骸", "每日修补量提高至 30%", "开战时在战线后部署 2 具防腐尸体"]
    },
    gravekeeper = {
        Name = "掘墓人首领", Archetype = "Ranger", Image = "ui/campfire/pale_gravekeeper",
        Description = "他能从野草的颜色和地面的塌陷看出帝国旧墓的位置，也知道哪道墓门还没被人撬开过。",
        Effects = ["每 7 天标出一处未勘察的古代遗址", "勘察时魂玉概率 +5 个百分点，锁链概率 +10 个百分点", "清剿古代遗址额外获得古代武器或古代金币"]
    },
    wight_captain = {
        Name = "尸妖王侍卫长", Archetype = "Officer", Image = "ui/campfire/pale_wight_captain",
        Description = "一名从古帝国站岗至今的沉默军官。它早已不记得自己的名字，却还记得怎样操练一名冠军。",
        Effects = ["冠军经验 +20%", "缚魂锁链生命门槛 +5 个百分点", "冠军在首回合获得 +10 近战技能"]
    },
    banshee = {
        Name = "女妖", Archetype = "Agent", Image = "ui/campfire/pale_banshee",
        Description = "只有守夜的人听见过她的歌声。第二天早上，他们谁也不肯复述那首歌。",
        Effects = ["夜战首回合敌人决心 −5", "夜间大地图视野 +15%", "首回合随机一名敌人做一次 −15 的士气检定"]
    },
    blood_steward = {
        Name = "血宴管家", Archetype = "Healer", Image = "ui/campfire/pale_blood_steward",
        Description = "一个举止得体的吸血鬼，深谙如何让活人的血保持新鲜。战团接受了这个有些滑稽的安排，只是没人愿意和他单独吃饭。",
        Effects = ["活人生命恢复速度 +20%", "战胜后导师恢复 30% 最大生命", "每战导师首次击杀恢复 20 生命和 10 疲劳"]
    }
};

S.followerRank = function( _key )
{
    if (!this.isActive() || !("Retinue" in ::World) || ::World.Retinue == null)
        return 0;
    local index = ::PandorasHobby.Follower.Archetype[this.FollowerData[_key].Archetype];
    local follower = ::World.Retinue.PH_getFollowerAtIndex(index);
    return follower != null && follower.getID() == "follower.pale_" + _key ? follower.getPaleRank() : 0;
};

S.followerVictory = function()
{
    if (this.followerRank("blood_steward") >= 2)
    {
        local chief = this.chief();
        chief.setHitpoints(::Math.minf(chief.getHitpointsMax(), chief.getHitpoints() + chief.getHitpointsMax() * 0.30));
    }
    foreach (key, data in this.FollowerData)
    {
        if (this.followerRank(key) > 0)
            ::World.Retinue.PH_getFollowerAtIndex(::PandorasHobby.Follower.Archetype[data.Archetype]).earnVictoryXP();
    }
};

S.followerWorldTick = function()
{
    local age = this.worldHours();
    if (this.followerRank("gravekeeper") > 0 && age >= this.get("NextRangerLead"))
    {
        this.revealAncient(false, true);
        this.set("NextRangerLead", age + 7 * 24);
    }
};

S.followerOnKill = function( _killer )
{
    if (_killer == null || ::MSU.isNull(_killer) || !this.isChief(_killer) || this.Battle.BloodFeast || this.followerRank("blood_steward") < 3)
        return;
    this.Battle.BloodFeast = true;
    _killer.setHitpoints(::Math.min(_killer.getHitpointsMax(), _killer.getHitpoints() + 20));
    _killer.setFatigue(::Math.max(0, _killer.getFatigue() - 10));
    ::Tactical.EventLog.log("血宴管家的秘法生效，导师从首个击杀中恢复了生命和疲劳。");
};

S.followerBattleOpening <- function( _actor )
{
    if (!this.Battle.FollowerOpening && _actor.isPlayerControlled() && _actor.isPlacedOnMap())
    {
        this.Battle.FollowerOpening = true;
        local enemies = [];
        foreach (faction in ::Tactical.Entities.getAllInstances())
            foreach (enemy in faction)
                if (enemy.isAlive() && !enemy.isDying() && enemy.isPlacedOnMap() && !enemy.isAlliedWith(_actor))
                    enemies.push(enemy);
        if (this.followerRank("embalmer") >= 3)
        {
            local tile = _actor.getTile();
            local rear = this.area(tile).filter(@(_, t) !t.IsOccupiedByActor && !t.IsCorpseSpawned);
            if (enemies.len() > 0)
            {
                local distance = function( _tile )
                {
                    local nearest = 999;
                    foreach (enemy in enemies)
                        nearest = ::Math.min(nearest, _tile.getDistanceTo(enemy.getTile()));
                    return nearest;
                };
                rear.sort(@(a, b) distance(b) <=> distance(a));
            }
            for (local i = 0; i < ::Math.min(2, rear.len()); ++i)
                this.placeShot(rear[i]);
        }
        if (this.followerRank("banshee") >= 3 && enemies.len() > 0)
            enemies[::Math.rand(0, enemies.len() - 1)].checkMorale(-1, -15);
    }
};

S.Mod.hook("scripts/retinue/retinue_manager", function(q)
{
    q.getFollowersForUI = @(__original) function( _slot = 99 )
    {
        local result = __original(_slot);
        if (!S.isActive())
            return result;
        return result.filter(@(_, f) ["follower.ph_healer_00", "follower.ph_healer_11"].find(f.ID) == null);
    };

    q.PH_getTrainersForUI = @(__original) function( _slot = 99 )
    {
        local follower = this.PH_getFollowerAtIndex(_slot);
        return follower != null && follower.getID().find("follower.pale_") == 0 ? [] : __original(_slot);
    };
});

S.Mod.hook("scripts/entity/tactical/actor", function(q)
{
    q.onRoundStart = @(__original) function()
    {
        __original();
        if (S.Battle == null)
            return;
        local round = ::Time.getRound();
        if (round != 1)
            return;
        if (S.Battle.Night && S.followerRank("banshee") >= 1 && S.chief() != null && !this.isAlliedWith(S.chief()))
            this.getSkills().add(::new(S.SkillDir + "effects/pale_banshee_effect"));
        S.followerBattleOpening(this);
    };
});

S.Mod.rawHookTree("scripts/items/accessory/accessory", function(p)
{
    if (!("addXP" in p))
        return;
    local original = p.addXP;
    p.addXP = function( _xp )
    {
        if (S.isActive() && S.isCoffin(this) && (S.mainPet() == this || this.m.PaleID > 0) && S.followerRank("wight_captain") >= 1)
            _xp = ::Math.round(_xp * 1.20);
        return original.call(this, _xp);
    };
});

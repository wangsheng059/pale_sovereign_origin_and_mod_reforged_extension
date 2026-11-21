this.pale_sovereign_scenario <- ::inherit("scripts/scenarios/world/starting_scenario", {
    m = {},
    function create()
    {
        this.m.ID = ::PaleSovereign.ID;
        this.m.Name = "亡灵主宰";
        this.m.Description = "[p=c][img]gfx/ui/events/pale_sovereign.png[/img][/p][p]你从一具不肯安息的尸骨学会了第一道法术。如今，两名盗墓贼驾着载棺的旧车跟随你，等待你为这支战团立下誓言。\n\n[color=#bcad8c]两条誓约[/color]　首席学到独有特技时永久立誓。亡灵冠军缚魂养成一名棺椁护卫，亡灵天灾经营尸骸、补充尸群。\n[color=#bcad8c]人少而精[/color]　编制和部署各限 12 名兄弟，常驻亡灵计入编制。\n[color=#bcad8c]夜行[/color]　首席夜战决心 +20，地图夜间视野惩罚减半。\n[color=#bcad8c]化身[/color]　首席无法解雇，一旦战死，战役结束。[/p]";
        this.m.Difficulty = 2;
        this.m.Order = 108;
        this.m.IsFixedLook = false;
        this.m.RF_RebuildPerkTreeAfterSpawn <- false;
    }

    function isValid()
    {
        return ::BGP.HasAC;
    }

    function onInit()
    {
        ::World.Assets.m.BrothersMax = ::PaleSovereign.RosterLimit;
        ::World.Assets.m.BrothersMaxInCombat = ::PaleSovereign.RosterLimit;
    }

    function onSpawnAssets()
    {
        local s = ::PaleSovereign;
        local chief = s.spawnBrother("pale_necromancer_background", ["armor/wizard_robe", "weapons/pale_staff"], 13, false);
        chief.getSkills().add(::new("scripts/skills/traits/player_character_trait"));
        chief.getFlags().set("IsPlayerCharacter", true);
        chief.getFlags().set("PaleChief", true);
        s.nameChief(chief);
        chief.getItems().equip(s.makeGuard(true));
        chief.getSkills().update();
        s.spawnBrother("graverobber_background", ["armor/thick_tunic", "weapons/militia_spear", "shields/wooden_shield"], 4);
        s.spawnBrother("graverobber_background", ["armor/thick_tunic", "weapons/knife", "tools/throwing_net"], 5);
        s.addMaterials("chain", 2);
        local stash = ::World.Assets.getStash();
        stash.add(::new("scripts/items/supplies/bread_item"));
        stash.add(::new("scripts/items/supplies/ground_grains_item"));
        ::World.Assets.m.BusinessReputation = 0;
    }

    function onSpawnPlayer()
    {
        local start = null;
        foreach (town in ::World.EntityManager.getSettlements())
        {
            if (town.isMilitary() || town.isIsolatedFromRoads())
                continue;
            local tile = town.getTile();
            for (local d = 0; d < 6; ++d)
            {
                if (!tile.hasNextTile(d))
                    continue;
                local next = tile.getNextTile(d);
                if (!next.IsOccupied && next.HasRoad)
                {
                    start = next;
                    break;
                }
            }
            if (start != null)
                break;
        }
        if (start == null)
            start = ::World.EntityManager.getSettlements()[0].getTile();
        ::World.State.m.Player = ::World.spawnEntity("scripts/entity/world/player_party", start.Coords.X, start.Coords.Y);
        ::World.Assets.updateLook(0);
        ::World.getCamera().setPos(::World.State.m.Player.getPos());
    }

    function onUpdateHiringRoster( _roster )
    {
        foreach (bro in clone _roster.getAll())
            if (::PaleSovereign.isRejected(bro.getBackground().getID()))
                _roster.remove(bro);
    }

    function onBattleWon( _combatLoot )
    {
        ::PaleSovereign.onVictory(_combatLoot);
    }

    function onCombatFinished()
    {
        return ::PaleSovereign.chief() != null;
    }
});

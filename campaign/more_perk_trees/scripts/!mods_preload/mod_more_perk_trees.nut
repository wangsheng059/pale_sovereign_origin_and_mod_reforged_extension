// Veteran perk-tree unlock system with MSU master enable/disable toggle.
::modMorePerkTrees <- {
	Version = "1.1.0",
	ID = "morePerkTrees",
	Name = "更多特技树"
};

::modMorePerkTrees.HooksMod <- ::Hooks.register(::modMorePerkTrees.ID, ::modMorePerkTrees.Version, ::modMorePerkTrees.Name);

::modMorePerkTrees.HooksMod.queue(">mod_msu", function()
{
	::modMorePerkTrees.Mod <- ::MSU.Class.Mod(::modMorePerkTrees.ID, ::modMorePerkTrees.Version, ::modMorePerkTrees.Name);

	::mods_registerJS("mod_mpt.js");
	::mods_registerCSS("mod_mpt.css");

	local page = ::modMorePerkTrees.Mod.ModSettings.addPage("通用设置");
	local function add(elem)
	{
		page.addElement(elem);
	}
	::modMorePerkTrees.conf <- function(name)
	{
		return ::modMorePerkTrees.Mod.ModSettings.getSetting(name).getValue();
	};

	add(::MSU.Class.BooleanSetting("enableMPT", true, "启用老兵点系统",
		"开启时，兄弟升级按设定频率获得老兵点，可在城镇训练场消耗老兵点解锁额外特技树；关闭后不再发放老兵点，并隐藏训练场入口。"
	));

	add(::MSU.Class.RangeSetting("vetFreq", 5, 3, 10, 1, "老兵点获得频率",
		"兄弟获得老兵点的频率(按等级)。第一个点会在(频率+1)级时获得，之后每(频率)级再获得一个。例如，按照默认值的5，老兵点会在第6，11，16级获得，以此类推。"
	));

	::modMorePerkTrees.HooksMod.hook("scripts/skills/backgrounds/character_background", function(q)
	{
		q.onUpdateLevel = @(__original) function()
		{
			__original();
			if (!::modMorePerkTrees.conf("enableMPT"))
				return;

			local actor = this.getContainer().getActor();
			if (actor.getLevel() % ::modMorePerkTrees.conf("vetFreq") == 1)
				actor.m.Flags.increment("mpt_veteran_points");
		};
	});

	::modMorePerkTrees.HooksMod.hook("scripts/ui/screens/world/modules/world_town_screen/town_training_dialog_module", function(q)
	{
		q.queryRosterInformation = @(__original) function()
		{
			local ret = __original();
			if (!::modMorePerkTrees.conf("enableMPT"))
				return ret;

			foreach (bro in ret.Roster)
			{
				local actor = this.Tactical.getEntityByID(bro.ID);
				if ("" + actor.m.Flags.get("mpt_veteran_points") == "false")
				{
					local vetPts = this.Math.floor((actor.getLevel() - 1) / ::modMorePerkTrees.conf("vetFreq"));
					if (vetPts < 0) vetPts = 0;
					actor.m.Flags.set("mpt_veteran_points", vetPts);
				}
				bro.Training.push({
					id = 11,
					icon = "skills/status_effect_73.png",
					name = "花费老兵点",
					tooltip = "mpt_spend_veteran_points_tooltip",
					price = actor.m.Flags.get("mpt_veteran_points")
				});
			}

			local brothers = this.World.getPlayerRoster().getAll();
			foreach (b in brothers)
			{
				if (b.getLevel() >= 11 || (b.getLevel() >= 7 && this.World.Assets.getOrigin().getID() == "scenario.manhunters" && b.getBackground().getID() == "background.slave") || b.getSkills().hasSkill("effects.trained"))
				{
					local background = b.getBackground();
					local e = {
						ID = b.getID(),
						Name = b.getName(),
						Level = b.getLevel(),
						ImagePath = b.getImagePath(),
						ImageOffsetX = b.getImageOffsetX(),
						ImageOffsetY = b.getImageOffsetY(),
						BackgroundImagePath = background.getIconColored(),
						BackgroundText = background.getDescription(),
						Training = [],
						Effects = []
					};
					if ("" + b.m.Flags.get("mpt_veteran_points") == "false")
					{
						local vetPts = this.Math.floor((b.getLevel() - 1) / ::modMorePerkTrees.conf("vetFreq"));
						if (vetPts < 0) vetPts = 0;
						b.m.Flags.set("mpt_veteran_points", vetPts);
					}
					e.Training.push({
						id = 11,
						icon = "skills/status_effect_73.png",
						name = "花费老兵点",
						tooltip = "mpt_spend_veteran_points_tooltip",
						price = b.m.Flags.get("mpt_veteran_points")
					});
					ret.Roster.push(e);
				}
			}
			return ret;
		};

		q.onTrain = @(__original) function( _data )
		{
			local entityID = _data[0];
			local trainingID = _data[1];
			if (trainingID == 11 && ::modMorePerkTrees.conf("enableMPT"))
			{
				local entity = this.Tactical.getEntityByID(entityID);
				entity.getSkills().add(this.new("scripts/skills/effects/choose_bro_for_mpt_effect"));
				::World.State.getMenuStack().popAll(true);
				::World.Events.fire("event.mpt_new_perk_tree");

				local background = entity.getBackground();
				local e = {
					ID = entity.getID(),
					Name = entity.getName(),
					Level = entity.getLevel(),
					ImagePath = entity.getImagePath(),
					ImageOffsetX = entity.getImageOffsetX(),
					ImageOffsetY = entity.getImageOffsetY(),
					BackgroundImagePath = background.getIconColored(),
					BackgroundText = background.getDescription(),
					Training = [],
					Effects = []
				};
				return {
					Entity = e,
					Assets = this.m.Parent.queryAssetsInformation()
				};
			}
			return __original(_data);
		};
	});

	::modMorePerkTrees.HooksMod.hook("scripts/ui/screens/tooltip/tooltip_events", function(q)
	{
		q.general_queryUIElementTooltipData = @(__original) function( _entityId, _elementId, _elementOwner )
		{
			if (_elementId == "mpt_spend_veteran_points_tooltip")
			{
				return [
					{
						id = 1,
						type = "title",
						text = "花费老兵点"
					},
					{
						id = 2,
						type = "description",
						text = "花费老兵点来获得额外的特技树。从" + (::modMorePerkTrees.conf("vetFreq") + 1) + "级开始，兄弟每升" + ::modMorePerkTrees.conf("vetFreq") + "级，就会获得1个老兵点。"
					}
				];
			}
			return __original(_entityId, _elementId, _elementOwner);
		};
	});
}, ::Hooks.QueueBucket.Late);

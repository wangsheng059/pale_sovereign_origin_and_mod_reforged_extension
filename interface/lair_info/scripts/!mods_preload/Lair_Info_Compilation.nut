// Lair defender scouting & famed item tooltip display with non-mutating MSU toggles.
::mods_registerMod("Lair_Info_Compilation", 1.1);

::mods_queue("Lair_Info_Compilation", null, function()
{
	::mods_hookBaseClass("entity/world/location", function(o)
	{
		while (!("getTooltip" in o)) o = o[o.SuperName];
		local getTooltip = o.getTooltip;
		o.getTooltip = function()
		{
			local scoutOn = !("LocalInterface" in ::getroottable()) || ::LocalInterface.get("UI_LairScout", true);
			local namedOn = !("LocalInterface" in ::getroottable()) || ::LocalInterface.get("UI_LairNamed", true);

			local prevShowing = this.m.IsShowingDefenders;
			if (scoutOn && !prevShowing)
				this.m.IsShowingDefenders = true;

			local tooltip = null;
			try
			{
				tooltip = getTooltip();
			}
			catch (e)
			{
				this.m.IsShowingDefenders = prevShowing;
				throw e;
			}
			this.m.IsShowingDefenders = prevShowing;

			if (!namedOn || tooltip == null)
				return tooltip;

			if (this.isLocationType(this.Const.World.LocationType.Lair) && !this.isLocationType(this.Const.World.LocationType.Unique))
			{
				local tile = this.getTile(), nearestSettlement = 9000;
				foreach (s in this.World.EntityManager.getSettlements())
				{
					local d = tile.getDistanceTo(s.getTile());
					if (d < nearestSettlement) nearestSettlement = d;
				}

				local chance = this.Math.min(100, this.Math.round((nearestSettlement * 4 + this.m.Resources) * 0.2 - 37));
				if (chance > 0)
					tooltip.append({ id = 123, type = "description", text = "\n营地生成时红装概率: " + chance + "%" });
			}

			if (!this.getLoot().isEmpty())
			{
				local i = 0;
				foreach (item in this.getLoot().getItems())
				{
					if (item != null && item.isItemType(this.Const.Items.ItemType.Named))
					{
						tooltip.push({
							id = 200 + i,
							type = "title",
							icon = "ui/items/" + item.getIcon(),
							text = "[color=" + this.Const.UI.Color.NegativeEventValue + "]" + item.getName() + "[/color]"
						});
						i = i + 1;
					}
				}
			}
			return tooltip;
		};
	});
});

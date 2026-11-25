// Incremental appearance-signature naked portrait cache for Career Stats.
// - Never runs on town enter (zero enter freeze).
// - On town leave or Obituary open, only re-renders brothers whose naked portrait
//   is missing or whose appearance changed, and restores all equipment immediately.

::CareerStats._portraitSignature <- function( _bro )
{
	local sig = "";
	foreach (layer in ::CareerStats.AppearanceLayers)
	{
		sig += "|";
		try
		{
			local sp = _bro.getSprite(layer);
			if (sp != null && sp.HasBrush) sig += sp.getBrush().Name;
		}
		catch (e) {}
	}
	return sig;
};

::CareerStats.cacheNakedPortraits <- function( _forceAll = false )
{
	local equipmentLayers = [
		"armor", "armor_upgrade_back", "armor_upgrade_front",
		"helmet", "helmet_damage", "surcoat",
		"accessory", "accessory_special", "shaft", "quiver",
		"body_blood", "dirt", "injury", "injury_body",
		"bandage_1", "bandage_2", "bandage_3"
	];
	local bodyLayers = ["head", "hair", "beard", "beard_top", "tattoo_head"];

	local bros = ::World.getPlayerRoster().getAll();
	local dirty = [];
	local sigs = [];

	foreach (bro in bros)
	{
		if (bro == null) continue;
		try { if ("isNull" in bro && bro.isNull()) continue; } catch (e) {}

		local sig = ::CareerStats._portraitSignature(bro);
		local cachedPath = ("CareerStats_CachedPortrait" in bro.m) ? bro.m.CareerStats_CachedPortrait : null;
		local cachedSig  = ("CareerStats_PortraitSig" in bro.m) ? bro.m.CareerStats_PortraitSig : null;

		if (_forceAll || cachedPath == null || cachedPath == "" || cachedSig != sig)
		{
			dirty.push(bro);
			sigs.push(sig);
		}
	}

	if (dirty.len() == 0) return 0;

	local savedEquipment = [];
	local savedVisibility = [];
	local savedItems = [];

	// Pass 1: unequip held items (triggers internal sprite update).
	foreach (bro in dirty)
	{
		try
		{
			local items = bro.getItems();
			local mainhand = items.getItemAtSlot(::Const.ItemSlot.Mainhand);
			local offhand  = items.getItemAtSlot(::Const.ItemSlot.Offhand);
			if (mainhand != null)
			{
				savedItems.push({ bro = bro, item = mainhand });
				items.unequip(mainhand);
			}
			if (offhand != null)
			{
				savedItems.push({ bro = bro, item = offhand });
				items.unequip(offhand);
			}
		}
		catch (e) {}
	}

	// Pass 2: clear armor/helmet overlays & reveal head layers.
	foreach (bro in dirty)
	{
		try
		{
			foreach (layer in equipmentLayers)
			{
				try
				{
					local sprite = bro.getSprite(layer);
					if (sprite != null && sprite.HasBrush)
					{
						savedEquipment.push({ bro = bro, layer = layer, brushName = sprite.getBrush().Name });
						sprite.resetBrush();
					}
				}
				catch (e2) {}
			}

			foreach (layer in bodyLayers)
			{
				try
				{
					local sprite = bro.getSprite(layer);
					if (sprite != null && !sprite.Visible)
					{
						savedVisibility.push({ bro = bro, layer = layer, wasVisible = false });
						sprite.Visible = true;
					}
				}
				catch (e2) {}
			}

			bro.setDirty(true);
		}
		catch (e) {}
	}

	// Capture cached portrait path + signature.
	for (local i = 0; i < dirty.len(); i++)
	{
		local bro = dirty[i];
		try
		{
			local path = bro.getImagePath();
			local ox   = bro.getImageOffsetX();
			local oy   = bro.getImageOffsetY();
			if ("CareerStats_CachedPortrait" in bro.m)
			{
				bro.m.CareerStats_CachedPortrait  = path;
				bro.m.CareerStats_CachedPortraitX = ox;
				bro.m.CareerStats_CachedPortraitY = oy;
			}
			else
			{
				bro.m.CareerStats_CachedPortrait  <- path;
				bro.m.CareerStats_CachedPortraitX <- ox;
				bro.m.CareerStats_CachedPortraitY <- oy;
			}
			if ("CareerStats_PortraitSig" in bro.m)
				bro.m.CareerStats_PortraitSig = sigs[i];
			else
				bro.m.CareerStats_PortraitSig <- sigs[i];
		}
		catch (e) {}
	}

	// Restore equipment sprites, visibility, and held items immediately.
	foreach (saved in savedEquipment)
	{
		try
		{
			local sprite = saved.bro.getSprite(saved.layer);
			if (sprite != null) sprite.setBrush(saved.brushName);
		}
		catch (e) {}
	}
	foreach (saved in savedVisibility)
	{
		try
		{
			local sprite = saved.bro.getSprite(saved.layer);
			if (sprite != null) sprite.Visible = saved.wasVisible;
		}
		catch (e) {}
	}
	foreach (saved in savedItems)
	{
		try { saved.bro.getItems().equip(saved.item); }
		catch (e) {}
	}
	foreach (bro in dirty)
	{
		try { bro.setDirty(true); } catch (e) {}
	}

	return dirty.len();
};

// Incremental cache on town leave only (catches new hires & barber changes with <10ms warm cost).
::CareerStats.MH.hook("scripts/ui/screens/world/modules/world_town_screen/town_main_dialog_module", function(q)
{
	q.onLeaveButtonPressed = @(__original) function()
	{
		try { ::CareerStats.cacheNakedPortraits(false); } catch (e) {}
		return __original();
	};
});

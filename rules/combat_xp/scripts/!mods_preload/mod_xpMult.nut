// 大规模战队更多经验加成 - wrapper rewrite.
//
// What the mod does (unchanged): when more than 12 brothers are fielded, all
// experience is multiplied by (fielded brothers / 12).
//
// What changed: the old version replaced player.addXP() on every brother with
// a full copy of old vanilla code, so anything the game or other mods
// (Reforged, Legacy XP share, ...) do in addXP was lost. This version only
// scales the incoming amount and then calls the original function.

::mods_hookExactClass("entity/tactical/player", function(o)
{
	local addXP = o.addXP;
	o.addXP = function( _xp, _scale = true )
	{
		if (("State" in this.World) && this.World.State != null)
		{
			local inBattle = 0;

			foreach (bro in this.World.getPlayerRoster().getAll())
			{
				if (bro.getPlaceInFormation() < 18)
				{
					inBattle++;
				}
			}

			if (inBattle > 12)
			{
				_xp = _xp * (1.0 * inBattle / 12);
			}
		}

		return addXP(_xp, _scale);
	}
});

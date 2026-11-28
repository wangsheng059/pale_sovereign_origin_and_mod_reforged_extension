// Snapshot vanilla terrain vision multipliers and apply the classic per-terrain defaults (1.15 flat/forest, 2.5 hills, 3.5 mountains).
local gt = this.getroottable();
if ("World" in gt.Const && "TerrainTypeVisionRadiusMult" in gt.Const.World)
{
	if (!("BGP_BaseTerrainVision" in gt.Const.World))
		gt.Const.World.BGP_BaseTerrainVision <- clone gt.Const.World.TerrainTypeVisionRadiusMult;

	local arr = gt.Const.World.TerrainTypeVisionRadiusMult;
	local tt = ("TerrainType" in gt.Const.World) ? gt.Const.World.TerrainType : {};
	local hillsIdx = ("Hills" in tt) ? tt.Hills : 4;
	local mtnIdx = ("Mountains" in tt) ? tt.Mountains : 9;

	for (local i = 0; i < arr.len(); i++)
	{
		if (i == hillsIdx)
			arr[i] = 2.5;
		else if (i == mtnIdx)
			arr[i] = 3.5;
		else
			arr[i] = 1.15;
	}
}

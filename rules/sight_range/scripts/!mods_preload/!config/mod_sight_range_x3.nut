// Snapshot vanilla terrain vision multipliers before applying the configurable multiplier.
local gt = this.getroottable();
if ("World" in gt.Const && "TerrainTypeVisionRadiusMult" in gt.Const.World)
{
	if (!("BGP_BaseTerrainVision" in gt.Const.World))
		gt.Const.World.BGP_BaseTerrainVision <- clone gt.Const.World.TerrainTypeVisionRadiusMult;

	local orig = gt.Const.World.BGP_BaseTerrainVision;
	for (local i = 0; i < orig.len(); i++)
		gt.Const.World.TerrainTypeVisionRadiusMult[i] = orig[i] * 2.0;
}

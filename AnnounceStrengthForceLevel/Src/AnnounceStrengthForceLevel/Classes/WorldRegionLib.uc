/**
 * WorldRegionLib
 *
 * Utility library responsible for mapping LWOTC world regions
 * to stable hardcoded region indices used throughout the mod.
 *
 * Responsibilities:
 * - Convert WorldRegion template names into region indices
 * - Provide a centralized region mapping implementation
 * - Support MCM regional settings lookup
 * - Support region-specific gameplay logic
 *
 * Region indices are intentionally hardcoded to maintain
 * stable configuration bindings across save files and MCM settings.
 *
 * @author Tigrik
 */
class WorldRegionLib extends Object;

`include(AnnounceStrengthForceLevel\Src\AnnounceStrengthForceLevel\LoggerMacros.uci)

/**
 * Retrieves the hardcoded region index for a world region state.
 *
 * @param Region    World region game state object
 *
 * @return int      Stable region index, or INDEX_NONE if invalid
 */
static function int GetRegionIndex(XComGameState_WorldRegion Region)
{
	`TRACE_ENTRY("");
    return GetRegionIndexByName(Region.GetMyTemplateName());
}

/**
 * Retrieves the hardcoded region index for a world region template name.
 *
 * Region indices are used for:
 * - Regional MCM settings
 * - Pause filtering logic
 * - Region-specific notifications
 *
 * @param RegionName    World region template name
 *
 * @return int          Stable region index, or INDEX_NONE if unknown
 */
static function int GetRegionIndexByName(name RegionName)
{
	`TRACE_ENTRY("");
    switch (RegionName)
    {
        case 'WorldRegion_EastNA':	return 0;
		case 'WorldRegion_WestNA':	return 1;
		case 'WorldRegion_SouthNA': return 2;
		case 'WorldRegion_NorthSA': return 3;
		case 'WorldRegion_SouthSA': return 4;
		case 'WorldRegion_WestEU':	return 5;
		case 'WorldRegion_EastEU':	return 6;
		case 'WorldRegion_NorthAF': return 7;
		case 'WorldRegion_EastAF':	return 8;
		case 'WorldRegion_SouthAF': return 9;
		case 'WorldRegion_EastAS':	return 10;
		case 'WorldRegion_WestAS':	return 11;
		case 'WorldRegion_NorthAS': return 12;
		case 'WorldRegion_SouthAS': return 13;
		case 'WorldRegion_NorthOC': return 14;
		case 'WorldRegion_SouthOC': return 15;
    }

	`ERROR("Unexpected RegionName. Expected 1 of 16, e.g. 'WorldRegion_EastNA'. Actual RegionName:" @ RegionName);
	`TRACE_EXIT("Return: INDEX_NONE");
    return INDEX_NONE;
}
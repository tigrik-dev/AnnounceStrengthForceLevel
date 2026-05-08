class WorldRegionLib extends Object;

`include(AnnounceStrengthForceLevel\Src\AnnounceStrengthForceLevel\LoggerMacros.uci)

static function int GetRegionIndex(XComGameState_WorldRegion Region)
{
	`TRACE_ENTRY("");
    return GetRegionIndexByName(Region.GetMyTemplateName());
}

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
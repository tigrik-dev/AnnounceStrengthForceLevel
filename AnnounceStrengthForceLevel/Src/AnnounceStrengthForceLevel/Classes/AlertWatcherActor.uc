/**
 * AlertWatcherActor
 *
 * Lightweight geoscape polling actor responsible for monitoring
 * LWOTC regional strategy values such as:
 * - ADVENT Strength (Local Alert Level)
 * - Force Level (Local Force Level)
 *
 * Responsibilities:
 * - Periodically poll all world regions while on the geoscape
 * - Detect increases in ADVENT Strength
 * - Detect both global and regional Force Level increases
 * - Display strategy notifications to the player
 * - Optionally pause the geoscape when configured via MCM
 * - Maintain cached regional values to detect changes efficiently
 * - Enforce singleton behavior to prevent duplicate polling actors
 *
 * Notes:
 * - Polling rate is configurable through MCM/config
 * - Minimum polling interval is clamped to 0.1 seconds
 * - Global Force Level increases are determined by majority detection
 * - Regional Force Level increases are treated as modded/special cases
 *
 * @author Tigrik
 */
class AlertWatcherActor extends Actor config(AnnounceStrengthForceLevel_Config);

`include(AnnounceStrengthForceLevel\Src\AnnounceStrengthForceLevel\LoggerMacros.uci)
`include(AnnounceStrengthForceLevel\Src\AnnounceStrengthForceLevel\MCM_API_CfgHelpers.uci)

var localized string sStengthIncreased, sStengthDecreased, sForceIncreased, sForceRegionIncreased;

var config float fPollingRate;

var array<int> CachedRegionIDs, CachedAlertLevels, CachedForceLevels;

var float TimeAccumulator, EffectivePollingRate;

var bool bInitialized;
var int LastProcessedDayStamp;

/**
 * Initializes the watcher actor after spawning.
 *
 * Responsibilities:
 * - Enforce singleton behavior
 * - Destroy duplicate watcher actors
 * - Initialize effective polling rate
 * - Clamp polling rate to a minimum safe value
 */
event PostBeginPlay()
{
    local AlertWatcherActor ExistingWatcher;

	`TRACE_ENTRY("");

    super.PostBeginPlay();

	// Force a polling rate to be at minimum 0.1 seconds
	EffectivePollingRate = FMax(default.fPollingRate, 0.1f);

    foreach AllActors(class'AlertWatcherActor', ExistingWatcher)
    {
        if (ExistingWatcher != self)
        {
            Destroy();
			`TRACE_EXIT("AlertWatcherActor already exists. Destroying self");
            return;
        }
    }
	`TRACE_EXIT("");
}

/**
 * Performs periodic geoscape polling updates.
 *
 * Responsibilities:
 * - Accumulate real time between polling intervals
 * - Prevent excessive polling frequency
 * - Detect geoscape time progression
 * - Trigger regional strategy value checks
 *
 * @param DeltaTime    Time elapsed since previous frame
 */
event Tick(float DeltaTime)
{
    local TDateTime CurrentTime;
	local int CurrentStamp;

    TimeAccumulator += DeltaTime;
    if (TimeAccumulator < EffectivePollingRate) return;

    TimeAccumulator = 0;

    CurrentTime = `STRATEGYRULES.GameTime;

    CurrentStamp = CurrentTime.m_iYear * 1000000
             + CurrentTime.m_iMonth * 10000
             + CurrentTime.m_iDay * 100
			 + CurrentTime.m_fTime;

	if (CurrentStamp == LastProcessedDayStamp) return;

	LastProcessedDayStamp = CurrentStamp;

    CheckAlertLevels();
}

/**
 * Checks all world regions for changes in:
 * - ADVENT Strength (Alert Level)
 * - Force Level
 *
 * Responsibilities:
 * - Compare current regional values against cached values
 * - Detect ADVENT Strength increases
 * - Detect Force Level increases
 * - Distinguish between global and regional Force Level changes
 * - Display notifications
 * - Pause geoscape if configured via MCM
 * - Update cached values after processing
 *
 * Global Force Level increases are determined by majority detection:
 * if at least half of all regions increased simultaneously,
 * the increase is considered global.
 *
 * Regional-only increases are treated as special/modded behavior.
 */
function CheckAlertLevels()
{
    local XComGameStateHistory History;
    local XComGameState_WorldRegion Region;
    local XComGameState_WorldRegion_LWStrategyAI RegionalAI;

    local int i, CachedIndex, NewAlertLevel, NewForceLevel, MajorityForceLevel, BestCount, Count, TestForceLevel;
	local XGParamTag ParamTag;
	local string sNotify;
	local array<int> IncreasedForceLevels;
	local array<string> IncreasedForceRegionNames;

	`TRACE_ENTRY("");

	// First run: just populate cache, don’t log anything
    if (!bInitialized)
	{
		InitializeCache();
		bInitialized = true;
		return;
	}

    History = `XCOMHISTORY;

    foreach History.IterateByClassType(class'XComGameState_WorldRegion', Region)
    {
        RegionalAI = class'XComGameState_WorldRegion_LWStrategyAI'.static.GetRegionalAI(Region);

        if (RegionalAI == none) continue;

        CachedIndex = CachedRegionIDs.Find(Region.ObjectID);
        NewAlertLevel = RegionalAI.LocalAlertLevel;
		NewForceLevel = RegionalAI.LocalForceLevel;

        if (CachedIndex == INDEX_NONE)
        {
            CachedRegionIDs.AddItem(Region.ObjectID);
            CachedAlertLevels.AddItem(NewAlertLevel);
			CachedForceLevels.AddItem(NewForceLevel);
        }
        else
        {
            if (Region.HaveMadeContact() && !RegionalAI.bLiberated)
            {
				if (NewAlertLevel > CachedAlertLevels[CachedIndex])
				{
					// Pause Geoscape if MCM options permit it
					if (Get_PAUSE_ADVENT_STRENGTH() && NewAlertLevel >= Get_MIN_ADVENT_STRENGTH_PAUSE() && ShouldPauseForRegion(class'WorldRegionLib'.static.GetRegionIndex(Region))) PauseGeoscape();

					// Don't notify if MCM option "Show notifications when ADVENT Strength increases" is unchecked
					if (!Get_NOTIFY_ADVENT_STRENGTH()) continue;

					ParamTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
					ParamTag.IntValue0 = CachedAlertLevels[CachedIndex];
					ParamTag.IntValue1 = NewAlertLevel;
					ParamTag.StrValue0 = Region.GetDisplayName();
					sNotify = `XEXPAND.ExpandString(sStengthIncreased);

					CachedAlertLevels[CachedIndex] = NewAlertLevel;

					`INFO(sNotify);
					`HQPRES.Notify(sNotify, class'UIUtilities_Image'.const.EventQueue_Advent);
				}
				else if (NewAlertLevel < CachedAlertLevels[CachedIndex])
				{
					// Pause Geoscape if MCM options permit it
					if (Get_PAUSE_ADVENT_STRENGTH_DEC() && (NewAlertLevel >= Get_MIN_ADVENT_STRENGTH_PAUSE() || CachedAlertLevels[CachedIndex] >= Get_MIN_ADVENT_STRENGTH_PAUSE())) PauseGeoscape();
					
					// Don't notify if MCM option "Show notifications when ADVENT Strength decreases" is unchecked
					if (!Get_NOTIFY_ADVENT_STRENGTH_DEC()) continue;

					ParamTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
					ParamTag.IntValue0 = CachedAlertLevels[CachedIndex];
					ParamTag.IntValue1 = NewAlertLevel;
					ParamTag.StrValue0 = Region.GetDisplayName();
					sNotify = `XEXPAND.ExpandString(sStengthDecreased);

					CachedAlertLevels[CachedIndex] = NewAlertLevel;

					`INFO(sNotify);
					`HQPRES.Notify(sNotify, class'UIUtilities_Image'.const.EventQueue_Advent);
				}
            }

			if (NewForceLevel > CachedForceLevels[CachedIndex])
			{
				IncreasedForceRegionNames.AddItem(Region.GetDisplayName());
				IncreasedForceLevels.AddItem(NewForceLevel);

				CachedForceLevels[CachedIndex] = NewForceLevel;
			}
		}
    }

	// Handle Force Level notifications after all regions were scanned
	if (IncreasedForceRegionNames.Length == 0) return;

	// GLOBAL increase (default behavior)
	if (IncreasedForceRegionNames.Length >= 8)
	{
		// Find most common force level
		for (i = 0; i < IncreasedForceLevels.Length; ++i)
		{
			TestForceLevel = IncreasedForceLevels[i];
			Count = 0;

			foreach IncreasedForceLevels(NewForceLevel)
			{
				if (NewForceLevel == TestForceLevel) ++Count;
			}

			if (Count > BestCount)
			{
				BestCount = Count;
				MajorityForceLevel = TestForceLevel;
			}
		}

		// Pause Geoscape if MCM options permit it
		if (Get_PAUSE_FORCE_LEVEL() && MajorityForceLevel >= Get_MIN_FORCE_LEVEL_PAUSE()) PauseGeoscape();

		// Notify if enabled
		if (Get_NOTIFY_FORCE_LEVEL())
		{
			ParamTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
			ParamTag.IntValue0 = MajorityForceLevel;
			sNotify = `XEXPAND.ExpandString(sForceIncreased);

			`INFO(sNotify);
			`HQPRES.Notify(sNotify, class'UIUtilities_Image'.const.EventQueue_Alien);
		}
	}
	// REGIONAL increase (e.g. by a mod "A Requiem For Man: Gameplay Mutators")
	else
	{
		for (i = 0; i < IncreasedForceRegionNames.Length; ++i)
		{
			NewForceLevel = IncreasedForceLevels[i];

			// Pause if enabled
			if (Get_PAUSE_FORCE_LEVEL() && NewForceLevel >= Get_MIN_FORCE_LEVEL_PAUSE()) PauseGeoscape();

			// Notify if enabled
			if (Get_NOTIFY_FORCE_LEVEL())
			{
				ParamTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
				ParamTag.IntValue0 = NewForceLevel;
				ParamTag.StrValue0 = IncreasedForceRegionNames[i];
				sNotify = `XEXPAND.ExpandString(sForceRegionIncreased);

				`INFO(sNotify);
				`HQPRES.Notify(sNotify, class'UIUtilities_Image'.const.EventQueue_Alien);
			}
		}
	}

	`TRACE_EXIT("");
}


/**
 * Initializes cached regional strategy values.
 *
 * Responsibilities:
 * - Populate cached region object IDs
 * - Populate cached ADVENT Strength values
 * - Populate cached Force Level values
 * - Prepare watcher state for future polling comparisons
 *
 * This function is executed once during the first polling cycle.
 */
function InitializeCache()
{
    local XComGameStateHistory History;
    local XComGameState_WorldRegion Region;
    local XComGameState_WorldRegion_LWStrategyAI RegionalAI;

	`TRACE_ENTRY("");

    History = `XCOMHISTORY;

    CachedRegionIDs.Length = 0;
    CachedAlertLevels.Length = 0;
	CachedForceLevels.Length = 0;

    foreach History.IterateByClassType(class'XComGameState_WorldRegion', Region)
    {
        RegionalAI = class'XComGameState_WorldRegion_LWStrategyAI'.static.GetRegionalAI(Region);

        if (RegionalAI == none) continue;

        CachedRegionIDs.AddItem(Region.ObjectID);
        CachedAlertLevels.AddItem(RegionalAI.LocalAlertLevel);
		CachedForceLevels.AddItem(RegionalAI.LocalForceLevel);
    }

	`TRACE_EXIT("AlertWatcher: Cache initialized with " $ CachedRegionIDs.Length $ " regions");
}

/**
 * Pauses the geoscape simulation.
 *
 * Responsibilities:
 * - Pause geoscape progression
 * - Avoid interrupting active flight mode
 * - Resume geoscape immediately after pausing
 *
 * Used when configured MCM thresholds are reached.
 */
function PauseGeoscape()
{
	local UIStrategyMap StrategyMap;
	local XGGeoscape Geoscape;

	`TRACE_ENTRY("");

	StrategyMap = `HQPRES.StrategyMap2D;
	if (StrategyMap != none && StrategyMap.m_eUIState != eSMS_Flight)
	{
		`DEBUG("Pausing Geoscape");
		Geoscape = `GAME.GetGeoscape();
		Geoscape.Pause();
		Geoscape.Resume();
	}

	`TRACE_EXIT("");
}

/**
 * Determines whether geoscape pausing is enabled
 * for a specific world region.
 *
 * Responsibilities:
 * - Map region index values to corresponding MCM settings
 * - Return whether pausing is enabled for that region
 * - Validate region index range
 *
 * Supported region indices:
 * - 0 through 15
 *
 * @param RegionIndex    Internal world region index
 *
 * @return bool          True if pausing is enabled for the region
 */
function bool ShouldPauseForRegion(int RegionIndex)
{
	`TRACE_ENTRY("RegionIndex:" @ RegionIndex);
	switch (RegionIndex)
	{
		case 0:  return Get_ADVENT_STRENGTH_PAUSE_REGION_0();
		case 1:  return Get_ADVENT_STRENGTH_PAUSE_REGION_1();
		case 2:  return Get_ADVENT_STRENGTH_PAUSE_REGION_2();
		case 3:  return Get_ADVENT_STRENGTH_PAUSE_REGION_3();
		case 4:  return Get_ADVENT_STRENGTH_PAUSE_REGION_4();
		case 5:  return Get_ADVENT_STRENGTH_PAUSE_REGION_5();
		case 6:  return Get_ADVENT_STRENGTH_PAUSE_REGION_6();
		case 7:  return Get_ADVENT_STRENGTH_PAUSE_REGION_7();
		case 8:  return Get_ADVENT_STRENGTH_PAUSE_REGION_8();
		case 9:  return Get_ADVENT_STRENGTH_PAUSE_REGION_9();
		case 10: return Get_ADVENT_STRENGTH_PAUSE_REGION_10();
		case 11: return Get_ADVENT_STRENGTH_PAUSE_REGION_11();
		case 12: return Get_ADVENT_STRENGTH_PAUSE_REGION_12();
		case 13: return Get_ADVENT_STRENGTH_PAUSE_REGION_13();
		case 14: return Get_ADVENT_STRENGTH_PAUSE_REGION_14();
		case 15: return Get_ADVENT_STRENGTH_PAUSE_REGION_15();
	}

	`ERROR("Unexpected RegionIndex. Expected a value between 0 - 15. Actual RegionIndex:" @ RegionIndex);
	`TRACE_EXIT("Return: false");
    return false;
}

`MCM_CH_VersionChecker(class'MCM_Defaults'.default.VERSION, class'UIS_MCM'.default.CONFIG_VERSION)

function bool Get_NOTIFY_ADVENT_STRENGTH()
{
	return `MCM_CH_GetValue(class'MCM_Defaults'.default.NOTIFY_ADVENT_STRENGTH, class'UIS_MCM'.default.NOTIFY_ADVENT_STRENGTH);
}

function bool Get_NOTIFY_ADVENT_STRENGTH_DEC()
{
	return `MCM_CH_GetValue(class'MCM_Defaults'.default.NOTIFY_ADVENT_STRENGTH_DEC, class'UIS_MCM'.default.NOTIFY_ADVENT_STRENGTH_DEC);
}

function bool Get_NOTIFY_FORCE_LEVEL()
{
	return `MCM_CH_GetValue(class'MCM_Defaults'.default.NOTIFY_FORCE_LEVEL, class'UIS_MCM'.default.NOTIFY_FORCE_LEVEL);
}

function bool Get_PAUSE_ADVENT_STRENGTH()
{
	return `MCM_CH_GetValue(class'MCM_Defaults'.default.PAUSE_ADVENT_STRENGTH, class'UIS_MCM'.default.PAUSE_ADVENT_STRENGTH);
}

function bool Get_PAUSE_ADVENT_STRENGTH_DEC()
{
	return `MCM_CH_GetValue(class'MCM_Defaults'.default.PAUSE_ADVENT_STRENGTH_DEC, class'UIS_MCM'.default.PAUSE_ADVENT_STRENGTH_DEC);
}

function bool Get_PAUSE_FORCE_LEVEL()
{
	return `MCM_CH_GetValue(class'MCM_Defaults'.default.PAUSE_FORCE_LEVEL, class'UIS_MCM'.default.PAUSE_FORCE_LEVEL);
}

function int Get_MIN_ADVENT_STRENGTH_PAUSE()
{
	return `MCM_CH_GetValue(class'MCM_Defaults'.default.MIN_ADVENT_STRENGTH_PAUSE, class'UIS_MCM'.default.MIN_ADVENT_STRENGTH_PAUSE);
}

function int Get_MIN_FORCE_LEVEL_PAUSE()
{
	return `MCM_CH_GetValue(class'MCM_Defaults'.default.MIN_FORCE_LEVEL_PAUSE, class'UIS_MCM'.default.MIN_FORCE_LEVEL_PAUSE);
}

function bool Get_ADVENT_STRENGTH_PAUSE_REGION_0()
{
	return `MCM_CH_GetValue(class'MCM_Defaults'.default.ADVENT_STRENGTH_PAUSE_REGION_0, class'UIS_MCM'.default.ADVENT_STRENGTH_PAUSE_REGION_0);
}

function bool Get_ADVENT_STRENGTH_PAUSE_REGION_1()
{
	return `MCM_CH_GetValue(class'MCM_Defaults'.default.ADVENT_STRENGTH_PAUSE_REGION_1, class'UIS_MCM'.default.ADVENT_STRENGTH_PAUSE_REGION_1);
}

function bool Get_ADVENT_STRENGTH_PAUSE_REGION_2()
{
	return `MCM_CH_GetValue(class'MCM_Defaults'.default.ADVENT_STRENGTH_PAUSE_REGION_2, class'UIS_MCM'.default.ADVENT_STRENGTH_PAUSE_REGION_2);
}

function bool Get_ADVENT_STRENGTH_PAUSE_REGION_3()
{
	return `MCM_CH_GetValue(class'MCM_Defaults'.default.ADVENT_STRENGTH_PAUSE_REGION_3, class'UIS_MCM'.default.ADVENT_STRENGTH_PAUSE_REGION_3);
}

function bool Get_ADVENT_STRENGTH_PAUSE_REGION_4()
{
	return `MCM_CH_GetValue(class'MCM_Defaults'.default.ADVENT_STRENGTH_PAUSE_REGION_4, class'UIS_MCM'.default.ADVENT_STRENGTH_PAUSE_REGION_4);
}

function bool Get_ADVENT_STRENGTH_PAUSE_REGION_5()
{
	return `MCM_CH_GetValue(class'MCM_Defaults'.default.ADVENT_STRENGTH_PAUSE_REGION_5, class'UIS_MCM'.default.ADVENT_STRENGTH_PAUSE_REGION_5);
}

function bool Get_ADVENT_STRENGTH_PAUSE_REGION_6()
{
	return `MCM_CH_GetValue(class'MCM_Defaults'.default.ADVENT_STRENGTH_PAUSE_REGION_6, class'UIS_MCM'.default.ADVENT_STRENGTH_PAUSE_REGION_6);
}

function bool Get_ADVENT_STRENGTH_PAUSE_REGION_7()
{
	return `MCM_CH_GetValue(class'MCM_Defaults'.default.ADVENT_STRENGTH_PAUSE_REGION_7, class'UIS_MCM'.default.ADVENT_STRENGTH_PAUSE_REGION_7);
}

function bool Get_ADVENT_STRENGTH_PAUSE_REGION_8()
{
	return `MCM_CH_GetValue(class'MCM_Defaults'.default.ADVENT_STRENGTH_PAUSE_REGION_8, class'UIS_MCM'.default.ADVENT_STRENGTH_PAUSE_REGION_8);
}

function bool Get_ADVENT_STRENGTH_PAUSE_REGION_9()
{
	return `MCM_CH_GetValue(class'MCM_Defaults'.default.ADVENT_STRENGTH_PAUSE_REGION_9, class'UIS_MCM'.default.ADVENT_STRENGTH_PAUSE_REGION_9);
}

function bool Get_ADVENT_STRENGTH_PAUSE_REGION_10()
{
	return `MCM_CH_GetValue(class'MCM_Defaults'.default.ADVENT_STRENGTH_PAUSE_REGION_10, class'UIS_MCM'.default.ADVENT_STRENGTH_PAUSE_REGION_10);
}

function bool Get_ADVENT_STRENGTH_PAUSE_REGION_11()
{
	return `MCM_CH_GetValue(class'MCM_Defaults'.default.ADVENT_STRENGTH_PAUSE_REGION_11, class'UIS_MCM'.default.ADVENT_STRENGTH_PAUSE_REGION_11);
}

function bool Get_ADVENT_STRENGTH_PAUSE_REGION_12()
{
	return `MCM_CH_GetValue(class'MCM_Defaults'.default.ADVENT_STRENGTH_PAUSE_REGION_12, class'UIS_MCM'.default.ADVENT_STRENGTH_PAUSE_REGION_12);
}

function bool Get_ADVENT_STRENGTH_PAUSE_REGION_13()
{
	return `MCM_CH_GetValue(class'MCM_Defaults'.default.ADVENT_STRENGTH_PAUSE_REGION_13, class'UIS_MCM'.default.ADVENT_STRENGTH_PAUSE_REGION_13);
}

function bool Get_ADVENT_STRENGTH_PAUSE_REGION_14()
{
	return `MCM_CH_GetValue(class'MCM_Defaults'.default.ADVENT_STRENGTH_PAUSE_REGION_14, class'UIS_MCM'.default.ADVENT_STRENGTH_PAUSE_REGION_14);
}

function bool Get_ADVENT_STRENGTH_PAUSE_REGION_15()
{
	return `MCM_CH_GetValue(class'MCM_Defaults'.default.ADVENT_STRENGTH_PAUSE_REGION_15, class'UIS_MCM'.default.ADVENT_STRENGTH_PAUSE_REGION_15);
}
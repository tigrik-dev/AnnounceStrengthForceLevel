class AlertWatcherActor extends Actor config(AnnounceStrengthForceLevel);

`include(AnnounceStrengthForceLevel\Src\AnnounceStrengthForceLevel\LoggerMacros.uci)
`include(AnnounceStrengthForceLevel\Src\AnnounceStrengthForceLevel\MCM_API_CfgHelpers.uci)

var localized string sAdventStrength, sForceLevel, sStengthIncreased, sForceIncreased;

var config float fPollingRate;

var array<int> CachedRegionIDs, CachedAlertLevels, CachedForceLevels;

var float TimeAccumulator, EffectivePollingRate;

var bool bInitialized;
var int LastProcessedDayStamp;

// This guarantees singleton behavior even if multiple somehow get spawned simultaneously.
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

function CheckAlertLevels()
{
    local XComGameStateHistory History;
    local XComGameState_WorldRegion Region;
    local XComGameState_WorldRegion_LWStrategyAI RegionalAI;

    local int CachedIndex, NewAlertLevel, NewForceLevel;
	local XGParamTag ParamTag;
	local string sNotify;
	local bool firstRegion;

	`TRACE_ENTRY("");

	// First run: just populate cache, don’t log anything
    if (!bInitialized)
	{
		InitializeCache();
		bInitialized = true;
		return;
	}

    History = `XCOMHISTORY;
	firstRegion = true;

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
            if (Region.HaveMadeContact() && !RegionalAI.bLiberated && NewAlertLevel > CachedAlertLevels[CachedIndex])
            {
				// Pause Geoscape if MCM options permit it
				if (Get_PAUSE_ADVENT_STRENGTH() && NewAlertLevel >= Get_MIN_ADVENT_STRENGTH_PAUSE() && ShouldPauseForRegion(class'WorldRegionLib'.static.GetRegionIndex(Region))) PauseGeoscape();

				// Don't notify if MCM option "Show notifications when ADVENT Strength increases" is unchecked
				if (!Get_NOTIFY_ADVENT_STRENGTH()) continue;

				ParamTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
				ParamTag.IntValue0 = CachedAlertLevels[CachedIndex];
				ParamTag.IntValue1 = NewAlertLevel;
				ParamTag.StrValue0 = sAdventStrength;
				ParamTag.StrValue1 = Region.GetDisplayName();
				sNotify = `XEXPAND.ExpandString(sStengthIncreased);

				CachedAlertLevels[CachedIndex] = NewAlertLevel;

				`INFO(sNotify);
				`HQPRES.Notify(sNotify, class'UIUtilities_Image'.const.EventQueue_Advent);
            }

			// Only check for Force Level increase in the first abtitrary region
			// in the base LWOTC Force Level will be the same in all regions.
			if (firstRegion && NewForceLevel > CachedForceLevels[CachedIndex])
			{
				// Pause Geoscape if MCM options permit it
				if (Get_PAUSE_FORCE_LEVEL() && NewForceLevel >= Get_MIN_FORCE_LEVEL_PAUSE()) PauseGeoscape();

				// Don't notify if MCM option "Show notifications when Force Level increases" is unchecked
				if (!Get_NOTIFY_FORCE_LEVEL()) continue;

				CachedForceLevels[CachedIndex] = NewForceLevel;

				ParamTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
				ParamTag.IntValue0 = NewForceLevel;
				ParamTag.StrValue0 = sForceLevel;
				sNotify = `XEXPAND.ExpandString(sForceIncreased);

				`INFO(sNotify);
				`HQPRES.Notify(sNotify, class'UIUtilities_Image'.const.EventQueue_Alien);
			}
			firstRegion = false;
        }
    }
	`TRACE_EXIT("");
}

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

function bool Get_NOTIFY_FORCE_LEVEL()
{
	return `MCM_CH_GetValue(class'MCM_Defaults'.default.NOTIFY_FORCE_LEVEL, class'UIS_MCM'.default.NOTIFY_FORCE_LEVEL);
}

function bool Get_PAUSE_ADVENT_STRENGTH()
{
	return `MCM_CH_GetValue(class'MCM_Defaults'.default.PAUSE_ADVENT_STRENGTH, class'UIS_MCM'.default.PAUSE_ADVENT_STRENGTH);
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
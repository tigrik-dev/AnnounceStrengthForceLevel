class AlertWatcherActor extends Actor;

`include(AnnounceStrengthForceLevel\Src\AnnounceStrengthForceLevel\LoggerMacros.uci)

var array<int> CachedRegionIDs;
var array<int> CachedAlertLevels;

var float TimeAccumulator;
var TDateTime LastCheckedGameTime;

var bool bInitialized;
var int LastProcessedDayStamp;

// This guarantees singleton behavior even if multiple somehow get spawned simultaneously.
event PostBeginPlay()
{
    local AlertWatcherActor ExistingWatcher;

	`TRACE_ENTRY("");

    super.PostBeginPlay();

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

	// Run at most once per second
    TimeAccumulator += DeltaTime;
    if (TimeAccumulator < 1.0f) return;

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
    local XComGameState_WorldRegion RegionState;
    local XComGameState_WorldRegion_LWStrategyAI RegionalAI;

    local int CachedIndex;
    local int OldValue, NewValue;

	`TRACE_ENTRY("");

	// First run: just populate cache, don’t log anything
    if (!bInitialized)
	{
		InitializeCache();
		bInitialized = true;
		return;
	}

    History = `XCOMHISTORY;

    foreach History.IterateByClassType(class'XComGameState_WorldRegion', RegionState)
    {
        RegionalAI = class'XComGameState_WorldRegion_LWStrategyAI'.static.GetRegionalAI(RegionState);

        if (RegionalAI == none) continue;

        CachedIndex = CachedRegionIDs.Find(RegionState.ObjectID);
        NewValue = RegionalAI.LocalAlertLevel;

        if (CachedIndex == INDEX_NONE)
        {
            CachedRegionIDs.AddItem(RegionState.ObjectID);
            CachedAlertLevels.AddItem(NewValue);
        }
        else
        {
            OldValue = CachedAlertLevels[CachedIndex];

            if (NewValue > OldValue)
            {
                `DEBUG("Advent Strength Increased. Region =" @ RegionState.GetDisplayName() $ ", Old =" @ OldValue $ ", New =" @ NewValue);
            }

            CachedAlertLevels[CachedIndex] = NewValue;
        }
    }
	`TRACE_EXIT("");
}

function InitializeCache()
{
    local XComGameStateHistory History;
    local XComGameState_WorldRegion RegionState;
    local XComGameState_WorldRegion_LWStrategyAI RegionalAI;

	`TRACE_ENTRY("");

    History = `XCOMHISTORY;

    CachedRegionIDs.Length = 0;
    CachedAlertLevels.Length = 0;

    foreach History.IterateByClassType(class'XComGameState_WorldRegion', RegionState)
    {
        RegionalAI = class'XComGameState_WorldRegion_LWStrategyAI'.static.GetRegionalAI(RegionState);

        if (RegionalAI == none) continue;

        CachedRegionIDs.AddItem(RegionState.ObjectID);
        CachedAlertLevels.AddItem(RegionalAI.LocalAlertLevel);
    }

	`TRACE_EXIT("AlertWatcher: Cache initialized with " $ CachedRegionIDs.Length $ " regions");
}
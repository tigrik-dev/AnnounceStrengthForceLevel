class UISL_AlertWatcher extends UIScreenListener;

`include(AnnounceStrengthForceLevel\Src\AnnounceStrengthForceLevel\LoggerMacros.uci)

event OnInit(UIScreen Screen)
{
    local AlertWatcherActor ExistingWatcher;

	`TRACE_ENTRY("");

    if (`GAME.GetGeoscape() == none) return;

    foreach `GAME.GetGeoscape().AllActors(class'AlertWatcherActor', ExistingWatcher)
    {
		`TRACE_EXIT("AlertWatcherActor already exists");
        return; // already exists
    }

    `GAME.GetGeoscape().Spawn(class'AlertWatcherActor');
	`TRACE_EXIT("");
}

// Apparently, AML will flag a conflict simply on the basis that two mods have screen listeners with the same class in their defaultproperties.ScreenClass
/*defaultproperties
{
    ScreenClass = UIStrategyMap;
}*/
/**
 * UISL_AlertWatcher
 *
 * UIScreenListener responsible for spawning and maintaining the
 * AlertWatcherActor singleton during Geoscape gameplay.
 *
 * Responsibilities:
 * - Detect Geoscape screen initialization
 * - Ensure exactly one AlertWatcherActor exists
 * - Spawn AlertWatcherActor when needed
 * - Prevent duplicate watcher actors
 *
 * @author Tigrik
 */
class UISL_AlertWatcher extends UIScreenListener;

`include(AnnounceStrengthForceLevel\Src\AnnounceStrengthForceLevel\LoggerMacros.uci)

/**
 * Called when a UI screen initializes.
 *
 * If the Geoscape exists and no AlertWatcherActor is currently active,
 * spawns a new AlertWatcherActor singleton instance.
 *
 * @param Screen    UI screen being initialized
 */
event OnInit(UIScreen Screen)
{
    local AlertWatcherActor ExistingWatcher;

    if (`GAME.GetGeoscape() == none) return;

    foreach `GAME.GetGeoscape().AllActors(class'AlertWatcherActor', ExistingWatcher)
    {
		`TRACE_EXIT("AlertWatcherActor already exists");
        return; // already exists
    }

    `GAME.GetGeoscape().Spawn(class'AlertWatcherActor');
}

// Apparently, AML will flag a conflict simply on the basis that two mods have screen listeners with the same class in their defaultproperties.ScreenClass
/*defaultproperties
{
    ScreenClass = UIStrategyMap;
}*/
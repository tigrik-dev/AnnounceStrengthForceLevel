class UISL_MCM extends UIScreenListener;

event OnInit(UIScreen Screen)
{
	local UIS_MCM MCMScreen;

	if (MCM_API(Screen) == none) return;

	if (ScreenClass == none) ScreenClass = Screen.Class;

	MCMScreen = new class'UIS_MCM';
	MCMScreen.OnInit(Screen);
}
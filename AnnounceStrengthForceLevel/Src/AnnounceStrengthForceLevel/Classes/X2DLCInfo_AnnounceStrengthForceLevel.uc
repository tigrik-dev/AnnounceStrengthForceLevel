class X2DLCInfo_AnnounceStrengthForceLevel extends X2DownloadableContentInfo;

`include(AnnounceStrengthForceLevel\Src\AnnounceStrengthForceLevel\LoggerMacros.uci)

static event OnPostTemplatesCreated()
{
	`TRACE_ENTRY("");
	`INFO(class'Version'.static.GetDisplayString());
	`TRACE_EXIT("");
}
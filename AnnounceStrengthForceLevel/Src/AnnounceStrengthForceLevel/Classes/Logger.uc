/**
 * Logger
 *
 * Centralized logging utility.
 *
 * Provides a lightweight logging framework inspired by log4j-style levels,
 * allowing developers to emit TRACE, DEBUG, INFO, WARN, and ERROR messages
 * with consistent formatting and optional verbosity control via config.
 *
 * Responsibilities:
 * - Provide static logging functions for different severity levels
 * - Respect config-driven toggles for TRACE, DEBUG, and INFO verbosity
 *
 * Configuration:
 * - bEnableInfo:  Enables INFO-level logging for general flow messages
 * - bEnableDebug: Enables DEBUG-level logging for development insights
 * - bEnableTrace: Enables verbose TRACE-level logging (very noisy)
 *
 * Usage:
 * - Intended to be used via macros (e.g. `TRACE, `DEBUG, etc.)
 * 
 * @author Tigrik
 */
class Logger extends Object config(AnnounceStrengthForceLevel_Logger);

var config bool bEnableInfo;
var config bool bEnableDebug;
var config bool bEnableTrace;

static function LogWithLevel(string Level, String Msg)
{
    `LOG(Level @ Msg,, 'AnnounceStrengthForceLevel');
}

static function Trace(string Msg)
{
    if (!default.bEnableTrace)
        return;

    LogWithLevel("[TRACE]", Msg);
}

static function Debug(string Msg)
{
    if (!default.bEnableDebug)
        return;

    LogWithLevel("[DEBUG]", Msg);
}

static function Info(string Msg)
{
    if (!default.bEnableInfo)
        return;

	// Add an extra space to align with the 5-symbol log levels
    LogWithLevel("[INFO] ", Msg);
}

static function Warn(string Msg)
{
	// Add an extra space to align with the 5-symbol log levels
    LogWithLevel("[WARN] ", Msg);
}

static function Error(string Msg)
{
    LogWithLevel("[ERROR]", Msg);
}

static function Test(string Msg)
{
	// Add an extra space to align with the 5-symbol log levels
    LogWithLevel("[TEST] ", Msg);
}

/**
 * PadFuncName
 *
 * Pads a function name to improve alignment in log messages.
 * The function name is padded with spaces to the nearest step width,
 * starting from a minimum width, so that logs are easier to read.
 *
 * Example behavior (step = 4, minWidth = 18):
 *   "GetAvgGraze"              ? padded to 18 chars
 *   "GetExpectedDamage"        ? padded to 18 chars
 *   "GetExpectedDamageString"  ? padded to 26 chars
 *   "SuperLongFunctionNameHere"? padded to 34 chars
 *
 * @param FuncName string - The function name to pad
 * @return string - Padded function name
 */
static function string PadFuncName(string FuncName)
{
    local int Length, Width, Step;
    
    Length = Len(FuncName);
    Step = 4;       // step size for flexible padding
    Width = 18;     // minimum width
    
    // Increase width until it fits the function name
    while (Width < Length)
        Width += Step;
    
    // Pad with spaces to reach target width
    while (Len(FuncName) < Width)
        FuncName = FuncName $ " ";
    
    return FuncName;
}
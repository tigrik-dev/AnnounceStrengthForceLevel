/**
 * Version
 *
 * Versioning utility
 *
 * Responsibilities:
 * - Store current mod version (Major, Minor, Patch)
 * - Provide formatted version string
 * - Provide comparable numeric version representation
 * - Allow version comparison checks for compatibility logic
 *
 * Versioning follows Semantic Versioning (SemVer):
 * MAJOR.MINOR.PATCH
 *
 * Notes:
 * - MAJOR: breaking changes
 * - MINOR: new features (backwards compatible)
 * - PATCH: bug fixes / small tweaks
 * 
 * @author Tigrik
 */
class Version extends Object;

var int MajorVersion;
var int MinorVersion;
var int PatchVersion;

/**
 * Returns version string in format "Major.Minor.Patch"
 *
 * @return string Version string
 */
static function string GetVersionString()
{
    return default.MajorVersion $ "." $ default.MinorVersion $ "." $ default.PatchVersion;
}

/**
 * Returns version as a comparable integer.
 *
 * Format: MMmmpppppp
 * - MM: Major (hundreds of millions)
 * - mm: Minor (millions)
 * - pp: Patch (ones)
 *
 * Allows easy numeric comparison between versions.
 *
 * @param Major   (out) Current major version
 * @param Minor   (out) Current minor version
 * @param Patch   (out) Current patch version
 *
 * @return int Comparable version number
 */
static function int GetVersionNumber(optional out int Major, optional out int Minor, optional out int Patch)
{
    Major = default.MajorVersion;
    Minor = default.MinorVersion;
    Patch = default.PatchVersion;

    return (default.MajorVersion * 100000000)
         + (default.MinorVersion * 1000000)
         + default.PatchVersion;
}

/**
 * Checks if current version is at least the specified version.
 *
 * Useful for:
 * - Save compatibility checks
 * - Conditional feature logic
 * - Cross-mod compatibility
 *
 * @param Major Required major version
 * @param Minor Required minor version
 * @param Patch Required patch version
 *
 * @return bool True if current version >= provided version
 */
static function bool IsAtLeast(int Major, int Minor, int Patch)
{
    local int CurMajor, CurMinor, CurPatch;

    class'Version'.static.GetVersionNumber(CurMajor, CurMinor, CurPatch);

    return
        (CurMajor > Major) ||
        (CurMajor == Major && CurMinor > Minor) ||
        (CurMajor == Major && CurMinor == Minor && CurPatch >= Patch);
}

/**
 * Checks if current version is exactly equal to the specified version.
 *
 * @param Major Version major
 * @param Minor Version minor
 * @param Patch Version patch
 *
 * @return bool True if versions match exactly
 */
static function bool IsVersion(int Major, int Minor, int Patch)
{
    return default.MajorVersion == Major
        && default.MinorVersion == Minor
        && default.PatchVersion == Patch;
}

/**
 * Returns version string in format "vMajor.Minor.Patch"
 *
 * Example: "v0.1.0"
 *
 * @return string Version string with "v" prefix
 */
static function string GetVersionStringWithPrefix()
{
    return "v" $ GetVersionString();
}

/**
 * Returns a user-friendly display string for UI or logs.
 *
 * Example: "Announce Advent Strength version: 0.1.0"
 *
 * @return string Display string
 */
static function string GetDisplayString()
{
    return "Announce Advent Strength version:" @ GetVersionString();
}

defaultproperties
{
    MajorVersion = 0
    MinorVersion = 1
    PatchVersion = 0
}
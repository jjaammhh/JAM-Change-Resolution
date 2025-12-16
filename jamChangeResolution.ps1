<#
.SYNOPSIS
    Sets screen resolution, HDR state, and DPI Scale using native Win32 APIs.
    
.DESCRIPTION
    This script forces a specific resolution, HDR state (On/Off), and DPI Scaling (e.g., 100%, 125%).
    It uses a specific execution order to override Windows' internal 
    profile memory, ensuring the target settings are applied regardless 
    of the previous state.

.PARAMETER Width
    Target horizontal resolution (e.g., 1920, 2560, 3840). Default: 1920.

.PARAMETER Height
    Target vertical resolution (e.g., 1080, 1440, 2160). Default: 1080.

.PARAMETER Frequency
    Target refresh rate in Hz (e.g., 60, 120, 144). Default: 60.

.PARAMETER HDR
    Target HDR state. Accepts "true", "1", "On" or "false", "0", "Off". Default: "false".

.PARAMETER Scale
    Target DPI scaling percentage (e.g., 100, 125, 150, 175). 
    If omitted or 0, the current scale is kept unchanged.

.PARAMETER WaitTime
    Time in milliseconds to wait between switching HDR and applying resolution.
    Default: 100.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File jamChangeResolution.ps1 -Width 3840 -Height 2160 -HDR On -Scale 150

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File jamChangeResolution.ps1 -Width 1920 -Height 1080 -HDR Off -Scale 100

#>

param(
    [int]$Width = 1920,
    [int]$Height = 1080,
    [int]$Frequency = 60,
    [string]$HDR = "false",
    [int]$Scale = 0,
    [int]$WaitTime = 100
)

# Parse HDR argument to boolean
$HDRBool = $HDR -eq "true" -or $HDR -eq "1" -or $HDR -eq "yes" -or $HDR -eq "On"

# --- C# BLOCK (Structures & API) ---
$code = @'
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;

public class DisplayTools {
    
    // --- RESOLUTION STRUCTURES ---
    [StructLayout(LayoutKind.Sequential)]
    public struct DEVMODE {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string dmDeviceName;
        public short dmSpecVersion;
        public short dmDriverVersion;
        public short dmSize;
        public short dmDriverExtra;
        public int dmFields;
        public int dmPositionX;
        public int dmPositionY;
        public int dmDisplayOrientation;
        public int dmDisplayFixedOutput;
        public short dmColor;
        public short dmDuplex;
        public short dmYResolution;
        public short dmTTOption;
        public short dmCollate;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string dmFormName;
        public short dmLogPixels;
        public int dmBitsPerPel;
        public int dmPelsWidth;
        public int dmPelsHeight;
        public int dmDisplayFlags;
        public int dmDisplayFrequency;
        public int dmICMMethod;
        public int dmICMIntent;
        public int dmMediaType;
        public int dmDitherType;
        public int dmReserved1;
        public int dmReserved2;
        public int dmPanningWidth;
        public int dmPanningHeight;
    }

    [DllImport("user32.dll")]
    public static extern int ChangeDisplaySettings(ref DEVMODE devMode, int flags);
    
    [DllImport("user32.dll")]
    public static extern bool EnumDisplaySettings(string deviceName, int modeNum, ref DEVMODE devMode);

    // --- DISPLAY CONFIG API (HDR & DPI) ---
    public const uint QDC_ONLY_ACTIVE_PATHS = 0x00000002;
    public const uint DISPLAYCONFIG_DEVICE_INFO_SET_ADVANCED_COLOR_STATE = 10;
    public const int DISPLAYCONFIG_DEVICE_INFO_GET_DPI_SCALE = -3; // Undocumented
    public const int DISPLAYCONFIG_DEVICE_INFO_SET_DPI_SCALE = -4; // Undocumented
    
    [StructLayout(LayoutKind.Sequential)]
    public struct LUID { public uint LowPart; public int HighPart; }

    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    public struct DISPLAYCONFIG_DEVICE_INFO_HEADER {
        public uint type; public uint size; public LUID adapterId; public uint id;
    }

    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    public struct DISPLAYCONFIG_SET_ADVANCED_COLOR_STATE {
        public DISPLAYCONFIG_DEVICE_INFO_HEADER header;
        public uint value; 
    }

    // DPI GET Structure (32 bytes)
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    public struct DISPLAYCONFIG_SOURCE_DPI_SCALE_GET {
        public DISPLAYCONFIG_DEVICE_INFO_HEADER header;
        public int minScaleRel;
        public int curScaleRel;
        public int maxScaleRel;
    }

    // DPI SET Structure (24 bytes)
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    public struct DISPLAYCONFIG_SOURCE_DPI_SCALE_SET {
        public DISPLAYCONFIG_DEVICE_INFO_HEADER header;
        public int scaleRel;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct DISPLAYCONFIG_PATH_INFO {
        public DISPLAYCONFIG_PATH_SOURCE_INFO sourceInfo;
        public DISPLAYCONFIG_PATH_TARGET_INFO targetInfo;
        public uint flags;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct DISPLAYCONFIG_PATH_SOURCE_INFO {
        public LUID adapterId; public uint id; public uint modeInfoIdx; public uint statusFlags;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct DISPLAYCONFIG_PATH_TARGET_INFO {
        public LUID adapterId; public uint id; public uint modeInfoIdx; 
        public int outputTechnology; public int rotation; public int scaling; 
        public int refreshRateNumerator; public int refreshRateDenominator; 
        public int scanLineOrdering; public int targetAvailable; public int statusFlags;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct DISPLAYCONFIG_MODE_INFO {
        public uint infoType; public uint id; public LUID adapterId; public DISPLAYCONFIG_MODE_INFO_UNION modeInfo;
    }

    [StructLayout(LayoutKind.Explicit)]
    public struct DISPLAYCONFIG_MODE_INFO_UNION {
        [FieldOffset(0)] public DISPLAYCONFIG_TARGET_MODE targetMode;
        [FieldOffset(0)] public DISPLAYCONFIG_SOURCE_MODE sourceMode;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct DISPLAYCONFIG_TARGET_MODE {
        public ulong pixelRate; public uint hSyncFreq; public uint vSyncFreq; 
        public uint activeSize; public uint totalSize; public uint videoStandard;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct DISPLAYCONFIG_SOURCE_MODE {
        public uint width; public uint height; public uint pixelFormat; 
        public uint positionX; public uint positionY;
    }

    [DllImport("user32.dll")]
    public static extern int GetDisplayConfigBufferSizes(uint flags, out uint numPathArrayElements, out uint numModeInfoArrayElements);

    [DllImport("user32.dll")]
    public static extern int QueryDisplayConfig(uint flags, ref uint numPathArrayElements, [Out] DISPLAYCONFIG_PATH_INFO[] pathArray, ref uint numModeInfoArrayElements, [Out] DISPLAYCONFIG_MODE_INFO[] modeInfoArray, IntPtr currentTopologyId);

    [DllImport("user32.dll")]
    public static extern int DisplayConfigSetDeviceInfo(ref DISPLAYCONFIG_SET_ADVANCED_COLOR_STATE setPacket);

    [DllImport("user32.dll")]
    public static extern int DisplayConfigSetDeviceInfo(ref DISPLAYCONFIG_SOURCE_DPI_SCALE_SET setPacket);
    
    [DllImport("user32.dll")]
    public static extern int DisplayConfigGetDeviceInfo(ref DISPLAYCONFIG_SOURCE_DPI_SCALE_GET requestPacket);

    // --- HELPER METHODS ---

    public static void SetHDR(bool enable) {
        uint numPaths = 0, numModes = 0;
        int ret = GetDisplayConfigBufferSizes(QDC_ONLY_ACTIVE_PATHS, out numPaths, out numModes);
        if (ret != 0) throw new Exception("GetDisplayConfigBufferSizes failed: " + ret);

        var paths = new DISPLAYCONFIG_PATH_INFO[numPaths];
        var modes = new DISPLAYCONFIG_MODE_INFO[numModes];
        ret = QueryDisplayConfig(QDC_ONLY_ACTIVE_PATHS, ref numPaths, paths, ref numModes, modes, IntPtr.Zero);
        if (ret != 0) throw new Exception("QueryDisplayConfig failed: " + ret);

        for (int i = 0; i < numPaths; i++) {
            var packet = new DISPLAYCONFIG_SET_ADVANCED_COLOR_STATE();
            packet.header.type = DISPLAYCONFIG_DEVICE_INFO_SET_ADVANCED_COLOR_STATE;
            packet.header.size = (uint)Marshal.SizeOf(typeof(DISPLAYCONFIG_SET_ADVANCED_COLOR_STATE));
            // HDR is set on the TARGET
            packet.header.adapterId = paths[i].targetInfo.adapterId;
            packet.header.id = paths[i].targetInfo.id;
            packet.value = enable ? 1u : 0u;
            DisplayConfigSetDeviceInfo(ref packet);
        }
    }

    public static void SetDPI(int targetScalePercent) {
        if (targetScalePercent <= 0) return;

        // Common scaling steps in Windows
        int[] dpiVals = { 100, 125, 150, 175, 200, 225, 250, 300, 350, 400, 450, 500 };
        
        // Find index of desired scale
        int targetIdx = -1;
        for(int i=0; i<dpiVals.Length; i++) {
            if (dpiVals[i] == targetScalePercent) {
                targetIdx = i;
                break;
            }
        }
        if (targetIdx == -1) {
            Console.WriteLine("Warning: Scale " + targetScalePercent + "% is not a standard step. Trying closest match.");
            // Simple logic: find closest
            int minDiff = 9999;
            for(int i=0; i<dpiVals.Length; i++) {
                int diff = Math.Abs(dpiVals[i] - targetScalePercent);
                if (diff < minDiff) {
                    minDiff = diff;
                    targetIdx = i;
                }
            }
        }

        uint numPaths = 0, numModes = 0;
        int ret = GetDisplayConfigBufferSizes(QDC_ONLY_ACTIVE_PATHS, out numPaths, out numModes);
        if (ret != 0) return;

        var paths = new DISPLAYCONFIG_PATH_INFO[numPaths];
        var modes = new DISPLAYCONFIG_MODE_INFO[numModes];
        ret = QueryDisplayConfig(QDC_ONLY_ACTIVE_PATHS, ref numPaths, paths, ref numModes, modes, IntPtr.Zero);
        if (ret != 0) return;

        for (int i = 0; i < numPaths; i++) {
            // DPI is set on the SOURCE
            var request = new DISPLAYCONFIG_SOURCE_DPI_SCALE_GET();
            
            // FIX: Use unchecked to force casting of negative constants to uint
            request.header.type = unchecked((uint)DISPLAYCONFIG_DEVICE_INFO_GET_DPI_SCALE);
            
            request.header.size = (uint)Marshal.SizeOf(typeof(DISPLAYCONFIG_SOURCE_DPI_SCALE_GET));
            request.header.adapterId = paths[i].sourceInfo.adapterId;
            request.header.id = paths[i].sourceInfo.id;

            if (DisplayConfigGetDeviceInfo(ref request) == 0) { // Success
                int minAbs = Math.Abs(request.minScaleRel);
                int valToSet = targetIdx - minAbs;

                if (valToSet < request.minScaleRel) valToSet = request.minScaleRel;
                if (valToSet > request.maxScaleRel) valToSet = request.maxScaleRel;

                var setPacket = new DISPLAYCONFIG_SOURCE_DPI_SCALE_SET();
                
                // FIX: Use unchecked here as well
                setPacket.header.type = unchecked((uint)DISPLAYCONFIG_DEVICE_INFO_SET_DPI_SCALE);
                
                setPacket.header.size = (uint)Marshal.SizeOf(typeof(DISPLAYCONFIG_SOURCE_DPI_SCALE_SET));
                setPacket.header.adapterId = paths[i].sourceInfo.adapterId;
                setPacket.header.id = paths[i].sourceInfo.id;
                setPacket.scaleRel = valToSet;

                int setRes = DisplayConfigSetDeviceInfo(ref setPacket);
                if (setRes == 0) {
                    Console.WriteLine("DPI Scale set to " + dpiVals[targetIdx] + "% (Step: " + valToSet + ")");
                } else {
                    Console.WriteLine("Failed to set DPI. Error: " + setRes);
                }
            }
        }
    }
}
'@

try { 
    Add-Type -TypeDefinition $code -Language CSharp 
} catch { 
    if ($_.Exception.Message -notmatch "already exists") { throw } 
}

# --- HELPER FUNCTIONS ---

function Set-ScreenResolution {
    param([int]$w, [int]$h, [int]$freq)
    
    $devmode = New-Object DisplayTools+DEVMODE
    $devmode.dmSize = [System.Runtime.InteropServices.Marshal]::SizeOf($devmode)
    
    [DisplayTools]::EnumDisplaySettings($null, -1, [ref]$devmode) | Out-Null
    
    $devmode.dmPelsWidth = $w
    $devmode.dmPelsHeight = $h
    $devmode.dmDisplayFrequency = $freq
    $devmode.dmBitsPerPel = 32
    $devmode.dmFields = 0x1C0000 
    
    $res = [DisplayTools]::ChangeDisplaySettings([ref]$devmode, 0)
    if ($res -eq 0) {
        Write-Host "Resolution set to: ${w}x${h} @ ${freq}Hz" -ForegroundColor Green
    } else {
        Write-Host "Error changing resolution. Code: $res" -ForegroundColor Red
    }
}

function Set-HDRState {
    param([bool]$state)
    Write-Host "Setting HDR to: $state" -ForegroundColor Cyan
    try { [DisplayTools]::SetHDR($state) } catch { Write-Error "HDR Error: $_" }
}

function Set-DPI {
    param([int]$s)
    if ($s -gt 0) {
        Write-Host "Setting DPI Scale to: $s%" -ForegroundColor Magenta
        try { [DisplayTools]::SetDPI($s) } catch { Write-Error "DPI Error: $_" }
    }
}

# --- MAIN EXECUTION LOGIC ---

# 1. HDR (Loads profile)
Set-HDRState -state $HDRBool

# 2. Critical Wait
Start-Sleep -Milliseconds $WaitTime

# 3. Resolution (Overrides profile)
Set-ScreenResolution -w $Width -h $Height -freq $Frequency

# 4. DPI Scale (Applies on top)
if ($Scale -gt 0) {
    Set-DPI -s $Scale
}

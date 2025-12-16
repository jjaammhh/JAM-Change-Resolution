# Windows Native Display Controller 🖥️

A powerful, **dependency-free** PowerShell script to programmatically control Screen Resolution, Refresh Rate, HDR status, and DPI Scaling on Windows.

> **Zero Dependencies:** This script uses **100% native Win32 APIs** (via C# P/Invoke embedded in PowerShell). It does **NOT** require external tools like QRes, NIRCmd, or DisplaySwitch. It works out-of-the-box on any modern Windows 10/11 installation.

## 🚀 Features

*   **Change Resolution & Refresh Rate**: Force specific width, height, and Hz.
*   **Control HDR**: Natively toggle High Dynamic Range (On/Off) using undocumented Windows APIs.
*   **Set DPI Scaling**: Change interface scaling (e.g., 100%, 125%, 150%) **on the fly** without signing out.
*   **Profile Memory Override**: Intelligent execution logic defeats Windows' tendency to revert resolutions when switching HDR modes.
*   **Portable**: Single `.ps1` file. No installation required.

## 📋 Requirements

*   Windows 10 or Windows 11.
*   PowerShell 5.1 or Core (standard on Windows).
*   *Administrator privileges are recommended to ensure API access, though often not strictly required depending on the specific setting changed.*

## ⚙️ Usage

Run the script via a PowerShell terminal.

powershell -ExecutionPolicy Bypass -File jamChangeResolution.ps1 [Parameters]

text

### Parameters

| Parameter    | Type   | Default | Description                                                                 |
| :----------- | :----- | :------ | :-------------------------------------------------------------------------- |
| `-Width`     | Int    | `1920`  | Target horizontal pixel count.                                              |
| `-Height`    | Int    | `1080`  | Target vertical pixel count.                                                |
| `-Frequency` | Int    | `60`    | Target refresh rate in Hz.                                                  |
| `-HDR`       | String | `false` | Set HDR state. Accepts: `On`, `Off`, `true`, `false`, `1`, `0`.             |
| `-Scale`     | Int    | `0`     | Target DPI Scale % (e.g., `100`, `125`, `150`). If `0`, scale is unchanged. |
| `-WaitTime`  | Int    | `100`   | Pause (ms) between HDR switch and resolution change.                        |

---

## 💡 Examples

### 1. Standard 1080p Gaming (SDR)
Set resolution to 1920x1080 at 144Hz, ensure HDR is OFF, and set scaling to 100% (no zoom).
.\jamChangeResolution.ps1 -Width 1920 -Height 1080 -Frequency 144 -HDR Off -Scale 100

text

### 2. 4K HDR Media Mode
Set resolution to 4K (3840x2160) at 60Hz, turn HDR ON, and increase text size to 150%.
.\jamChangeResolution.ps1 -Width 3840 -Height 2160 -Frequency 60 -HDR On -Scale 150

text

### 3. High-Res Productivity (No HDR)
Set an ultrawide resolution with a slight scale increase for readability.
.\jamChangeResolution.ps1 -Width 3440 -Height 1440 -Frequency 100 -HDR Off -Scale 125

text

### 4. Just Toggle HDR (Keep Resolution)
If you only want to force HDR On (parameters default to 1920x1080, so be careful if that's not your native res).
*Tip: It is best to always specify your target resolution.*
.\jamChangeResolution.ps1 -HDR On

text

### 5. Fix "Stuck" Resolution
If Windows constantly reverts your resolution when toggling HDR, increase the wait time to allow the driver to settle.
.\jamChangeResolution.ps1 -Width 2560 -Height 1440 -HDR On -WaitTime 500

text

---

## 🔧 How It Works

Windows stores separate resolution profiles for SDR and HDR modes. Often, switching HDR on will cause Windows to revert to the "last known" HDR resolution, ignoring your current settings.

This script solves this by enforcing a strict **Order of Operations**:
1.  **Switch HDR State** (Triggering Windows profile load).
2.  **Critical Wait** (Wait for the driver to finish the mode switch).
3.  **Force Resolution** (Override whatever profile Windows just loaded).
4.  **Apply DPI Scale** (Set the interface scaling on top of the final resolution).

This logic guarantees your desired state is achieved every time.

## 📝 License

Open Source. Feel free to modify and distribute.

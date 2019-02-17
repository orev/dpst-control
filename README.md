# DPST-Control
Easily disable/enable Intel&reg; *Display Power Saving Technology* (DPST)

## Introduction

Intel&reg; *Display Power Saving Technology* (DPST), sometimes called "adaptive brightness", is a feature of some Intel&reg; graphics chips that automatically adjusts the screen brightness based on what is shown on the screen.

It is notably used on the Microsoft Surface line of products, as well as many others, and is the source of many complaints about display quality when systems are used in low-light settings.

`DPST-Control` is a command-line tool that allows one to easily disable or enable this feature.  Based on the great work done here:

* [https://mikebattistablog.wordpress.com/2016/05/27/disable-intel-dpst-on-sp4/](https://mikebattistablog.wordpress.com/2016/05/27/disable-intel-dpst-on-sp4/)

`DPST-Control` has been tested on Windows 10 with all recent patches (as of ~ Jan 2019).  It may not work on older versions of Windows.


## Usage

Each command does only one thing, and there is no GUI interface. To use:
1. Download and unzip. Does not have an installer
2. Select file
2. Right-click, Select: "Run as Administrator"
3. Enter administrator password if prompted
4. Reboot

:warning: **MUST RUN AS ADMINISTRATOR** :warning:

To check the status of DPST:
* `get-status.bat`

To disable DPST:
* `disable-dpst.bat`

To enable DPST:
* `enable-dpst.bat`

Typically DPST only needs to be disabled/enabled one time, however it may need to be re-run after major Windows updates or Intel&reg; graphics driver updates.


## Method of Operation

`DPST-Control` locates and reads the value of `FeatureTestControl` in the registry, and isolates the bit that represents the DPST feature.

When changing the setting, only the DPST bit is updated; other bits are not altered.


### Compared with Other Methods

A common method of disabling this feature is to replace a registry value with another (such as replacing `9240` with `9250`).  This only works correctly if the value matches what's expected before the change (e.g. `9240`).  If the original value does not match, it means other feature bits have been altered, possibly through the control panel or other driver settings.  In such a case, changing the value to `9250` would reset/overwrite those other settings.

One could also use the calculator in programmer mode to calculate the value by manually changing the bit.  `DPST-Control` does the same thing automatically.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.


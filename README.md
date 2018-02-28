# OBS Settings for Bitrate Calculator

[OBS Lua Script](https://obsproject.com/docs/scripting.html) to calculate best resolution or frame rate for a target bitrate.

## Usage

- Select an optimization target to have that value calculated based on the others.
- Bitrate, Resolution, and FPS should be initialized from OBS, you may need to use *Capture OBS Settings* as they are not necessarily accurate at startup.
- When editing text controls, you must press *Refresh* to updated calculated fields.

No changes are made to OBS settings. While I have found a way to update the runtime OBS video configuration, I do not know of any way to persistently change OBS settings.

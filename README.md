# OBS Bitrate Settings Calculator

[OBS Lua Script](https://obsproject.com/docs/scripting.html) to calculate best resolution or frame rate for a target bitrate. I use it when changing from high motion to high detail, or trying to figure out what I can stream at on bad internet days.

## Usage

- Select an optimization target to have that value calculated based on the others.
- Bitrate, Resolution, and FPS should be initialized from OBS, you may need to use *Capture OBS Settings* as they are not necessarily accurate at startup.
- When editing text controls, you must press *Refresh* to updated calculated fields.

No changes are made to OBS settings. While I have found a way to update the runtime OBS video configuration, I do not know of any way to persistently change OBS settings.

## Notes

MilliBits Per Pixel is used instead of the more traditional Bits Per Pixel because OBS float controls only display two decimal points.

Refresh button is a limitation of OBS properties, possibly only in the scripting interface. Triggering a refresh from a text control modified handler causes the control to lose focus on each character.
Partly based on [google sheet](https://docs.google.com/spreadsheets/d/1Vm0_8BQGNxKcowK5RwTgiqQisR4mVblbWvl-N4A-lDM/edit#gid=0), which includes a lot of additional information about choosing video settings.

As always experiment, I was pretty happy with 720p30 when I could reliably get over 2kbps, which is nominally only 75mbpp.

Collection of my personalized mpv scripts and configuration.
Can be cloned directly in `~/.config/mpv` directory.

Includes modified and customized scripts by other authors.

Here is the list of included scripts with short descriptions and customizations.
Links to original scripts are included.
A script was written from scratch if there is no link.

## scroll-list

Original: https://github.com/CogentRedTester/mpv-scroll-list

Changes:
- Supports HOME and END keys to quickly jump to the start or the end of a list

## boss

Boss key.
Pauses playback and minimizes the window on ESCAPE.

## chapter-list

Original: https://github.com/CogentRedTester/mpv-scroll-list/blob/master/examples/chapter-list.lua

Changes:
- Initially selects the current chapter instead of the first one on list open

## clock

Shows system clock in bottom right corner (position is configurable).
Can be toggled on/off with `F12` (configurable).

## guess-media-title

Uses [guessit](https://github.com/guessit-io/guessit) to detect media title by filename.
Upon detection, sets `force-media-title` variable and shows the detected title on screen.

Useful for getting cleaner screenshot file names.

Requires `guessit` to be installed and accessible as `guessit` command.

## load-profiles

This script is used to load platform-dependent profiles.
One should specify profiles to load in `script-opts/load-profiles.conf` file in the following form:

```
profiles=one,two,three
```

## pause-indicator

Original: https://github.com/oltodosel/mpv-scripts/blob/master/pause-indicator.lua

Changes:
- Pause icon is now less obtrusive and is placed in top right corner.

## recent

Original: https://github.com/hacel/recent

## remember-props

When a property changes, it saves it to restore it on next start.
Saved values are not file-specific.
List of properties to save is configured in `script-opts/remember-props.conf` file:

```
props=one,two,three
```

## restore-subtitles

Saves selected subtitle tracks to `saved-subs.json` file in mpv directory and restores them whenever file is loaded.
It is required because mpv does not remember selected subtitles (at least secondary subtitle tracks).
It also stores subtitle visibility state.

## slicing-copy

Cut video segment into a new file with ffmpeg.

Original: https://github.com/snylonue/mpv_slicing_copy/blob/master/slicing_copy.lua

Changes:
- uses `media-title` for generated filenames instead of video file name
- not fast cutting like original script (using `copy` as a codec for ffmpeg), re-encodes the video each time to avoid problems with keyframes.

## sub-search

Searching for text inside subtitles.

Original: https://github.com/kelciour/mpv-scripts/blob/master/sub-search.lua

Changes:
- Searches in a subtitle file active as a primary subtitle instead of attempting to find subtitle files matching video name
- Outputs all search results in OSD list instead of jumping between them with a hotkey
- Supports searching unicode text (subtitles should be encoded as utf8, please re-encode your subtitles if you get no results searching for unicode text)
- Embedded console replaced with more recent variant from mpv sources (to support unicode input)

Requires `script-modules/utf8` repository, `script-modules/scroll-list.lua` and `script-modules/input-console.lua` to work.

You can clone `script-modules/utf8` repository with the following command (assuming you are in mpv config directory): `git clone git@github.com:Stepets/utf8.lua.git script-modules/utf8`

## toggle-osc

Allows toggling osc on/off with a hotkey.
Bound to `TAB` and single right mouse button click in `input.conf`.

## track-menu

Shows a navigable menu with list of chapters for the current video.

Original: https://github.com/dyphire/mpv-scripts/blob/main/track-menu.lua

Changes:
- Supports selecting secondary subtitle track

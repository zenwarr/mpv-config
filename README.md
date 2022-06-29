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

## pause-indicator

Original: https://github.com/oltodosel/mpv-scripts/blob/master/pause-indicator.lua

Changes:
- Pause icon is now less obtrusive and is placed in top right corner.

## restore-subtitles

Saves selected subtitle tracks to `saved-subs.json` file in mpv directory and restores them whenever file is loaded.
It is required because mpv does not remember selected subtitles (at least secondary subtitle tracks).

## slicing-copy

Quickly cut video segment into a new file with ffmpeg.

Original: https://github.com/snylonue/mpv_slicing_copy/blob/master/slicing_copy.lua

## sub-search

Searching for text inside subtitles.

Original: https://github.com/kelciour/mpv-scripts/blob/master/sub-search.lua

Changes:
- Searches in a subtitle file active as a primary subtitle instead of attempting to find subtitle files matching video name
- Outputs all search results in OSD list instead of jumping between them with a hotkey

## track-menu

Shows a navigable menu with list of chapters for the current video.

Original: https://github.com/dyphire/mpv-scripts/blob/main/track-menu.lua

Changes:
- Supports selecting secondary subtitle track

Collection of my personalized mpv scripts and configuration.
Can be cloned directly in `~/.config/mpv` directory.

Includes modified and customized scripts by other authors.

Here is the list of included scripts with short descriptions and customizations.
Links to original scripts are included.
A script was written from scratch if there is no link.

## scroll-list

Original: https://github.com/CogentRedTester/mpv-scroll-list

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
- Shows hourglass icon when buffering or seeking.

You can configure the script using the following options in `script-opts/pause_indicator.conf`:

```
# position of the icon, first word is horizontal alignment, second is vertical (you can also use `center` shorthand for `center-center`)
position=bottom-right

# font size of the icon
size=50

# whether to show hourglass icon when buffering or seeking
show_hourglass=no
```

## recent

Original: https://github.com/hacel/recent

## remember-props

When a property changes, it saves it to restore on next start.
Saved values are not file-specific.
List of properties to save is configured in `script-opts/remember-props.conf` file:

```
props=one,two,three
```

## restore-subtitles

Saves selected subtitle tracks to `saved-subs.json` file in mpv directory and restores them whenever file is loaded.
Differs from `watch-later`-saved data in that it saves secondary subtitles too (and uses subtitle file paths instead of ids).
It also stores subtitle visibility state for a secondary subtitles too.

## russian-layout-bindings

As mpv does not natively support shortcuts independent of the keyboard layout (https://github.com/mpv-player/mpv/issues/351), this script tries to workaround this issue for some limited cases with russian (йцукен) keyboard layout.
Upon startup, it takes currently active bindings from `input-bindings` property and duplicates them for the russian layout.
You can adapt the script for your preferred layout, but it won't (of course) work for layouts sharing unicode characters with the english layout.

Known issues:
- When bindings are defined in `input.conf`, mpv determines by the attached command whether this binding should be repeatable or not.
  But when defining a binding from inside a script, the script should decide whether the binding should be repeatable.
  And mpv does not give any information on whether a binding was detected to be repeatable, so we have no easy way to determine this.
  So this script uses a quick and dirty solution: it just checks if the command has `repeatable` word in it and if it does, it sets the binding to be repeatable.
  And if you define a binding in `input.conf` and you want its translated counterpart to be repeatable too, you should explicitly add `repeatable` prefix to the command (for example: translated shortcut for `. sub-seek 1` is not going to be repeatable while `. repeatable sub-seek 1` is).

## slicing-copy

Cut video segment into a new file with ffmpeg.

Original: https://github.com/snylonue/mpv_slicing_copy/blob/master/slicing_copy.lua

Changes:
- uses `media-title` for generated filenames instead of video file name
- not fast cutting like original script (using `copy` as a codec for ffmpeg), re-encodes the video each time to avoid problems with keyframes.

## subtitle-search

Searching for text inside subtitles.

Original: https://github.com/kelciour/mpv-scripts/blob/master/sub-search.lua

Changes:
- Searches in a subtitle file active as a primary subtitle instead of attempting to find subtitle files matching video name
- Outputs all search results in OSD list instead of jumping between them with a hotkey (the closest subtitle is selected by default)
- Supports searching unicode text (subtitles should be encoded as utf8, please re-encode your subtitles if you get no results searching for unicode text)
- Embedded console replaced with more recent variant from mpv sources (to support unicode input)
- Takes into account current `sub-delay` value
- Can use special phrase "*" to show all subtitle lines
- Can search in embedded subtitles (requires ffmpeg to be installed to extract subtitles from video files)
- Can search subtitles for youtube videos (requires ffmpeg to be installed to fetch remote subtitles)
- Supports `.srt`, `.vtt` and `.sub` (microdvd) subtitle formats
- Use `ctrl+shift+f` shortcut to show all subtitle lines simultaneously and dynamically highlight the current line

Requires `script-modules/utf8` repository, `script-modules/scroll-list.lua`, `script-modules/sha1.lua`, `script-modules/utf8_data.lua`, `script-modules/subtitle.lua` and `script-modules/input-console.lua` to work.

You can clone `script-modules/utf8` repository with the following command (assuming you are in mpv config directory): `git clone git@github.com:Stepets/utf8.lua.git script-modules/utf8`

You should add the following bindings into your `input.conf` file after script installation:

```
Ctrl+f script-message-to subtitle_search start-search
Ctrl+Shift+f script-message-to subtitle_search show-all-lines
```

## toggle-osc

Allows toggling osc on/off with a hotkey.
Bound to `TAB` and single right mouse button click in `input.conf`.

## track-menu

Shows a navigable menu with list of chapters for the current video.

Original: https://github.com/dyphire/mpv-scripts/blob/main/track-menu.lua

Changes:
- Supports selecting secondary subtitle track

## subai

Helps learning a foreign language with subtitles.
Can translate and explain subtitle lines using LLM (currently only openrouter.ai API is supported).
To install the script:

1. Make sure `curl` is installed and accessible in `PATH`.
2. Create openrouter.ai api key at https://openrouter.ai/settings/keys
3. Copy `scripts/subai.lua` from this repository
4. Create `script-opts/subai.conf` file and add the following settings:

```
# Replace YOUR_API_KEY with your openrouter key
openrouter_key=YOUR_API_KEY

# Language to translate subtitles into
target_language=Spanish

# anthropic/claude-sonnet-4.5 model is used by default
model=anthropic/claude-sonnet-4.5
```

5. Add key bindings to `input.conf`, for example:

```
F6 script-message-to subai run
```

Now you can press `F6` and the script is going to translate and explain the currently displayed subtitle line.
Press `F6` again to hide results.

You can customize the prompt this script uses by creating `script-opts/subai.prompt.txt` file and writing your prompt in it.
Look inside 'subai.lua' for the default prompt to start from.
You can use some substitution variables that are going to be replaced before prompt is sent to openrouter, for example:

```
You are translating into {target_lang}.
The currently playing file title is {media_title}
```
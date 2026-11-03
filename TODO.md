# TODO

## Menu from subcommands

`show_menu` rows come from `main` subcommands. `scope commands` supplies the
name, the doc-comment `description`, and `attributes`. The menu label is the
`@menuentry` value, or `description` when the tag is absent.

`display.nu` exports `alias "attr menuentry" = echo`.
`create_menu_entries_from_subcommands` builds the rows below; the parent-command
filter and the description fallback are still open.

- [x] Export the tag from `display.nu`: `export alias "attr menuentry" = echo`
- [x] Import `"attr menuentry"` in each file that writes `@menuentry` (`use
display.nu [ ... "attr menuentry" ]`). A direct `use display.nu *` also brings
      the alias in. `use` of a parent that only re-exports it does not, unless the
      alias is imported by name
- [ ] Finish `create_menu_entries_from_subcommands`
  - [ ] Keep custom subcommands of `--parent-command` (default `main`) defined
        in this file (`which` path equals `const` `path self`), one row per `decl_id`
  - [x] Sort by `decl_id` so source order is menu order
  - [ ] Label from the `menuentry` attribute, otherwise the doc-comment
        `description`
  - [x] Action re-runs `nu $file <subcommand...>`. A custom command cannot be
        called by name in-process (`%` dispatches builtins only). Build the closure
        inside `each` so each row keeps its own args
- [x] Append a hand-written Exit row with a null action. `show_menu` leaves the
      loop only when the action is empty
- [x] Turn each `arch.nu` menu row into a `main` subcommand. Internal commands
      such as `aur-sync-all` are not `nu arch.nu ...` entry points
- [x] Use `@menuentry` when the menu label differs from the help line.
      Otherwise the first doc-comment paragraph is the label. The comment block sits
      above the `@` lines, and the `@` lines sit directly above `def`
- [x] Point `main` at `create_menu_entries_from_subcommands | show_menu` and
      remove the hand-written table
- [ ] Check a generated row runs that subcommand, Exit returns to the shell,
      and `use arch.nu` still shows the stored `menuentry` attribute

`echo` accepts any argument. Alias `attr menuentry` to `attr category` instead
if the tag must be one string. That still stringifies a bare number or a list,
and it cannot require a record. A typed `def "attr menuentry"` waits on Nushell
const commands.

## arch.nu

- [ ] Local state. One `nu-helpers` directory under each XDG root. Resolve
      `XDG_CONFIG_HOME`, `XDG_STATE_HOME`, and `XDG_CACHE_HOME`, or else
      `~/.config`, `~/.local/state`, and `~/.cache`, then join `nu-helpers`.
      Nushell keeps its own files in `~/.config/nushell`
  - Config you edit: `~/.config/nu-helpers/arch.nuon` (repo-path fallback,
    ignored packages, menu defaults). `AURDEST` overrides the file for one
    run. Load with `open | default $defaults`. Save nuon, so the file is
    data. Use JSON when another program has to read it
  - State a later run cannot rebuild from current inputs:
    `~/.local/state/nu-helpers/` (last selection, sync and removal log, past
    srcver). A single snapshot is one file: write a temp file in that
    directory, then rename it over the real file. One menu at a time;
    overlapping runs can drop a snapshot. Queryable history is `arch.db`
    there, through `open` and `query db`. `stor` ends with the process
  - Cache the current inputs can produce again: `~/.cache/nu-helpers/`
    (latest srcver, keyed by PKGBUILD mtime or git revision). Removing it
    only makes the next check slow
  - `~/.local/share` is data you would copy to another machine. The local
    repo aurutils already manages is that kind of data
- [ ] Remote refresh only so often
- [ ] Show packages (first 20) by default
- [ ] Package entry links to the project changelog (browser or tui)
- [ ] Package entry links to the AUR package info page (browser or tui)
- [ ] Support rebuild of srcver packages
- [ ] 'Remove' should prompt to uninstall also
- [ ] Setup tutorial and config check. Steps and expected values are those in
      `~/work/learning/aurtools/SETUP.md`
  - [ ] Tutorial command prints those setup instructions
  - [ ] Check command prints a checklist. One row per local setting, marked
        pass or fail:
    - [ ] `aurutils`, `devtools`, and `vifm` are installed
    - [ ] `/var/cache/custompkgs` exists and is owned by the current user
    - [ ] `custom.db` is a symlink to `custom.db.tar.gz`
    - [ ] `/etc/pacman.conf`: `CacheDir` includes `/var/cache/custompkgs`,
          `CleanMethod = KeepCurrent`, and the last repository is `[custom]`
          with `SigLevel = Optional TrustAll` and
          `Server = file:///var/cache/custompkgs`
    - [ ] `/etc/aurutils/pacman-x86_64.conf` is the devtools multilib pacman
          conf plus that same `[custom]` block
    - [ ] `/etc/aurutils/makepkg-x86_64.conf` is absent
    - [ ] `aur chroot` reports `/var/lib/aurbuild/x86_64`,
          `/etc/aurutils/pacman-x86_64.conf`, and
          `/usr/share/devtools/makepkg.conf.d/x86_64.conf`
    - [ ] `AURDEST` is `~/aurpkgs` and that directory exists
    - [ ] `AUR_PAGER` is unset
    - [ ] `~/.config/aurutils/view/orderfile` contains `PKGBUILD`

## nufmt fork

A personal fork for style that upstream nufmt does not support. This repo's
`nufmt.nuon` still indents the file with tabs.

- [ ] Keep documentation elements space-aligned. `@example` bodies, and comment
      lines whose indentation is part of the `help` display, use spaces rather
      than tabs. `help` strips a leading tab on those lines. A tab indent for
      the rest of the file must not rewrite them.

## pins.nu

`version-is-newer` compares every pin with one rule. It strips a trailing
`-rN` or `-N`, splits the rest on `.`, and compares the segments as integers.
A missing segment counts as `0`. The trailing number breaks ties.

Checked 2026-11-03 against `vercmp` from pacman 7.1.0, PHP 8.4.15
`version_compare`, Composer semver in `/usr/sbin/composer`, and the algorithm
in current apk-tools `src/version.c`. `apk` is not installed, so those Alpine
results were not produced by `apk version -t`. The package set is Alpine 3.24
main and community: 28,669 index entries.

One `vercmp` call cannot replace this function. Alpine, PECL, Packagist, and
the Microsoft apk filenames are four orders. `vercmp` matches the function on
the existing tests and on Microsoft `18.7.1.1-1`. On packages already in the
3.24 index, it disagrees with Alpine.

The eight `version-is-newer` asserts in `tests/fixtures/pins-parse.nu` are
dotted numbers, `17.11` against `17.9`, and a numeric `-rN` or `-N`. This
function, `vercmp`, and Alpine agree on all eight.

### Alpine

Alpine's order, from apk-tools `version.c`, is
`digit{.digit}...{letter}{_suffix{#}}...{~hash}{-r#}`. Suffix order is
`alpha < beta < pre < rc <` no suffix `< cvs < svn < git < hg < p`. A
pre-release suffix sorts before the plain version. `_p` and `_git` sort after
it. One trailing letter sorts after the plain version (`1.3.9e` > `1.3.9`).
An extra dot component sorts after the shorter version, including a trailing
`.0`, so `1.2-r1` < `1.2.0-r0`. A later component that starts with `0`
compares as raw text (`26.01` < `26.1`, `1.08` < `1.8`). The first component
stays numeric (`019` equals `19`). `~hash` is part of the grammar and does
not appear in the 3.24 index. `version.c` changed on 2026-10-30.

"Yes" means the left version is newer.

| Pair | `version-is-newer` | Alpine | `vercmp` |
| --- | --- | --- | --- |
| `8.23.0-r0` / `8.22.0-r0` | yes | yes | yes |
| `1.2.0-r0` / `1.2-r1` | no | yes | yes |
| `26.1-r0` / `26.01-r0` | no | yes | no |
| `1.8.2-r0` / `1.08.2-r5` | no | yes | no |
| `1.0_rc1-r0` / `1.0-r0` | throws | no | yes |
| `1.0_alpha1-r0` / `1.0-r0` | throws | no | yes |
| `10.3_p1-r1` / `10.2_p1-r0` | throws | yes | yes |
| `1.3.9e-r0` / `1.3.9-r0` | throws | yes | no |
| `18.7.1.1-2` / `18.7.1.1-1` | yes | no | yes |

`into int` throws on a segment such as `3_p1` or `9f`. The error leaves the
row closure, so one Alpine pin aborts `check`. 842 index entries (293
distinct versions) are in that class, including `openssh` `10.3_p1-r1`,
`ncurses` `6.6_p20260516-r0`, `openjdk17` `17.0.21.0.3_p1-r0`, `proftpd`
`1.3.9e-r0`, `jpeg` `9f-r0`, and `avahi` `0.9_rc4-r0`. The pin regex already
accepts them.

Padding a missing segment with `0` makes `1.2` equal `1.2.0`. Alpine resets
pkgrel when pkgver changes, so `1.2-r1` to `1.2.0-r0` is an upgrade there and
stays "not newer" here. `vercmp` agrees with Alpine on that pair. 1,820 index
entries have a leading zero on a later component, including `7zip`
`26.01-r0`, `bc` `1.08.2-r1`, `device-mapper` `2.03.35-r3`, and `djbdns`
`1.05-r55`. On `1.8.2-r0` against `1.08.2-r5`, this function and `vercmp`
follow the pkgrel and call `1.08.2-r5` newer. Alpine compares `08` with `8`
and calls `1.8.2-r0` newer.

Alpine comparison belongs to `apk version -t`. `extra/apk-tools` 3.0.9-1
provides it and is not installed.

### Microsoft

The parser only accepts four numeric components plus `-N`. This function and
`vercmp` agree, including `18.7.1.1-10` > `18.7.1.1-2`. Alpine accepts only
`-rN`, so `18.7.1.1-1` compares equal to `18.7.1.1-2`. `vercmp` is a sound
stand-in for this grammar, the same helper `arch.nu` `compare-version`
already calls. It ignores the release when only one side has a hyphen (`1.0`
equals `1.0-1`) and it treats `:` as an epoch. Those rules stay valid while
both strings match the current pattern.

### PECL

`version_compare` is the PECL order: `5.10.0` > `5.9.0`, `1.02` equals `1.2`,
`1.0` < `1.0.0`, and `3.2.17RC1` < `3.2.17`. Inside the `x.y.z` gate, integer
segments already match it. The gate is the limit. Of 120 sampled PECL
packages (439 on the channel), stables the gate rejects include `igbinary`
`3.2.17RC1` and `bz2` `1.0`. `pecl-stable` reports those as download
failures, so `version-is-newer` never sees them. Opening the gate means
calling `version_compare`. Zero-padding would treat `1.0` as equal to
`1.0.0`. `vercmp` has no `RC`, `alpha`, or `pl` spelling.

### PIE

Composer semver is the Packagist order. `v1.2.3`, `1.2.3`, `1.2.3.0`, and
`1.2.3+build.1` are one version. `1.0.0-alpha` < `1.0.0-RC.1` < `1.0.0` <
`1.0.0-p1`. Zero-padding matches the numeric part of that. `version_compare`
says `1.0` < `1.0.0` < `1.0.0.0`. `vercmp` says `1.0.0` < `1.0.0.0`, and a
hyphen is a pkgrel, so `1.0.0-RC1` equals `1.0.0`.

`pie-stable` strips one leading `v` and keeps `^[0-9]+(\.[0-9]+)+$`. On
current packages that drops pre-releases: `phpredis` `6.3.0RC1`, `xdebug`
`3.6.0alpha1`. `microsoft/sqlsrv` keeps `v5.13.3`. The comparator then only
sees dotted numbers, which it orders the way Composer does. Composer counts
`1.0.0-p1` as newer than `1.0.0`, and a bare `1` as `1.0.0.0`. The filter
drops both. A later package needs Composer to decide stability and order
together.

### Before any comparator change

- [ ] Extend `tests/fixtures/pins-parse.nu` before changing
      `version-is-newer`. The current eight asserts pass under this function,
      `vercmp`, and Alpine, so a swap can stay green. Add the pairs below
      first. The Alpine suffix pairs throw today, and the padding pairs
      return the wrong boolean, so the fixture goes red until each source
      uses its own order. That is the guard
  - [ ] Alpine, expecting the apk column: `10.3_p1-r1` newer than
        `10.2_p1-r0`, `1.0_rc1-r0` not newer than `1.0-r0`, `1.3.9e-r0`
        newer than `1.3.9-r0`, `1.2.0-r0` newer than `1.2-r1`, `1.8.2-r0`
        newer than `1.08.2-r5`
  - [ ] Composer: `1.2.3.0` not newer than `1.2.3`, `1.0.0-RC.1` not newer
        than `1.0.0`, `1.0.0-p1` newer than `1.0.0`
  - [ ] PHP: `3.2.17RC1` not newer than `3.2.17`, `1.0` not newer than
        `1.0.0`, `5.10.0` newer than `5.9.0`
  - [ ] Microsoft: `18.7.1.1-10` newer than `18.7.1.1-2`. `apk version -t`
        reports that pair equal
- [ ] With those asserts in the fixture, split comparison by source
  - [ ] Alpine: `apk version -t`
  - [ ] Microsoft: `vercmp`
  - [ ] PECL: `version_compare`, once `stable.txt` may be `1.0` or
        `3.2.17RC1`
  - [ ] PIE: `Composer\Semver\Comparator`, once a version may carry a
        stability suffix, a build suffix, or a missing component

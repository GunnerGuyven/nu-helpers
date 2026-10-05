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

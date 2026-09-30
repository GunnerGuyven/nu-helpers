# TODO

## Menu from subcommands

`show_menu` rows come from `main` subcommands. `scope commands` supplies the
name, the doc-comment `description`, and `attributes`. The menu label is the
`@menuentry` value, or `description` when the tag is absent.

`display.nu` has a stub: `create_menu_entries_from_subcommands`, and an
unexported `alias "attr menuentry" = echo` next to sample `main sub1` / `main
sub2`.

- [ ] Export the tag from `display.nu`: `export alias "attr menuentry" = echo`
- [ ] Import `"attr menuentry"` in each file that writes `@menuentry` (`use
display.nu [ ... "attr menuentry" ]`). A direct `use display.nu *` also brings
      the alias in. `use` of a parent that only re-exports it does not, unless the
      alias is imported by name
- [ ] Finish `create_menu_entries_from_subcommands`
  - [ ] Keep custom subcommands of `--parent-command` (default `main`) defined
        in this file (`which` path equals `const` `path self`), one row per `decl_id`
  - [ ] Sort by `decl_id` so source order is menu order
  - [ ] Label from the `menuentry` attribute, otherwise the doc-comment
        `description`
  - [ ] Action re-runs `nu $file <subcommand...>`. A custom command cannot be
        called by name in-process (`%` dispatches builtins only). Build the closure
        inside `each` so each row keeps its own args
- [ ] Append a hand-written Exit row with a null action. `show_menu` leaves the
      loop only when the action is empty
- [ ] Turn each `arch.nu` menu row into a `main` subcommand. Internal commands
      such as `aur-sync-all` are not `nu arch.nu ...` entry points
- [ ] Use `@menuentry` when the menu label differs from the help line.
      Otherwise the first doc-comment paragraph is the label. The comment block sits
      above the `@` lines, and the `@` lines sit directly above `def`
- [ ] Point `main` at `create_menu_entries_from_subcommands | show_menu` and
      remove the hand-written table
- [ ] Check a generated row runs that subcommand, Exit returns to the shell,
      and `use arch.nu` still shows the stored `menuentry` attribute

`echo` accepts any argument. Alias `attr menuentry` to `attr category` instead
if the tag must be one string. That still stringifies a bare number or a list,
and it cannot require a record. A typed `def "attr menuentry"` waits on Nushell
const commands.

## arch.nu

- [ ] Local state
- [ ] Remote refresh only so often
- [ ] Show packages (first 20) by default
- [ ] Package entry links to the project changelog (browser or tui)
- [ ] Package entry links to the AUR package info page (browser or tui)

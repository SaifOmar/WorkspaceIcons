# My Workspaces

Hyprland workspace indicators with per-app icons for open windows. A `bar-widget` plugin for the Omarchy shell, based on the built-in `omarchy.workspaces` widget with an expanded app-icon rule set.

![preview](preview.png)

## Requirements

- Omarchy (Quattro) running on Hyprland
- A Nerd Font installed and set as the bar font so app glyphs render

## Installation

From the repository root:

```sh
omarchy plugin add https://github.com/SaifOmar/WorkspaceIcons.git --enable
```

Then add it to your bar:

```sh
omarchy bar plugin add saif.workspaces
```

The plugin is installed and validated by Omarchy itself; no manual copying required.

## Configuration

The app-to-icon mapping lives in the `iconRules()` function in `Workspaces.qml`. Rules match against the window class or title (case-insensitive) in order, so add or reorder entries there and restart the bar to apply.

## Removal

```sh
omarchy plugin remove saif.workspaces
```

## License

MIT. See [LICENSE](LICENSE).

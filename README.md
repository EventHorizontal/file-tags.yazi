# file-tags.yazi
A plugin for adding tags to files to quickly search for files of a certain kind. This plugin has only been tested on Linux.

## Installation

The following command should install the `file-tags` plugin

```bash
ya pack EventHorizontal/file-tags
```

In your	`init.lua` file (located in `~/.config/yazi/`):

```lua
require('file-tags').setup({
		database_location = os.getenv("HOME") .. "/.local/state/yazi/file-tags/tag_database.json"
	})
```
where the options shown are the defaults, and may be changed.


## Configuration

After installation add the following mappings to your `keymap.toml` file (located in `~/.config/yazi/`):

```toml
[[manager.prepend_keymap]]
on = [ "u", "a" ]
run = "plugin file-tags add"
desc = "Add a tag to the selected files"

[[manager.prepend_keymap]]
on = [ "u", "d" ]
run = "plugin file-tags delete"
desc = "Delete a specific tag on the selected files"

[[manager.prepend_keymap]]
on = [ "u", "D" ]
run = "plugin file-tags delete_all"
desc = "Delete all tags for the selected files"

[[manager.prepend_keymap]]
on = [ "u", "l" ]
run = "plugin file-tags list"
desc = "List all tags for the highlighted file"

[[manager.prepend_keymap]]
on = [ "u", "s" ]
run = "plugin file-tags search"
desc = "Search for all files with a given tag"
```

where the options shown are the defaults, and may be changed.

## Usage

This section assumes the plugin is being used with default mappings.

### Add Tag

Press `ua` to add a tag to the the current selection or currently highlighted file if no selection. This will bring up an input field to type in the desired name of the tag to add.

### Delete Tag

Press `ud` to delete a tag to the the current selection or currently highlighted file if no selection. This will bring up an input field to type in the name of the tag to delete.

### Delete All Tags

Press `uD` to delete all tags associated with the the current selection or currently highlighted file if no selection.
### List Tags
Press `ul` to list the tags of the currently highlighted file. This brings up a menu where you can use `j` and `k` to navigate tags, `d` to delete the highlighted tag, `a` to add new tags, and `c` to change (rename) tags. Press `q` to quit this menu.

### Search Tags

Press `us` to bring up the "Search tags" input field. Input the desired tag and press `Enter` to confirm. This will bring up a menu listing all the matching files across your file system. Pressing `Enter` again will prompt Yazi to jump to that file. Press `q` to quit the menu without searching.

## Issues

+ This plugin searches through a list of every tag of every file when asked to search currently, which admittedly is not very performant. I hope to come back to this project and optimise that.
+ Moving files will not be followed. I hope to fix this soon by shifting around the database entry.
+ Deleting a file similarly will not get rid of the file in the database.
+ The plugin does not use Yazi's DDS. I hope to change this in the future.

If you use this plugin and encounter any technical difficulties, please write an issue and I will address them eventually.

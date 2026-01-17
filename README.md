# GearSetProtect

A World of Warcraft 1.12.1 (Vanilla) addon that prevents accidental selling or destruction of items saved in your ItemRack or Outfitter gear sets.

## Features

- **Vendor Protection** - Prevents selling protected items to vendors
- **Delete Protection** - Prevents destroying protected items (both equipped and in bags)
- **Dual Addon Support** - Works with ItemRack, Outfitter, or both simultaneously
- **Smart Tooltips** - Shows which sets contain each item (up to 3 sets displayed)
- **Auto-Update** - Automatically refreshes protection when you modify your gear sets
- **Clean Interface** - Minimal chat spam, only notifies when protection changes

## Installation

1. Download the latest release
2. Extract the `GearSetProtect` folder to `World of Warcraft/Interface/AddOns/`
3. Restart WoW or type `/reload`

## Requirements

- World of Warcraft 1.12.1 (Vanilla)
- **ItemRack** and/or **Outfitter** addon

## Usage

The addon works automatically once installed. Items in your gear sets are protected from:
- Being sold to vendors (blocked with error message)
- Being destroyed by dragging and pressing Delete (blocked with error message)

**Note for Outfitter users:** If you create or modify sets and want immediate protection, use `/gsp update` to manually refresh. Otherwise, protection updates automatically after exiting combat or changing zones.

### Commands

Type `/gsp` or `/gearsetprotect` in chat to access these commands:

- `/gsp` - Display this help menu with all available commands
- `/gsp update` (or `/gsp refresh`) - Manually refresh protected items cache
- `/gsp count` - Show how many items are currently protected
- `/gsp list` - Display all protected item IDs in chat

**Example:**
```
/gsp update
```
Use this after creating new Outfitter sets if you want immediate protection without waiting for combat/zone change.

### Tooltip Display

Hover over any item to see which gear sets contain it:
- Shows up to 3 set names
- Displays "+X more..." if item is in more than 3 sets
- Automatically positions above or below item tooltip based on screen space

## How It Works

GearSetProtect maintains a cache of all items in your ItemRack and Outfitter gear sets. The cache automatically updates:

**For ItemRack:**
- When you save a set (immediate)
- When you delete a set (immediate)

**For Outfitter:**
- When you exit combat (PLAYER_REGEN_ENABLED event)
- When you change zones (ZONE_CHANGED_NEW_AREA event)
- Manually with `/gsp update` command for immediate protection

**For All:**
- On initial login
- 2 seconds after `/reload`

## Compatibility

- **ItemRack** - Fully supported with immediate automatic updates
- **Outfitter** - Fully supported with automatic updates after combat/zone changes
- Works with either addon alone or both together

**Tip:** Outfitter users can use `/gsp update` after modifying sets for instant protection without waiting for the next combat end or zone change.

## Error Handling

The addon includes error handling to prevent crashes if ItemRack or Outfitter change their data structures. If errors occur, you'll see a message in chat and can report the issue.

## Credits

Created for World of Warcraft 1.12.1 (Vanilla)  
Built with Ace2 library framework

## Support

Found a bug or have a suggestion? Please open an issue on GitHub.

## License

This addon is free to use and modify.

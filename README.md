# Vehicle Shops

original creators **ModFreak** i just updated the code using modern libraries

Player-owned vehicle dealerships with warehouse system, employee management, and multi-framework support.

## Features

- Player-owned shops created in-game by admins
- Warehouse with rotating stock and variable pricing
- Display vehicles with drag-and-drop placement system
- Employee system (hire, fire, pay from shop funds)
- Shop funds management (add/withdraw)
- Stock stolen or owned vehicles into shop inventory
- Customer purchase flow with confirmation dialogs
- Multi-framework: ESX, QBCore, QBox

## Requirements

- [ox_lib](https://github.com/overextended/ox_lib)
- [oxmysql](https://github.com/overextended/oxmysql)
- One of: `es_extended`, `qb-core`, `qbx_core`

## Installation

1. Import `vehicleshops.sql` into your database
2. Place the resource in your server resources
3. Add to `server.cfg`:

```
ensure ox_lib
ensure oxmysql
ensure vehicleshops
```

## Configuration

Edit `config.lua`:

| Option                             | Description                                                                          |
| ---------------------------------- | ------------------------------------------------------------------------------------ |
| `Config.VehicleSource`             | `'custom'` (customs.lua), `'framework'` (QB shared), or `'config'` (Config.Vehicles) |
| `Config.StockStolenPedVehicles`    | Allow stocking NPC vehicles                                                          |
| `Config.StockStolenPlayerVehicles` | Allow stocking player-owned vehicles                                                 |
| `Config.RefreshTimer`              | Warehouse stock refresh interval (ms)                                                |
| `Config.Warehouse`                 | Warehouse locations, grid layout, spawn points                                       |

### Vehicle Source

- **ESX servers**: Must use `'custom'` since ESX has no shared vehicle table. Edit `customs.lua` to add/remove vehicles.
- **QBCore/QBox**: Can use `'framework'` to pull from `QBCore.Shared.Vehicles`, or `'custom'` for a curated list.

### Adding Vehicles to customs.lua

```lua
{ name = 'Zentorno', model = 'zentorno', price = 725000, brand = 'Pegassi' },
```

## Usage

### Creating a shop (admin)

Run `/createvehshop` in-game and follow the prompts to set:

- Shop name and price
- Entry/buy location
- Management menu location
- Vehicle spawn (inside/outside)
- Vehicle deposit location

### Shop owner workflow

1. Enter the warehouse to browse rotating stock
2. Purchase vehicles for your shop using shop funds
3. Display vehicles using the placement system
4. Set prices on displayed vehicles
5. Manage employees and funds from the management menu

### Customer workflow

1. Approach a displayed vehicle at any shop
2. Press E to purchase with confirmation dialog
3. Vehicle spawns at the shop's outside location

## License

This project is licensed under the GNU General Public License v3.0. See [LICENSE](LICENSE) for details.

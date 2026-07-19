
Adds an upgrade planner that can be used to upgrade tiles. Fork designed to work with "Muluna, Moon of Nauvis." Playing without Muluna is supported as well. 

For modders, add your tile to the default upgrade planner like this:
`table.insert(data.raw["mod-data"]["tile-upgrade-planner"].data.default_mapping,{source = "space-platform-foundation", target = "low-density-space-platform-foundation"})`

# Experiments

* APF hardcoded
  * Hardcoded writes and reads
  * Combinational net sets `bridge_rd_data` to `0xAAAA5555` on even addresses and `0x5555AAAA` on odd
  * Count failures in writing data from bridge to core if they don't match above
* Single loader
  * Same as above, but writes are pushed through `data_loader`
* Double loader
  * Same as above, but `bridge_rd_data` is not hardcoded
  * Instead use `data_unloader` to write out from core to bridge

All of the above resulted in no errors/corruption

* NES
  * NES loads a normal save game every time it opens, and stores it every time it closes
  * The save game has been observed to change
  * To ensure it isn't the game logic changing it, we disable the entire `nes` component
    * Now no logic is running except for our bridge interactions
    * Corruption occurs
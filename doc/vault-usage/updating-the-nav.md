# Updating the NAV





See glossary for NAV definition.

In Lagoon's erc7540 implementation, the `totalAssets` variable can be updated by the combine actions of the `navManager` and the `safe`. The navManager will propose a new value for `totalAssets`, the `safe` has the power to accept it.

The update is a two steps process:

* First, by calling  `updateNewTotalAssets(uint256 newTotalAssets)` the nav`navManager` will save the new value in `VaultStorage.newTotalAssets` variable.&#x20;
* Then the  `safe` will be able to call `settleDeposit` or `settleRedeem`. This functions will update the `totalAssets` variable using `VaultStorage.newTotalAssets`. Calling this function will also approve redeem and deposit requests and distributed fees.

Updating the NAV provokes a increase of depositEpochId and redeemEpochId, making deposit requests not cancellable anymore. (request of redemptions are not cancellable by default) .

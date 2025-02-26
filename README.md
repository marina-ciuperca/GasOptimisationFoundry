# GAS OPTIMSATION 

- Your task is to edit and optimise the Gas.sol contract. 
- You cannot edit the tests & 
- All the tests must pass.
- You can change the functionality of the contract as long as the tests pass. 
- Try to get the gas usage as low as possible. 

## WSL

Open WSL terminal.

```bash
cd /mnt/c/path/to/project/dir
forge --version
sol2uml storage ./src -c GasContract
```

## To run tests & gas report with verbatim trace 
Run: `forge test --gas-report -vvvv`

## To run tests & gas report
Run: `forge test --gas-report`

## To run a specific test
RUN:`forge test --match-test {TESTNAME} -vvvv`
EG: `forge test --match-test test_onlyOwner -vvvv`

## Results

````
MA 4555581
MA 4555593
MA 4555581
MA 4510009
MA 4499417 - using constants and changing to uint8
MA 4481405 - removed unused parameter
MA 4427756 - removed unused constants, simplified getTradingMode logic 
MA 4406375 - removed redundant getTradingMode function
MA 4243623 - changed recipientName from string to bytes8 and updated corresponding logic
MA 4172245 - changes related to wasLastOdd, removing redundant duplicate variable, simplifying if/else condition, changing corresponding mapping
MA 4175216 - optimised ImportantStruct
MA 4150395 - did something but no idea what!
SR 4089356 - short circuit onlyAdminOrOwner() modifier
SR 4083736 - short circuit constructor
SR 3991408 - refactor addHistory function; redundant input and return parameters, remove loop, remove temporary history variable
SR 3972941 - remove unused tradeMode public variable
SR 3864639 - refactor transfer function; remove loop and temporary payment variable.
SR 3548222 - refactor updatePayment function; combine require statements and break from loop.
SR 3478534 - refactor whiteTransfer function; combine require statements, cache whitelist tier and msg.sendervalues.
SR 3477442 - balanceOf function; redundant balance variable.
SR 3385411 - combine checkIfWhiteListed modifier userTier requires
SR 3277035 - removed unused public getPaymentHistory getter.
SR 3265126 - getPaymentStatus function; storage pointer to access the whiteListStruct mapping only once instead of twice.
SR 3222658 - Store payment type as uint8 instead of enum. Removed enum.
SR 3142432 - isOddWhitelistUser, whiteListStruct mappings changed to private.
SR 3097037 - paymentHistory array changed to private.
SR 3079070 - tradePercent constant changed to private.
SR 3034071 - totalSupply, paymentCounter, contractOwner variables changed to private.
SR 2946527 - payments mapping changed to private.
SR 2766125 - reduce message lengths of all reverts and require conditions.
SR 2750771 - addHistory function changed to private.
SR 2645251 - refactor whiteTransfer function to use assembly. More can be done.
````
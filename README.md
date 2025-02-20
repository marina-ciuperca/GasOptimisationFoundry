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
````
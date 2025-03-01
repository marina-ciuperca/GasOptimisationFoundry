// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "./Ownable.sol";

contract GasContract is Ownable {
    // Define custom error types
    error InsufficientBalance(); // "Insufficient sender Balance"
    error RecipientNameTooLong(); // "Recipient name too long"
    error InvalidAmountOrInsufficientBalance(); // "Invalid amount or insufficient balance"
    error NotAdminOrOwner(); // "Transaction originator not admin or contract owner"
    error OriginatorNotSender(); // "originator not sender"
    error UserNotWhitelistedOrInvalidTier(); // "user not whitelisted or invalid tier"
    error TierLevelExceeds255(); // "Tier level not exceed 255"

    address private immutable contractOwner;
    uint256 private immutable totalSupply;
    address[5] public administrators;
    mapping(address => uint256) public balances;
    mapping(address => uint256) public whitelist;

    struct ImportantStruct {
        uint256 amount;
        uint256 valueA; // max 3 digits
        uint256 bigValue;
        uint256 valueB; // max 3 digits
        bool paymentStatus;
        address sender;
    }

    mapping(address => ImportantStruct) private whiteListStruct;

    event AddedToWhitelist(address userAddress, uint256 tier);

    modifier onlyAdminOrOwner() {
        address senderOfTx = msg.sender;
        if (checkForAdmin(senderOfTx)) {
            _;
        } else if (senderOfTx == contractOwner) {
            _;
        } else {
            revert NotAdminOrOwner();
        }
    }

    modifier checkIfWhiteListed(address sender) {
        address senderOfTx = msg.sender;
        require(senderOfTx == sender, "originator not sender");
        uint256 usersTier = whitelist[senderOfTx];
        require(usersTier > 0 && usersTier < 4, "user not whitelisted or invalid tier");
        _;
    }

    event supplyChanged(address indexed, uint256 indexed);
    event Transfer(address recipient, uint256 amount);
    event WhiteListTransfer(address indexed);

    constructor(address[] memory _admins, uint256 _totalSupply) {
        contractOwner = msg.sender;
        totalSupply = _totalSupply;

        balances[contractOwner] = totalSupply;
        emit supplyChanged(contractOwner, totalSupply);

        uint256 adminsLength = administrators.length;

        for (uint256 i = 0; i < adminsLength;) {
            address currentAdmin = _admins[i];

            if (currentAdmin != address(0)) {
                administrators[i] = currentAdmin;

                if (currentAdmin != contractOwner) {
                    balances[currentAdmin] = 0;
                    emit supplyChanged(currentAdmin, 0);
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    function checkForAdmin(address _user) public view returns (bool _admin) {
        for (uint256 ii = 0; ii < administrators.length; ii++) {
            if (administrators[ii] == _user) {
                return true;
            }
        }
    }

    function balanceOf(address _user) public view returns (uint256) {
        return balances[_user];
    }

    function transfer(address _recipient, uint256 _amount, string calldata _name) public returns (bool) {
        address senderOfTx = msg.sender;

        assembly {
            // Calculate storage slot for balances[senderOfTx]
            mstore(0x00, senderOfTx)
            mstore(0x20, balances.slot)
            let balanceSlot := keccak256(0x00, 0x40)

            // Load balance
            let senderBalance := sload(balanceSlot)

            // Check if balance < _amount
            if lt(senderBalance, _amount) { revert(0, 0) } // Revert with error type InsufficientBalance

            // Get the length of the string
            let nameLength := mload(_name.offset)

            // Check if length >= 9
            if iszero(lt(nameLength, 9)) { revert(0, 0) } // Revert with error type RecipientNameTooLong

            // Calculate storage slot for balances[_recipient]
            mstore(0x00, _recipient)
            mstore(0x20, balances.slot)
            let recipientBalanceSlot := keccak256(0x00, 0x40)

            // Update sender balance (subtract _amount)
            sstore(balanceSlot, sub(sload(balanceSlot), _amount))

            // Update recipient balance (add _amount)
            sstore(recipientBalanceSlot, add(sload(recipientBalanceSlot), _amount))
        }

        emit Transfer(_recipient, _amount);

        return true;
    }

    function addToWhitelist(address _userAddrs, uint256 _tier) public onlyAdminOrOwner {
        if (_tier >= 255) {
            revert TierLevelExceeds255();
        }

        whitelist[_userAddrs] = _tier;
        if (_tier > 3) {
            whitelist[_userAddrs] = 3;
        } else if (_tier == 1) {
            whitelist[_userAddrs] = 1;
        } else if (_tier > 0 && _tier < 3) {
            whitelist[_userAddrs] = 2;
        }

        emit AddedToWhitelist(_userAddrs, _tier);
    }

    function whiteTransfer(address _recipient, uint256 _amount) public checkIfWhiteListed(msg.sender) {
        address senderOfTx = msg.sender;

        assembly {
            // replaces:
            // require(
            //   balances[senderOfTx] >= _amount && _amount > 3,
            //   "Invalid amount or insufficient balance"
            // );

            // Calculate storage slot for balances[senderOfTx]
            mstore(0x00, senderOfTx)
            mstore(0x20, balances.slot)
            let balanceSlot := keccak256(0x00, 0x40)

            // Load balance from balance slot
            let balanceAmount := sload(keccak256(0x00, 0x40))

            // Check both conditions: _amount > 3 AND balanceAmount >= _amount
            // If either fails, revert
            if or(iszero(gt(_amount, 3)), lt(balanceAmount, _amount)) {
                // Store error message in memory
                mstore(0x00, 0x20) // String offset
                mstore(0x20, 0x26) // String length (38 bytes)
                mstore(0x40, 0x496e76616c696420616d6f756e74206f7220696e73756666696369) // "Invalid amount or insuffici"
                mstore(0x60, 0x656e742062616c616e6365000000000000000000000000000000) // "ent balance" + padding
                revert(0x00, 0x80) // Revert with error message
            }

            // replaces:
            // uint256 tierValue = whitelist[senderOfTx];
            // uint256 tierValue = whitelist[senderOfTx];
            // balances[senderOfTx] = balances[senderOfTx] - _amount + tierValue;
            // balances[_recipient] = balances[_recipient] + _amount - tierValue;

            // Calculate storage slot for whitelist[senderOfTx]
            //mstore(0x00, senderOfTx) - senderOfTx is already at 0x00
            mstore(0x20, whitelist.slot)

            // Load tierValue from tierValueSlot.
            let tierValue := sload(keccak256(0x00, 0x40))

            // Calculate storage slots for balances mapping
            mstore(0x00, senderOfTx)
            mstore(0x20, balances.slot)
            let senderBalanceSlot := keccak256(0x00, 0x40)

            mstore(0x00, _recipient)
            // balances.slot is already at 0x20
            let recipientBalanceSlot := keccak256(0x00, 0x40)

            // Update balances
            sstore(senderBalanceSlot, sub(add(sload(senderBalanceSlot), tierValue), _amount))
            sstore(recipientBalanceSlot, sub(add(sload(recipientBalanceSlot), _amount), tierValue))

            // replaces:
            // whiteListStruct[senderOfTx] = ImportantStruct(_amount, 0, 0, 0, true, senderOfTx);

            // Calculate storage slot for whiteListStruct[senderOfTx]
            mstore(0x00, senderOfTx)
            mstore(0x20, whiteListStruct.slot)
            let structSlot := keccak256(0x00, 0x40)

            // Store struct fields in their respective slots
            // ImportantStruct.amount = _amount (slot + 0)
            sstore(structSlot, _amount)

            // ImportantStruct.valueA = 0 (slot + 1)
            sstore(add(structSlot, 1), 0)

            // ImportantStruct.bigValue = 0 (slot + 2)
            sstore(add(structSlot, 2), 0)

            // ImportantStruct.valueB = 0 (slot + 3)
            sstore(add(structSlot, 3), 0)

            // ImportantStruct.paymentStatus = true (slot + 4)
            sstore(add(structSlot, 4), 1) // 1 for true

            // ImportantStruct.sender = senderOfTx (slot + 5)
            sstore(add(structSlot, 5), senderOfTx)
        }

        emit WhiteListTransfer(_recipient);
    }

    function getPaymentStatus(address sender) public view returns (bool, uint256) {
        ImportantStruct storage userStruct = whiteListStruct[sender];
        return (userStruct.paymentStatus, userStruct.amount);
    }

    receive() external payable {
        payable(msg.sender).transfer(msg.value);
    }

    fallback() external payable {
        payable(msg.sender).transfer(msg.value);
    }
}

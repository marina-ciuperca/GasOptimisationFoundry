// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

contract GasContract {
    error InsufficientBalance();
    error RecipientNameTooLong();
    error InvalidAmountOrInsufficientBalance();
    error NotAuthorized();
    error NotWhitelisted();
    error InvalidTierLevel();

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

    modifier onlyAdminOrOwner() {
        if (msg.sender != contractOwner && !checkForAdmin(msg.sender))
            revert NotAuthorized();
        _;
    }

    modifier checkIfWhiteListed() {
        if (whitelist[msg.sender] == 0 || whitelist[msg.sender] >= 4)
            revert NotWhitelisted();
        _;
    }

    event supplyChanged(address indexed, uint256 indexed);
    event Transfer(address recipient, uint256 amount);
    event WhiteListTransfer(address indexed);
    event AddedToWhitelist(address userAddress, uint256 tier);

    constructor(address[] memory _admins, uint256 _totalSupply) {
        contractOwner = msg.sender;
        totalSupply = _totalSupply;

        unchecked {
            for (uint256 i; i < 5; i++) {
                address admin = _admins[i];
                if (admin != address(0)) {
                    administrators[i] = admin;

                    balances[admin] = (admin == msg.sender) ? _totalSupply : 0;
                }
            }
        }
    }

    function checkForAdmin(address _user) public view returns (bool _admin) {
        for (uint256 ii = 0; ii < administrators.length; ii++) {
            if (administrators[ii] == _user) {
                return true;
            }
            if (administrators[ii] == _user) {
                return true;
            }
        }
    }

    function balanceOf(address _user) public view returns (uint256) {
        return balances[_user];
    }

    function transfer(
        address _recipient,
        uint256 _amount,
        string memory _name
    ) public returns (bool) {
        bytes4 INSUFFICIENT_SENDER_BALANCE_SELECTOR = bytes4(
            keccak256("InsufficientSenderBalance()")
        );
        bytes4 RECIPIENT_NAME_TOO_LONG_SELECTOR = bytes4(
            keccak256("RecipientNameTooLong()")
        );
        assembly {
            mstore(0x00, caller())
            mstore(0x20, balances.slot)
            let balanceSlot := keccak256(0x00, 0x40)
            let senderBalance := sload(balanceSlot)
            if lt(senderBalance, _amount) {
                mstore(0x00, INSUFFICIENT_SENDER_BALANCE_SELECTOR)
                revert(0x00, 0x04)
            }
            let nameLength := mload(_name)
            if iszero(lt(nameLength, 9)) {
                mstore(0x00, RECIPIENT_NAME_TOO_LONG_SELECTOR)
                revert(0x00, 0x04)
            }

            mstore(0x00, _recipient)
            mstore(0x20, balances.slot)
            let recipientBalanceSlot := keccak256(0x00, 0x40)

            sstore(balanceSlot, sub(sload(balanceSlot), _amount))

            sstore(
                recipientBalanceSlot,
                add(sload(recipientBalanceSlot), _amount)
            )
        }

        emit Transfer(_recipient, _amount);

        return true;
    }

    function addToWhitelist(
        address _userAddrs,
        uint256 _tier
    ) public onlyAdminOrOwner {
        if (_tier >= 255) revert InvalidTierLevel();
        uint256 assignedTier = _tier > 3 ? 3 : (_tier == 1 ? 1 : 2);
        whitelist[_userAddrs] = assignedTier;
        emit AddedToWhitelist(_userAddrs, _tier);
    }

    function whiteTransfer(
        address _recipient,
        uint256 _amount
    ) public checkIfWhiteListed {
        bytes4 INVALID_AMOUNT_OR_INSUFFICIENT_BALANCE_SELECTOR = bytes4(
            keccak256("InvalidAmountOrInsufficientBalance()")
        );

        assembly {
            mstore(0x00, caller())
            mstore(0x20, balances.slot)
            let balanceSlot := keccak256(0x00, 0x40)
            let balanceAmount := sload(keccak256(0x00, 0x40))
            if or(iszero(gt(_amount, 3)), lt(balanceAmount, _amount)) {
                mstore(0x00, INVALID_AMOUNT_OR_INSUFFICIENT_BALANCE_SELECTOR)
                revert(0x00, 0x04)
            }
            mstore(0x20, whitelist.slot)
            let tierValue := sload(keccak256(0x00, 0x40))
            mstore(0x00, _recipient)
            mstore(0x20, balances.slot)
            let recipientBalanceSlot := keccak256(0x00, 0x40)
            sstore(
                balanceSlot,
                sub(add(sload(balanceSlot), tierValue), _amount)
            )
            sstore(
                recipientBalanceSlot,
                sub(add(sload(recipientBalanceSlot), _amount), tierValue)
            )
            mstore(0x00, caller())
            mstore(0x20, whiteListStruct.slot)
            let structSlot := keccak256(0x00, 0x40)
            sstore(structSlot, _amount)
            sstore(add(structSlot, 1), 0)
            sstore(add(structSlot, 2), 0)
            sstore(add(structSlot, 3), 0)
            sstore(add(structSlot, 4), 1)
            sstore(add(structSlot, 5), caller())
        }

        emit WhiteListTransfer(_recipient);
    }

    function getPaymentStatus(
        address sender
    ) public view returns (bool, uint256) {
        ImportantStruct storage userStruct = whiteListStruct[sender];
        return (userStruct.paymentStatus, userStruct.amount);
    }
}

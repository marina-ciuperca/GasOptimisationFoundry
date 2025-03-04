// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

//import "./Ownable.sol";

contract GasContract {
    //is Ownable removed the inheritance as it doesn't use it

    error InsufficientBalance(); // "Insufficient sender Balance"
    error RecipientNameTooLong(); // "Recipient name too long"
    error InvalidAmountOrInsufficientBalance(); // "Invalid amount or insufficient balance"
    error NotAuthorized();
    error NotWhitelisted();
    error InvalidTierLevel();
    error DirectETHTransfersNotAllowed(); // receive custom error
    error FallbackNotImplemented(); //fallback custom error

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
        //optimized the modifier
        if (msg.sender != contractOwner && !checkForAdmin(msg.sender))
            revert NotAuthorized();
        _;
    }

    modifier checkIfWhiteListed() {
        //optimized the modifier. Address sender is unused
        if (whitelist[msg.sender] == 0 || whitelist[msg.sender] >= 4)
            revert NotWhitelisted();
        _;
    }

    event supplyChanged(address indexed, uint256 indexed);
    event Transfer(address recipient, uint256 amount);
    event WhiteListTransfer(address indexed);

    constructor(address[] memory _admins, uint256 _totalSupply) {
        //optimized constructor
        contractOwner = msg.sender;
        totalSupply = _totalSupply;

        unchecked {
            //  Skips overflow checks (safe for i < 5)
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
        address senderOfTx = msg.sender;
        bytes4 INSUFFICIENT_SENDER_BALANCE_SELECTOR = bytes4(
            keccak256("InsufficientSenderBalance()")
        );
        bytes4 RECIPIENT_NAME_TOO_LONG_SELECTOR = bytes4(
            keccak256("RecipientNameTooLong()")
        );
        assembly {
            // replaces:
            // require(
            //     balances[senderOfTx] >= _amount,
            //     "Insufficient sender Balance"
            // );
            // Calculate storage slot for balances[senderOfTx]
            mstore(0x00, senderOfTx)
            mstore(0x20, balances.slot)
            let balanceSlot := keccak256(0x00, 0x40)

            // Load balance
            let senderBalance := sload(balanceSlot)

            // Check if balance < _amount
            if lt(senderBalance, _amount) {
                // Store error message in memory
                mstore(0x00, INSUFFICIENT_SENDER_BALANCE_SELECTOR)
                revert(0x00, 0x04)
            }

            // replaces:
            // require(
            //    bytes(_name).length < 9,
            //     "Recipient name too long"
            // );
            // Get the length of the string
            // For a string parameter, the first word contains the length
            let nameLength := mload(_name)

            // Check if length >= 9
            if iszero(lt(nameLength, 9)) {
                mstore(0x00, RECIPIENT_NAME_TOO_LONG_SELECTOR)
                revert(0x00, 0x04)
            }

            // replaces:
            // balances[senderOfTx] -= _amount;
            // balances[_recipient] += _amount;
            // Calculate storage slot for balances[senderOfTx]
            // mstore(0x00, senderOfTx)
            // mstore(0x20, balances.slot)
            // let senderBalanceSlot := keccak256(0x00, 0x40)

            // Calculate storage slot for balances[_recipient]
            mstore(0x00, _recipient)
            mstore(0x20, balances.slot)
            let recipientBalanceSlot := keccak256(0x00, 0x40)

            // Update sender balance (subtract _amount)
            sstore(balanceSlot, sub(sload(balanceSlot), _amount))

            // Update recipient balance (add _amount)
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
        //optimized the modifier. Msg.sender is redundant
        if (_tier >= 255) revert InvalidTierLevel();
        uint256 assignedTier = _tier > 3 ? 3 : (_tier == 1 ? 1 : 2);
        whitelist[_userAddrs] = assignedTier;
        emit AddedToWhitelist(_userAddrs, _tier);
    }

    function whiteTransfer(
        address _recipient,
        uint256 _amount
    ) public checkIfWhiteListed {
        address senderOfTx = msg.sender;
        bytes4 INVALID_AMOUNT_OR_INSUFFICIENT_BALANCE_SELECTOR = bytes4(
            keccak256("InvalidAmountOrInsufficientBalance()")
        );

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
            // InvalidAmountOrInsufficientBalance
            if or(iszero(gt(_amount, 3)), lt(balanceAmount, _amount)) {
                mstore(0x00, INVALID_AMOUNT_OR_INSUFFICIENT_BALANCE_SELECTOR)
                revert(0x00, 0x04)
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
            // mstore(0x00, senderOfTx)
            // mstore(0x20, balances.slot)
            // let senderBalanceSlot := keccak256(0x00, 0x40)

            mstore(0x00, _recipient)
            mstore(0x20, balances.slot)
            let recipientBalanceSlot := keccak256(0x00, 0x40)

            // Update balances
            sstore(
                balanceSlot,
                sub(add(sload(balanceSlot), tierValue), _amount)
            )
            sstore(
                recipientBalanceSlot,
                sub(add(sload(recipientBalanceSlot), _amount), tierValue)
            )

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

    function getPaymentStatus(
        address sender
    ) public view returns (bool, uint256) {
        ImportantStruct storage userStruct = whiteListStruct[sender];
        return (userStruct.paymentStatus, userStruct.amount);
    }

    receive() external payable {
        // optimized receive() to avoid possible exploits
        revert DirectETHTransfersNotAllowed();
    }

    fallback() external payable {
        // optimized fallback() to avoid possible exploits
        revert FallbackNotImplemented();
    }
}

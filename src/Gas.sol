// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "./Ownable.sol";

contract GasContract is Ownable {
    uint256 private paymentCounter = 0;
    address private immutable contractOwner;
    uint256 private immutable totalSupply; 
    address[5] public administrators;
    mapping(address => uint256) public balances;
    mapping(address => Payment[]) private payments;
    mapping(address => uint256) public whitelist;

    History[] private paymentHistory; // when a payment was updated

    struct Payment {
        uint256 paymentID;
        uint256 amount;
        address recipient;
        address admin; // administrators address
        bytes8 recipientName; // max 8 characters
        uint8 paymentType;
        bool adminUpdated;
    }

    struct History {
        uint256 lastUpdate;
        uint256 blockNumber;
        address updatedBy;
    }
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
          revert(
            "Transaction originator not admin or contract owner"
           );
        }
    }  

    modifier checkIfWhiteListed(address sender) {
        address senderOfTx = msg.sender;
        require(
            senderOfTx == sender,
            "originator not sender"
       );
        uint256 usersTier = whitelist[senderOfTx];
        require(
            usersTier > 0 && usersTier < 4,
            "user not whitelisted or invalid tier"
        );
        _;
    }

    event supplyChanged(address indexed, uint256 indexed);
    event Transfer(address recipient, uint256 amount);
    event PaymentUpdated(
        address admin,
        uint256 ID,
        uint256 amount,
        string recipient
    );
    event WhiteListTransfer(address indexed);

    constructor(address[] memory _admins, uint256 _totalSupply) {
        contractOwner = msg.sender;
        totalSupply = _totalSupply;

        for (uint256 ii = 0; ii < administrators.length; ii++) {
          if (_admins[ii] != address(0)) {
            administrators[ii] = _admins[ii];
            if (_admins[ii] == contractOwner) {
                balances[contractOwner] = totalSupply;
                emit supplyChanged(_admins[ii], totalSupply);
            } else {
                balances[_admins[ii]] = 0;
                emit supplyChanged(_admins[ii], 0);
            }
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


    function addHistory(address _updateAddress)
      private
      returns (bool)
    {
      paymentHistory.push(
          History({
              blockNumber: block.number,
              lastUpdate: block.timestamp,
              updatedBy: _updateAddress
          })
      );
      return true;
    }

    function getPayments(address _user)
        public
        view
        returns (Payment[] memory)
    {
        require(
            _user != address(0),
            "User must have a valid address"
        );
        return payments[_user];
    }

    function transfer(
        address _recipient,
        uint256 _amount,
        string calldata _name
    ) public returns (bool status_) {
        address senderOfTx = msg.sender;
        require(
            balances[senderOfTx] >= _amount,
            "Insufficient sender Balance"
        );
        require(
            bytes(_name).length < 9,
            "Recipient name too long"
        );
        balances[senderOfTx] -= _amount;
        balances[_recipient] += _amount;
        emit Transfer(_recipient, _amount);

         payments[senderOfTx].push(
            Payment({
                admin: address(0),
                adminUpdated: false,
                paymentType: 1,
                recipient: _recipient,
                amount: _amount,
                recipientName: bytes8(bytes(_name)),
                paymentID: ++paymentCounter
            })
        );
        return true;
    }

    function updatePayment(
        address _user,
        uint256 _ID,
        uint256 _amount,
        uint8 _type
    ) public onlyAdminOrOwner {
        require(
          _ID > 0 && _amount > 0 && _user != address(0),
          "ID and amount mandatory and user address must be valid"
        );

        address senderOfTx = msg.sender;
        Payment[] storage userPayments = payments[_user];
        
        for (uint256 ii = 0; ii < userPayments.length; ii++) {
            if (userPayments[ii].paymentID == _ID) {
                // replaces:
                // Payment storage payment = userPayments[ii];
                // payment.adminUpdated = true;
                // payment.admin = _user;
                // payment.paymentType = _type;
                // payment.amount = _amount;
                assembly {
                    // Calculate the base slot for the Payment struct
                    // First get the slot of userPayments[ii]
                    let paymentSlot := add(sload(userPayments.slot), mul(ii, 7)) // 7 fields in Payment struct
                    
                    // Update adminUpdated (slot + 6)
                    sstore(add(paymentSlot, 6), 1) // true
                    
                    // Update admin (slot + 3)
                    sstore(add(paymentSlot, 3), _user)
                    
                    // Update paymentType (slot + 5)
                    sstore(add(paymentSlot, 5), _type)
                    
                    // Update amount (slot + 1)
                    sstore(add(paymentSlot, 1), _amount)
                }
                     
                addHistory(_user);
                
                emit PaymentUpdated(
                    senderOfTx,
                    _ID,
                    _amount,
                    string(abi.encodePacked(userPayments[ii].recipientName))
                );
                
                break;
            }
        }
    }

    function addToWhitelist(address _userAddrs, uint256 _tier)
        public
        onlyAdminOrOwner
    {
        require(
            _tier < 255,
            "Tier level not exceed 255"
        );

        whitelist[_userAddrs] = _tier;
        if (_tier > 3) {
            whitelist[_userAddrs] -= _tier;
            whitelist[_userAddrs] = 3;
        } else if (_tier == 1) {
            whitelist[_userAddrs] -= _tier;
            whitelist[_userAddrs] = 1;
        } else if (_tier > 0 && _tier < 3) {
            whitelist[_userAddrs] -= _tier;
            whitelist[_userAddrs] = 2;
        }

        emit AddedToWhitelist(_userAddrs, _tier);
    }


    function whiteTransfer(
        address _recipient,
        uint256 _amount
    ) public checkIfWhiteListed(msg.sender) {
        address senderOfTx = msg.sender;
        
        assembly {
            
          // replaces:
          // require(
          //   balances[senderOfTx] >= _amount && _amount > 3,
          //   "Invalid amount or insufficient balance"
          // );
          
          // Check if _amount > 3
          if iszero(gt(_amount, 3)) {
            // Store error message in memory
            mstore(0x00, 0x20)  // String offset
            mstore(0x20, 0x26)  // String length (38 bytes)
            mstore(0x40, 0x496e76616c696420616d6f756e74206f7220696e73756666696369)  // "Invalid amount or insuffici"
            mstore(0x60, 0x656e742062616c616e6365000000000000000000000000000000)    // "ent balance" + padding
            revert(0x00, 0x80)  // Revert with error message
          }
            
          // Calculate storage slot for balances[senderOfTx]
          mstore(0x00, senderOfTx)
          mstore(0x20, balances.slot)
          let balanceSlot := keccak256(0x00, 0x40)
            
          // Load balance
          let balanceAmount := sload(balanceSlot)
            
          // Check if balance >= _amount
          if iszero(iszero(lt(balanceAmount, _amount))) {
            // Same error message as above
            mstore(0x00, 0x20)
            mstore(0x20, 0x26)
            mstore(0x40, 0x496e76616c696420616d6f756e74206f7220696e73756666696369)
            mstore(0x60, 0x656e742062616c616e6365000000000000000000000000000000)
            revert(0x00, 0x80)
          }

    
          // replaces:
          // uint256 tierValue = whitelist[senderOfTx];
          // uint256 tierValue = whitelist[senderOfTx];
          // balances[senderOfTx] = balances[senderOfTx] - _amount + tierValue;
          // balances[_recipient] = balances[_recipient] + _amount - tierValue;

          // Calculate storage slot for whitelist[senderOfTx]
          mstore(0x00, senderOfTx)
          mstore(0x20, whitelist.slot)
          let tierValueSlot := keccak256(0x00, 0x40)
            
          // Load tierValue
          let tierValue := sload(tierValueSlot)

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
          sstore(add(structSlot, 4), 1)  // 1 for true
            
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
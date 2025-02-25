// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "./Ownable.sol";

contract GasContract is Ownable {
    uint8 private constant tradePercent = 12;
    bool private wasLastOdd = true;
    uint256 private totalSupply = 0; // cannot be updated
    uint256 private paymentCounter = 0;
    address private contractOwner;
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
    mapping(address => bool) private isOddWhitelistUser;
    
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

    function checkForAdmin(address _user) public view returns (bool admin_) {
        bool admin = false;
        for (uint256 ii = 0; ii < administrators.length; ii++) {
            if (administrators[ii] == _user) {
                admin = true;
            }
        }
        return admin;
    }


    function balanceOf(address _user) public view returns (uint256) {
        return balances[_user];
    }


    function addHistory(address _updateAddress)
      public
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
                Payment storage payment = userPayments[ii];
                payment.adminUpdated = true;
                payment.admin = _user;
                payment.paymentType = _type;
                payment.amount = _amount;
                
                addHistory(_user);
                
                emit PaymentUpdated(
                    senderOfTx,
                    _ID,
                    _amount,
                    string(abi.encodePacked(payment.recipientName))
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

        wasLastOdd = !wasLastOdd;
        isOddWhitelistUser[_userAddrs] = wasLastOdd;
        emit AddedToWhitelist(_userAddrs, _tier);
    }


    function whiteTransfer(
        address _recipient,
        uint256 _amount
    ) public checkIfWhiteListed(msg.sender) {
        address senderOfTx = msg.sender;
        
        require(
            balances[senderOfTx] >= _amount && _amount > 3,
            "Invalid amount or insufficient balance"
        );
        
        uint256 tierValue = whitelist[senderOfTx];
        balances[senderOfTx] = balances[senderOfTx] - _amount + tierValue;
        balances[_recipient] = balances[_recipient] + _amount - tierValue;
        
        whiteListStruct[senderOfTx] = ImportantStruct(_amount, 0, 0, 0, true, senderOfTx);
        
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
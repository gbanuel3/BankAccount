pragma solidity >=0.4.22 >=0.8.17;

contract BankAccount {
    event Deposit(
        address indexed user,
        uint256 indexed accountID,
        uint256 value,
        uint256 timestamp
    );
    event WithdrawRequested(
        address indexed user,
        uint256 indexed accountID,
        uint256 indexed withdrawID,
        uint256 amount,
        uint256 timestamp
    );
    event Withdraw(uint256 indexed withdrawID, uint256 timestamp);
    event AccountCreated(address[] owners, uint256 indexed id, uint256 timestamp);

    struct WithdrawRequest {
        address user;
        uint256 amount;
        uint256 approvals;
        bool approved; 
        mapping(address => bool) ownersApproved;
    }

    struct Account {
        address[] owners;
        uint256 balance;
        mapping(uint256 => WithdrawRequest) withdrawRequests;
    }

    mapping(uint256 => Account) accounts;
    mapping(address => uint256[]) userAccounts;

    uint256 nextAccountID; 
    uint256 nextWithdrawID;

    modifier accountOwner(uint256 accountID) {
        bool isOwner = false;
        for (uint256 idx; idx < accounts[accountID].owners.length; idx++) {
            if (accounts[accountID].owners[idx] == msg.sender) {
                isOwner = true;
                break;
            }
        }

        require(isOwner == true, "You are not an owner of this account!");
        _;
    }

    modifier ValidOwners(address[] calldata owners) {
        require(owners.length + 1 <= 4, "Maximum of 4 owners per account");
        for (uint256 i; i < owners.length; i++) {
            if (owners[i]==msg.sender) revert("No Duplicate Owners");
            for (uint256 j=i+1; j < owners.length; j++) {
                if (owners[i] == owners[j]) {
                    revert("No duplicate owners!");
                }
            }
        }
        _;
    }

    modifier SufficientBalance(uint256 accountID, uint256 amount) {
        require(accounts[accountID].balance >= amount, "Insufficient Balance!");
        _;
    }

    modifier CanApprove(uint256 accountID, uint256 withdrawID) {
        require(!accounts[accountID].withdrawRequests[withdrawID].approved, "This request is already approved!");
        require(accounts[accountID].withdrawRequests[withdrawID].user != msg.sender, "You cannot approve this request!");
        require(accounts[accountID].withdrawRequests[withdrawID].user != address(0), "This request does not exist!");
        require(accounts[accountID].withdrawRequests[withdrawID].ownersApproved[msg.sender], "You already approved this request!");
        _;
    }

    modifier CanWithdraw(uint256 accountID, uint256 withdrawID) {
        require(accounts[accountID].withdrawRequests[withdrawID].user == msg.sender, "You did not create this request!");
        require(accounts[accountID].withdrawRequests[withdrawID].approved, "This request is not approved!");
        _;
    }

    function deposit(uint256 accountID) external payable accountOwner(accountID) {
        accounts[accountID].balance += msg.value;
    }

    function createAccount(address[] calldata otherOwners) external ValidOwners(otherOwners){
        address[] memory owners = new address[](otherOwners.length + 1);
        owners[otherOwners.length] = msg.sender;

        uint256 ID = nextAccountID;

        for(uint256 idx; idx < owners.length; idx++) {
            if (idx < owners.length - 1) {
                owners[idx] = otherOwners[idx];
            }

            if (userAccounts[owners[idx]].length > 2) {
                revert("Each user can only have at most 3 accounts!");
            }

            userAccounts[owners[idx]].push(ID);
        }

        accounts[ID].owners = owners;
        nextAccountID++;
        emit AccountCreated(owners, ID, block.timestamp);
    }

    function requestWithdrawal(uint256 accountID, uint256 amount) external accountOwner(accountID) SufficientBalance(accountID, amount) {
        uint256 ID = nextWithdrawID;
        WithdrawRequest storage request = accounts[accountID].withdrawRequests[ID];
        request.user = msg.sender; 
        request.amount = amount;
        nextWithdrawID++;
        emit WithdrawRequested(msg.sender, accountID, ID, amount, block.timestamp);
    }
    
    function approveWithdrawal(uint256 accountID, uint256 withdrawalID) external accountOwner(accountID) CanApprove(accountID, withdrawalID) {
        WithdrawRequest storage request = accounts[accountID].withdrawRequests[withdrawalID];
        request.approvals++;
        request.ownersApproved[msg.sender] = true;

        if (request.approvals == accounts[accountID].owners.length - 1) {
            request.approved = true;
        }
    }

    function withdraw(uint256 accountID, uint256 withdrawID) external CanWithdraw(accountID, withdrawID) {
        uint256 amount = accounts[accountID].withdrawRequests[withdrawID].amount;
        require(accounts[accountID].balance >= amount, "Insufficient Funds!");

        accounts[accountID].balance -= amount;

        delete accounts[accountID].withdrawRequests[withdrawID];
        (bool sent, ) = payable(msg.sender).call{value: amount}("");
        require(sent);

        emit Withdraw(withdrawID, block.timestamp);
    }

    function getBalance(uint256 accountID) public view returns (uint256) {
        return accounts[accountID].balance;
    }

    function getOwners(uint256 accountID) public view returns (address[] memory) {
        return accounts[accountID].owners;
    }

    function getApprovals(uint256 accountID, uint256 withdrawalID) public view returns (uint256) {
        return accounts[accountID].withdrawRequests[withdrawalID].approvals;
    }

    function getAccounts() public view returns (uint256[] memory) {
        return userAccounts[msg.sender];
    }
}

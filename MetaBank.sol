// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract MetaBank {
    // Mapping from user to token to their balance
    mapping(address => mapping(address => uint256)) private _balances;
    // Mapping from user to list of deposited tokens
    mapping(address => address[]) private _userTokens;

    // Event that logs the deposit action
    event Deposited(address indexed token, address indexed user, uint256 amount);

    // Event that logs the withdrawal action
    event Withdrawn(address indexed token, address indexed user, uint256 amount);

    // Function to deposit ERC-20 tokens into the bank contract
    function deposit(address token, uint256 amount) public {
        require(IERC20(token).transferFrom(msg.sender, address(this), amount), "Transfer failed");
        _balances[msg.sender][token] += amount;
        // Add token to user's list of deposited tokens if not already present
        if (!isTokenDeposited(msg.sender, token)) {
            _userTokens[msg.sender].push(token);
        }
        emit Deposited(token, msg.sender, amount);
    }

    // Function to withdraw ERC-20 tokens from the bank contract
    function withdraw(address token, uint256 amount) public {
        require(_balances[msg.sender][token] >= amount, "Insufficient balance");
        _balances[msg.sender][token] -= amount;
        // Remove token address from user's list of deposited tokens if withdrawing all amount
        if (_balances[msg.sender][token] == 0) {
            removeTokenFromUserTokens(msg.sender, token);
        }
        require(IERC20(token).transfer(msg.sender, amount), "Transfer failed");
        emit Withdrawn(token, msg.sender, amount);
    }

    // Function to check the balance of ERC-20 tokens in the bank contract for a specific token
    function tokenBalance(address token) public view returns (uint256) {
        return _balances[msg.sender][token];
    }

    // Function to check if a token is deposited by a user
    function isTokenDeposited(address user, address token) internal view returns (bool) {
        for (uint256 i = 0; i < _userTokens[user].length; i++) {
            if (_userTokens[user][i] == token) {
                return true;
            }
        }
        return false;
    }

    // Function to get the list of deposited tokens for a user
    function getUserTokens() public view returns (address[] memory) {
        return _userTokens[msg.sender];
    }

    // Optional: Function to get the total number of tokens deposited by a user
    function getUserTokenCount(address user) public view returns (uint256) {
        return _userTokens[user].length;
    }

    // Function to get the balances of all deposited tokens for a user
    function getUserBalance() public view returns (address[] memory userTokens, uint256[] memory tokenBalances) {
        uint256 tokenCount = getUserTokenCount(msg.sender);
        userTokens = new address[](tokenCount);
        tokenBalances = new uint256[](tokenCount);

        for (uint256 i = 0; i < tokenCount; i++) {
            address token = _userTokens[msg.sender][i];
            userTokens[i] = token;
            tokenBalances[i] = _balances[msg.sender][token];
        }

        return (userTokens, tokenBalances);
    }

    // Internal function to remove a token address from the user's list of deposited tokens
    function removeTokenFromUserTokens(address user, address token) internal {
        for (uint256 i = 0; i < _userTokens[user].length; i++) {
            if (_userTokens[user][i] == token) {
                // Swap with the last element and then pop
                _userTokens[user][i] = _userTokens[user][_userTokens[user].length - 1];
                _userTokens[user].pop();
                break;
            }
        }
    }
}

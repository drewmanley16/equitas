// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/// @notice Restricted USDC spending for approved SNAP beneficiaries at approved merchants.
contract SNAPSpender is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    IERC20 public immutable usdc;

    mapping(address => bool) public approvedMerchants;
    mapping(address => bool) public approvedUsers;
    mapping(address => uint256) public userAllowance;
    mapping(address => uint256) public userSpent;
    /// @dev Expiry timestamp (unix seconds). 0 means no expiry.
    mapping(address => uint256) public userExpiry;

    error NotApprovedUser();
    error NotApprovedMerchant();
    error AllowanceExceeded();
    error Expired();
    error ZeroAddress();

    constructor(address initialOwner, address usdcToken) Ownable(initialOwner) {
        if (usdcToken == address(0)) revert ZeroAddress();
        usdc = IERC20(usdcToken);
    }

    function setMerchant(address merchant, bool approved) external onlyOwner {
        if (merchant == address(0)) revert ZeroAddress();
        approvedMerchants[merchant] = approved;
    }

    function setUserEligibility(address user, bool eligible, uint256 expiryTimestamp) external onlyOwner {
        if (user == address(0)) revert ZeroAddress();
        approvedUsers[user] = eligible;
        userExpiry[user] = expiryTimestamp;
    }

    function setUserAllowance(address user, uint256 allowance) external onlyOwner {
        if (user == address(0)) revert ZeroAddress();
        userAllowance[user] = allowance;
    }

    /// @notice Pulls USDC into this contract (treasury / program operator must approve first).
    function depositBenefits(uint256 amount) external nonReentrant whenNotPaused onlyOwner {
        usdc.safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @notice Beneficiary pays an approved merchant; USDC is sent from this contract.
    function payMerchant(address merchant, uint256 amount) external nonReentrant whenNotPaused {
        if (!approvedUsers[msg.sender]) revert NotApprovedUser();
        if (!approvedMerchants[merchant]) revert NotApprovedMerchant();
        uint256 exp = userExpiry[msg.sender];
        if (exp != 0 && block.timestamp > exp) revert Expired();
        if (userSpent[msg.sender] + amount > userAllowance[msg.sender]) revert AllowanceExceeded();
        userSpent[msg.sender] += amount;
        usdc.safeTransfer(merchant, amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}

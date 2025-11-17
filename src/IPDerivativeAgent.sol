// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/// @title IPDerivativeAgent
/// @notice Agent (owner) manages a whitelist of (parentIp, childIp, licenseTemplate, licenseId, licensee).
/// Whitelisted licensees may delegate the agent to register derivatives on behalf of the
/// derivative owner. The minting fee is paid in an ERC-20 token. The agent pulls the token
/// from the licensee, approves the RoyaltyModule to pull it from the agent, and then calls
/// LicensingModule.registerDerivative(...). The agent exposes no regular withdraw function;
/// an emergency withdrawal (ERC20/native) is available only to the owner while paused.
///
/// @dev CRITICAL: Licensees must approve this contract to spend the minting fee token before calling registerDerivativeViaAgent.
/// @dev Wildcard Pattern: Setting licensee = address(0) in whitelist allows ANY caller to register that specific (parent, child, template, license) combo.
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @dev Minimal LicensingModule interface used by this agent
interface ILicensingModule {
    /// @notice Register a derivative IP with parent licenses
    /// @param childIpId The derivative IP ID
    /// @param parentIpIds Array of parent IP IDs
    /// @param licenseTermsIds Array of license terms IDs corresponding to each parent
    /// @param licenseTemplate The license template address
    /// @param royaltyContext Additional context for royalty configuration (typically empty bytes)
    /// @param maxMintingFee Maximum minting fee willing to pay (0 = no limit)
    /// @param maxRts Maximum RTS value allowed
    /// @param maxRevenueShare Maximum revenue share percentage allowed
    function registerDerivative(
        address childIpId,
        address[] calldata parentIpIds,
        uint256[] calldata licenseTermsIds,
        address licenseTemplate,
        bytes calldata royaltyContext,
        uint256 maxMintingFee,
        uint32 maxRts,
        uint32 maxRevenueShare
    ) external;

    /// @notice Predict the minting license fee for a given configuration
    /// @param licensorIpId The parent IP ID (licensor)
    /// @param licenseTemplate The license template address
    /// @param licenseTermsId The license terms ID
    /// @param amount Number of license tokens to mint (typically 1 for derivative registration)
    /// @param receiver The receiver of the license tokens (typically the derivative owner)
    /// @param royaltyContext Additional royalty context (typically empty bytes)
    /// @return currencyToken The ERC20 token address for payment (address(0) if no payment required)
    /// @return tokenAmount The amount of tokens required
    function predictMintingLicenseFee(
        address licensorIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        uint256 amount,
        address receiver,
        bytes calldata royaltyContext
    ) external view returns (address currencyToken, uint256 tokenAmount);
}

/// @dev Custom errors for gas-efficient reverts
error IPDerivativeAgent_ZeroAddress();
error IPDerivativeAgent_AlreadyWhitelisted(address parentIpId, address childIpId, address licenseTemplate, uint256 licenseId, address licensee);
error IPDerivativeAgent_NotWhitelisted(address parentIpId, address childIpId, address licenseTemplate, uint256 licenseId, address licensee);
error IPDerivativeAgent_InvalidParams();
error IPDerivativeAgent_BatchLengthMismatch();
error IPDerivativeAgent_FeeTooHigh(uint256 required, uint256 maxAllowed);
error IPDerivativeAgent_EmergencyWithdrawFailed();

contract IPDerivativeAgent is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Licensing module to call for derivative registration
    ILicensingModule public immutable LICENSING_MODULE;

    /// @notice Royalty module address (used for token allowance during fee payment)
    address public immutable ROYALTY_MODULE;

    /// @notice Whitelist mapping keyed by keccak256(parentIpId, childIpId, licenseTemplate, licenseId, licensee)
    /// @dev Use address(0) as licensee for wildcard (allows any caller)
    mapping(bytes32 => bool) private _whitelist;

    /// @notice Emitted when a whitelist entry is added
    event WhitelistedAdded(
        address indexed parentIpId,
        address indexed childIpId,
        address indexed licenseTemplate,
        uint256 licenseId,
        address licensee
    );

    /// @notice Emitted when a whitelist entry is removed
    event WhitelistedRemoved(
        address indexed parentIpId,
        address indexed childIpId,
        address indexed licenseTemplate,
        uint256 licenseId,
        address licensee
    );

    /// @notice Emitted after batch whitelist addition
    event BatchWhitelistAdded(uint256 count);

    /// @notice Emitted after batch whitelist removal
    event BatchWhitelistRemoved(uint256 count);

    /// @notice Emitted on successful derivative registration via agent
    event DerivativeRegistered(
        address indexed caller,
        address indexed childIpId,
        address indexed parentIpId,
        uint256 licenseId,
        address licenseTemplate,
        address currencyToken,
        uint256 tokenAmount,
        uint256 timestamp
    );

    /// @notice Emitted on emergency withdraw
    event EmergencyWithdraw(address indexed token, address indexed to, uint256 amount, uint256 timestamp);

    /// @notice Constructor
    /// @param owner Address to transfer ownership to (if non-zero). Otherwise deployer remains owner.
    /// @param _licensingModule LicensingModule address (must be non-zero)
    /// @param _royaltyModule RoyaltyModule address (must be non-zero)
    constructor(address owner, address _licensingModule, address _royaltyModule) {
        if (_licensingModule == address(0) || _royaltyModule == address(0)) revert IPDerivativeAgent_ZeroAddress();
        LICENSING_MODULE = ILicensingModule(_licensingModule);
        ROYALTY_MODULE = _royaltyModule;

        if (owner != address(0) && owner != msg.sender) {
            transferOwnership(owner);
        }
    }

    /// -----------------------------------------------------------------------
    /// Whitelist Management
    /// -----------------------------------------------------------------------

    /// @dev Compute whitelist key from parameters
    /// @param parentIpId Parent IP address
    /// @param childIpId Child/derivative IP address
    /// @param licenseTemplate License template address
    /// @param licenseId License terms ID
    /// @param licensee Specific licensee address (or address(0) for wildcard)
    /// @return Keccak256 hash of the packed parameters
    function _whitelistKey(
        address parentIpId,
        address childIpId,
        address licenseTemplate,
        uint256 licenseId,
        address licensee
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(parentIpId, childIpId, licenseTemplate, licenseId, licensee));
    }

    /// @notice Add a single whitelist entry. Callable by owner and internally.
    /// @dev Setting licensee = address(0) creates a wildcard entry (any caller can register)
    /// @param parentIpId Parent IP address (must be non-zero)
    /// @param childIpId Child/derivative IP address (must be non-zero)
    /// @param licensee Specific licensee address, or address(0) for wildcard
    /// @param licenseTemplate License template address (must be non-zero)
    /// @param licenseId License terms ID
    function addToWhitelist(
        address parentIpId,
        address childIpId,
        address licensee,
        address licenseTemplate,
        uint256 licenseId
    ) public onlyOwner {
        if (parentIpId == address(0) || childIpId == address(0) || licenseTemplate == address(0)) {
            revert IPDerivativeAgent_InvalidParams();
        }

        bytes32 key = _whitelistKey(parentIpId, childIpId, licenseTemplate, licenseId, licensee);
        if (_whitelist[key]) {
            revert IPDerivativeAgent_AlreadyWhitelisted(parentIpId, childIpId, licenseTemplate, licenseId, licensee);
        }
        _whitelist[key] = true;
        emit WhitelistedAdded(parentIpId, childIpId, licenseTemplate, licenseId, licensee);
    }

    /// @notice Remove a single whitelist entry. Callable by owner and internally.
    /// @param parentIpId Parent IP address (must be non-zero)
    /// @param childIpId Child/derivative IP address (must be non-zero)
    /// @param licensee Specific licensee address (or address(0) if removing wildcard)
    /// @param licenseTemplate License template address (must be non-zero)
    /// @param licenseId License terms ID
    function removeFromWhitelist(
        address parentIpId,
        address childIpId,
        address licensee,
        address licenseTemplate,
        uint256 licenseId
    ) public onlyOwner {
        if (parentIpId == address(0) || childIpId == address(0) || licenseTemplate == address(0)) {
            revert IPDerivativeAgent_InvalidParams();
        }

        bytes32 key = _whitelistKey(parentIpId, childIpId, licenseTemplate, licenseId, licensee);
        if (!_whitelist[key]) {
            revert IPDerivativeAgent_NotWhitelisted(parentIpId, childIpId, licenseTemplate, licenseId, licensee);
        }
        _whitelist[key] = false;
        emit WhitelistedRemoved(parentIpId, childIpId, licenseTemplate, licenseId, licensee);
    }

    /// @notice Batch add whitelist entries. Reverts if any entry is invalid or already exists.
    /// @dev All arrays must have the same length
    /// @param parentIpIds Array of parent IP addresses
    /// @param childIpIds Array of child/derivative IP addresses
    /// @param licensees Array of licensee addresses (use address(0) for wildcard)
    /// @param licenseTemplates Array of license template addresses
    /// @param licenseIds Array of license terms IDs
    function addToWhitelistBatch(
        address[] calldata parentIpIds,
        address[] calldata childIpIds,
        address[] calldata licensees,
        address[] calldata licenseTemplates,
        uint256[] calldata licenseIds
    ) external onlyOwner {
        uint256 n = parentIpIds.length;
        if (childIpIds.length != n || licensees.length != n || licenseTemplates.length != n || licenseIds.length != n) {
            revert IPDerivativeAgent_BatchLengthMismatch();
        }
        for (uint256 i = 0; i < n; ) {
            address parentIpId = parentIpIds[i];
            address childIpId = childIpIds[i];
            address licenseTemplate = licenseTemplates[i];
            address licensee = licensees[i];
            uint256 licenseId = licenseIds[i];

            if (parentIpId == address(0) || childIpId == address(0) || licenseTemplate == address(0)) {
                revert IPDerivativeAgent_InvalidParams();
            }

            bytes32 key = _whitelistKey(parentIpId, childIpId, licenseTemplate, licenseId, licensee);
            if (_whitelist[key]) {
                revert IPDerivativeAgent_AlreadyWhitelisted(parentIpId, childIpId, licenseTemplate, licenseId, licensee);
            }
            _whitelist[key] = true;
            emit WhitelistedAdded(parentIpId, childIpId, licenseTemplate, licenseId, licensee);

            unchecked { ++i; }
        }
        emit BatchWhitelistAdded(n);
    }

    /// @notice Batch remove whitelist entries. Reverts if any entry doesn't exist.
    /// @dev All arrays must have the same length
    /// @param parentIpIds Array of parent IP addresses
    /// @param childIpIds Array of child/derivative IP addresses
    /// @param licensees Array of licensee addresses
    /// @param licenseTemplates Array of license template addresses
    /// @param licenseIds Array of license terms IDs
    function removeFromWhitelistBatch(
        address[] calldata parentIpIds,
        address[] calldata childIpIds,
        address[] calldata licensees,
        address[] calldata licenseTemplates,
        uint256[] calldata licenseIds
    ) external onlyOwner {
        uint256 n = parentIpIds.length;
        if (childIpIds.length != n || licensees.length != n || licenseTemplates.length != n || licenseIds.length != n) {
            revert IPDerivativeAgent_BatchLengthMismatch();
        }
        for (uint256 i = 0; i < n; ) {
            address parentIpId = parentIpIds[i];
            address childIpId = childIpIds[i];
            address licenseTemplate = licenseTemplates[i];
            address licensee = licensees[i];
            uint256 licenseId = licenseIds[i];

            if (parentIpId == address(0) || childIpId == address(0) || licenseTemplate == address(0)) {
                revert IPDerivativeAgent_InvalidParams();
            }

            bytes32 key = _whitelistKey(parentIpId, childIpId, licenseTemplate, licenseId, licensee);
            if (!_whitelist[key]) {
                revert IPDerivativeAgent_NotWhitelisted(parentIpId, childIpId, licenseTemplate, licenseId, licensee);
            }
            _whitelist[key] = false;
            emit WhitelistedRemoved(parentIpId, childIpId, licenseTemplate, licenseId, licensee);

            unchecked { ++i; }
        }
        emit BatchWhitelistRemoved(n);
    }

    /// @notice Convenience function to add a wildcard whitelist entry (allows any caller)
    /// @param parentIpId Parent IP address
    /// @param childIpId Child/derivative IP address
    /// @param licenseTemplate License template address
    /// @param licenseId License terms ID
    function addWildcardToWhitelist(
        address parentIpId,
        address childIpId,
        address licenseTemplate,
        uint256 licenseId
    ) external onlyOwner {
        addToWhitelist(parentIpId, childIpId, address(0), licenseTemplate, licenseId);
    }

    /// @notice Convenience function to remove a wildcard whitelist entry
    /// @param parentIpId Parent IP address
    /// @param childIpId Child/derivative IP address
    /// @param licenseTemplate License template address
    /// @param licenseId License terms ID
    function removeWildcardFromWhitelist(
        address parentIpId,
        address childIpId,
        address licenseTemplate,
        uint256 licenseId
    ) external onlyOwner {
        removeFromWhitelist(parentIpId, childIpId, address(0), licenseTemplate, licenseId);
    }

    /// @notice Check if a licensee is whitelisted (exact match or wildcard)
    /// @param parentIpId Parent IP address
    /// @param childIpId Child/derivative IP address
    /// @param licenseTemplate License template address
    /// @param licenseId License terms ID
    /// @param licensee Licensee address to check
    /// @return True if exact licensee is whitelisted OR wildcard (address(0)) is whitelisted
    function isWhitelisted(
        address parentIpId,
        address childIpId,
        address licenseTemplate,
        uint256 licenseId,
        address licensee
    ) public view returns (bool) {
        bytes32 keyExact = _whitelistKey(parentIpId, childIpId, licenseTemplate, licenseId, licensee);
        if (_whitelist[keyExact]) return true;
        bytes32 keyWildcard = _whitelistKey(parentIpId, childIpId, licenseTemplate, licenseId, address(0));
        return _whitelist[keyWildcard];
    }

    /// @notice Helper function to compute the whitelist key for off-chain use
    /// @param parentIpId Parent IP address
    /// @param childIpId Child/derivative IP address
    /// @param licenseTemplate License template address
    /// @param licenseId License terms ID
    /// @param licensee Licensee address
    /// @return The computed whitelist key
    function getWhitelistKey(
        address parentIpId,
        address childIpId,
        address licenseTemplate,
        uint256 licenseId,
        address licensee
    ) external pure returns (bytes32) {
        return _whitelistKey(parentIpId, childIpId, licenseTemplate, licenseId, licensee);
    }

    /// @notice Helper function to return raw whitelist status by key
    /// @param key The whitelist key
    /// @return True if the key is whitelisted
    function getWhitelistStatusByKey(bytes32 key) external view returns (bool) {
        return _whitelist[key];
    }

    /// -----------------------------------------------------------------------
    /// Pausable Controls
    /// -----------------------------------------------------------------------

    /// @notice Pause the contract (blocks registerDerivativeViaAgent calls). Only callable by owner.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause the contract. Only callable by owner.
    function unpause() external onlyOwner {
        _unpause();
    }

    /// -----------------------------------------------------------------------
    /// Derivative Registration (Delegated by Licensee)
    /// -----------------------------------------------------------------------

    /// @notice Register a derivative via IPDerivativeAgent
    /// @dev CRITICAL: The licensee (msg.sender) must have approved this agent to transfer
    ///      the minting fee token BEFORE calling this function. Use ERC20.approve(agentAddress, feeAmount).
    /// @dev The agent will:
    ///      1. Check whitelist authorization
    ///      2. Predict the minting fee
    ///      3. Validate fee against maxMintingFee (if specified)
    ///      4. Pull fee tokens from licensee
    ///      5. Approve RoyaltyModule to spend fee tokens
    ///      6. Call LicensingModule.registerDerivative
    ///      7. Clean up any remaining allowance
    /// @param childIpId The derivative IP ID (must be non-zero)
    /// @param parentIpId The parent IP ID (must be non-zero)
    /// @param licenseId The license terms ID in the license template
    /// @param licenseTemplate The license template address (must be non-zero)
    /// @param maxMintingFee Maximum minting fee willing to pay. Use 0 for no limit (per LicensingModule conventions).
    function registerDerivativeViaAgent(
        address childIpId,
        address parentIpId,
        uint256 licenseId,
        address licenseTemplate,
        uint256 maxMintingFee
    ) external nonReentrant whenNotPaused {
        if (childIpId == address(0) || parentIpId == address(0) || licenseTemplate == address(0)) {
            revert IPDerivativeAgent_InvalidParams();
        }

        // Check whitelist (exact match or wildcard)
        if (!isWhitelisted(parentIpId, childIpId, licenseTemplate, licenseId, msg.sender)) {
            revert IPDerivativeAgent_NotWhitelisted(parentIpId, childIpId, licenseTemplate, licenseId, msg.sender);
        }

        bytes memory royaltyContext = "";

        // Predict minting fee for a single license token (amount = 1), receiver = msg.sender (licensee/derivative owner)
        (address currencyToken, uint256 tokenAmount) = LICENSING_MODULE.predictMintingLicenseFee(
            parentIpId,
            licenseTemplate,
            licenseId,
            1,
            msg.sender,
            royaltyContext
        );

        // Validate fee against maxMintingFee if caller specified a non-zero maximum
        if (maxMintingFee != 0 && tokenAmount > maxMintingFee) {
            revert IPDerivativeAgent_FeeTooHigh(tokenAmount, maxMintingFee);
        }

        // Prepare arrays for LicensingModule call (single parent)
        address[] memory parents = new address[](1);
        parents[0] = parentIpId;
        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = licenseId;
        uint32 maxRts = 0;
        uint32 maxRevenueShare = 0;

        // Handle token payment if required
        if (currencyToken != address(0) && tokenAmount > 0) {
            IERC20 token = IERC20(currencyToken);

            // Transfer tokens from licensee to this contract
            token.safeTransferFrom(msg.sender, address(this), tokenAmount);

            // Increase allowance for RoyaltyModule to pull tokens during registerDerivative
            token.safeIncreaseAllowance(ROYALTY_MODULE, tokenAmount);
        }

        // Call LicensingModule to register derivative
        // The RoyaltyModule will pull the minting fee tokens from this contract during this call
        LICENSING_MODULE.registerDerivative(
            childIpId,
            parents,
            licenseTermsIds,
            licenseTemplate,
            royaltyContext,
            maxMintingFee,
            maxRts,
            maxRevenueShare
        );

        // Clean up any remaining allowance for RoyaltyModule
        if (currencyToken != address(0) && tokenAmount > 0) {
            IERC20 token = IERC20(currencyToken);
            uint256 remainingAllowance = token.allowance(address(this), ROYALTY_MODULE);
            if (remainingAllowance > 0) {
                token.safeApprove(ROYALTY_MODULE, 0);
            }
        }

        emit DerivativeRegistered(
            msg.sender,
            childIpId,
            parentIpId,
            licenseId,
            licenseTemplate,
            currencyToken,
            tokenAmount,
            block.timestamp
        );
    }

    /// -----------------------------------------------------------------------
    /// Emergency Recovery
    /// -----------------------------------------------------------------------

    /// @notice Emergency withdraw of stuck funds. Only callable by owner while paused.
    /// @dev This function is only available when the contract is paused to prevent accidental
    ///      withdrawal during normal operations. Use pause() first, then call this function.
    /// @param token Token address (address(0) for native ETH/IP)
    /// @param to Destination address (must be non-zero and not this contract)
    /// @param amount Amount to transfer (in wei for native, or token smallest unit)
    function emergencyWithdraw(address token, address to, uint256 amount) external onlyOwner whenPaused nonReentrant {
        if (to == address(0) || to == address(this)) revert IPDerivativeAgent_InvalidParams();
        
        if (token == address(0)) {
            // Withdraw native token (ETH/IP)
            (bool success, ) = payable(to).call{value: amount}("");
            if (!success) revert IPDerivativeAgent_EmergencyWithdrawFailed();
        } else {
            // Withdraw ERC20 token
            IERC20(token).safeTransfer(to, amount);
        }
        
        emit EmergencyWithdraw(token, to, amount, block.timestamp);
    }

    /// -----------------------------------------------------------------------
    /// Receive / Fallback (Accept incoming tokens)
    /// -----------------------------------------------------------------------

    /// @notice Allow contract to receive native tokens
    receive() external payable {}

    /// @notice Allow contract to receive calls with data
    fallback() external payable {}
}
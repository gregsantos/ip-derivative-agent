// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "../src/IPDerivativeAgent.sol";
import "./mocks/MockLicensingModule.sol";
import "./mocks/MockERC20.sol";

contract IPDerivativeAgentTest is Test {
    IPDerivativeAgent public agent;
    MockLicensingModule public licensingModule;
    MockERC20 public token;
    
    address public owner = address(0x1);
    address public royaltyModule = address(0x2);
    address public parentIp = address(0x3);
    address public childIp = address(0x4);
    address public licenseTemplate = address(0x5);
    address public licensee = address(0x6);
    uint256 public licenseTermsId = 1;
    
    event WhitelistedAdded(
        address indexed parentIpId,
        address indexed childIpId,
        address indexed licenseTemplate,
        uint256 licenseTermsId,
        address licensee
    );
    
    event DerivativeRegistered(
        address indexed caller,
        address indexed childIpId,
        address indexed parentIpId,
        uint256 licenseTermsId,
        address licenseTemplate,
        address currencyToken,
        uint256 tokenAmount,
        uint256 timestamp
    );
    
    function setUp() public {
        // Deploy mocks
        licensingModule = new MockLicensingModule();
        token = new MockERC20("Mock Token", "MTK");
        
        // Deploy agent
        vm.prank(owner);
        agent = new IPDerivativeAgent(owner, address(licensingModule), royaltyModule);
        
        // Mint tokens to licensee
        token.mint(licensee, 1000 ether);
    }
    
    // ========== Constructor Tests ==========
    
    function test_Constructor_Success() public view {
        assertEq(address(agent.LICENSING_MODULE()), address(licensingModule));
        assertEq(agent.ROYALTY_MODULE(), royaltyModule);
        assertEq(agent.owner(), owner);
    }
    
    function test_Constructor_RevertIf_ZeroLicensingModule() public {
        vm.expectRevert(IPDerivativeAgent_ZeroAddress.selector);
        new IPDerivativeAgent(owner, address(0), royaltyModule);
    }
    
    function test_Constructor_RevertIf_ZeroRoyaltyModule() public {
        vm.expectRevert(IPDerivativeAgent_ZeroAddress.selector);
        new IPDerivativeAgent(owner, address(licensingModule), address(0));
    }
    
    function test_Constructor_RevertIf_ZeroOwner() public {
        vm.expectRevert(IPDerivativeAgent_ZeroAddress.selector);
        new IPDerivativeAgent(address(0), address(licensingModule), royaltyModule);
    }
    
    // ========== Whitelist Management Tests ==========
    
    function test_AddToWhitelist_Success() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit WhitelistedAdded(parentIp, childIp, licenseTemplate, licenseTermsId, licensee);
        agent.addToWhitelist(parentIp, childIp, licensee, licenseTemplate, licenseTermsId);
        
        assertTrue(agent.isWhitelisted(parentIp, childIp, licenseTemplate, licenseTermsId, licensee));
    }
    
    function test_AddToWhitelist_RevertIf_NotOwner() public {
        vm.prank(address(0x999));
        vm.expectRevert("Ownable: caller is not the owner");
        agent.addToWhitelist(parentIp, childIp, licensee, licenseTemplate, licenseTermsId);
    }
    
    function test_AddToWhitelist_RevertIf_ZeroParentIp() public {
        vm.prank(owner);
        vm.expectRevert(IPDerivativeAgent_InvalidParams.selector);
        agent.addToWhitelist(address(0), childIp, licensee, licenseTemplate, licenseTermsId);
    }
    
    function test_AddToWhitelist_RevertIf_ZeroLicenseId() public {
        vm.prank(owner);
        vm.expectRevert(IPDerivativeAgent_InvalidParams.selector);
        agent.addToWhitelist(parentIp, childIp, licensee, licenseTemplate, 0);
    }
    
    function test_AddToWhitelist_RevertIf_AlreadyWhitelisted() public {
        vm.startPrank(owner);
        agent.addToWhitelist(parentIp, childIp, licensee, licenseTemplate, licenseTermsId);
        
        vm.expectRevert(
            abi.encodeWithSelector(
                IPDerivativeAgent_AlreadyWhitelisted.selector,
                parentIp,
                childIp,
                licenseTemplate,
                licenseTermsId,
                licensee
            )
        );
        agent.addToWhitelist(parentIp, childIp, licensee, licenseTemplate, licenseTermsId);
        vm.stopPrank();
    }
    
    function test_AddWildcardToWhitelist_Success() public {
        vm.prank(owner);
        agent.addWildcardToWhitelist(parentIp, childIp, licenseTemplate, licenseTermsId);
        
        assertTrue(agent.isWhitelisted(parentIp, childIp, licenseTemplate, licenseTermsId, address(0x999)));
        assertTrue(agent.isWhitelisted(parentIp, childIp, licenseTemplate, licenseTermsId, licensee));
    }
    
    function test_RemoveFromWhitelist_Success() public {
        vm.startPrank(owner);
        agent.addToWhitelist(parentIp, childIp, licensee, licenseTemplate, licenseTermsId);
        agent.removeFromWhitelist(parentIp, childIp, licensee, licenseTemplate, licenseTermsId);
        vm.stopPrank();
        
        assertFalse(agent.isWhitelisted(parentIp, childIp, licenseTemplate, licenseTermsId, licensee));
    }
    
    function test_RemoveFromWhitelist_RevertIf_ZeroLicenseTermsId() public {
        vm.startPrank(owner);
        agent.addToWhitelist(parentIp, childIp, licensee, licenseTemplate, licenseTermsId);
        
        vm.expectRevert(IPDerivativeAgent_InvalidParams.selector);
        agent.removeFromWhitelist(parentIp, childIp, licensee, licenseTemplate, 0);
        vm.stopPrank();
    }
    
    function test_BatchAddToWhitelist_Success() public {
        address[] memory parentIps = new address[](2);
        address[] memory childIps = new address[](2);
        address[] memory licensees = new address[](2);
        address[] memory licenseTemplates = new address[](2);
        uint256[] memory licenseTermsIds = new uint256[](2);
        
        parentIps[0] = parentIp;
        parentIps[1] = address(0x10);
        childIps[0] = childIp;
        childIps[1] = address(0x11);
        licensees[0] = licensee;
        licensees[1] = address(0x12);
        licenseTemplates[0] = licenseTemplate;
        licenseTemplates[1] = address(0x13);
        licenseTermsIds[0] = 1;
        licenseTermsIds[1] = 2;
        
        vm.prank(owner);
        agent.addToWhitelistBatch(parentIps, childIps, licensees, licenseTemplates, licenseTermsIds);
        
        assertTrue(agent.isWhitelisted(parentIps[0], childIps[0], licenseTemplates[0], licenseTermsIds[0], licensees[0]));
        assertTrue(agent.isWhitelisted(parentIps[1], childIps[1], licenseTemplates[1], licenseTermsIds[1], licensees[1]));
    }
    
    function test_BatchAddToWhitelist_RevertIf_LengthMismatch() public {
        address[] memory parentIps = new address[](2);
        address[] memory childIps = new address[](1); // Different length
        address[] memory licensees = new address[](2);
        address[] memory licenseTemplates = new address[](2);
        uint256[] memory licenseTermsIds = new uint256[](2);
        
        vm.prank(owner);
        vm.expectRevert(IPDerivativeAgent_BatchLengthMismatch.selector);
        agent.addToWhitelistBatch(parentIps, childIps, licensees, licenseTemplates, licenseTermsIds);
    }
    
    function test_BatchAddToWhitelist_RevertIf_ZeroLicenseTermsId() public {
        address[] memory parentIps = new address[](2);
        address[] memory childIps = new address[](2);
        address[] memory licensees = new address[](2);
        address[] memory licenseTemplates = new address[](2);
        uint256[] memory licenseTermsIds = new uint256[](2);
        
        parentIps[0] = parentIp;
        parentIps[1] = address(0x10);
        childIps[0] = childIp;
        childIps[1] = address(0x11);
        licensees[0] = licensee;
        licensees[1] = address(0x12);
        licenseTemplates[0] = licenseTemplate;
        licenseTemplates[1] = address(0x13);
        licenseTermsIds[0] = 1;
        licenseTermsIds[1] = 0; // Zero license terms ID
        
        vm.prank(owner);
        vm.expectRevert(IPDerivativeAgent_InvalidParams.selector);
        agent.addToWhitelistBatch(parentIps, childIps, licensees, licenseTemplates, licenseTermsIds);
    }
    
    function test_BatchRemoveFromWhitelist_Success() public {
        address[] memory parentIps = new address[](2);
        address[] memory childIps = new address[](2);
        address[] memory licensees = new address[](2);
        address[] memory licenseTemplates = new address[](2);
        uint256[] memory licenseTermsIds = new uint256[](2);
        
        parentIps[0] = parentIp;
        parentIps[1] = address(0x10);
        childIps[0] = childIp;
        childIps[1] = address(0x11);
        licensees[0] = licensee;
        licensees[1] = address(0x12);
        licenseTemplates[0] = licenseTemplate;
        licenseTemplates[1] = address(0x13);
        licenseTermsIds[0] = 1;
        licenseTermsIds[1] = 2;
        
        vm.startPrank(owner);
        // Add entries first
        agent.addToWhitelistBatch(parentIps, childIps, licensees, licenseTemplates, licenseTermsIds);
        
        // Remove entries
        agent.removeFromWhitelistBatch(parentIps, childIps, licensees, licenseTemplates, licenseTermsIds);
        vm.stopPrank();
        
        // Verify removed
        assertFalse(agent.isWhitelisted(parentIps[0], childIps[0], licenseTemplates[0], licenseTermsIds[0], licensees[0]));
        assertFalse(agent.isWhitelisted(parentIps[1], childIps[1], licenseTemplates[1], licenseTermsIds[1], licensees[1]));
    }
    
    function test_BatchRemoveFromWhitelist_RevertIf_ZeroLicenseTermsId() public {
        address[] memory parentIps = new address[](2);
        address[] memory childIps = new address[](2);
        address[] memory licensees = new address[](2);
        address[] memory licenseTemplates = new address[](2);
        uint256[] memory licenseTermsIds = new uint256[](2);
        
        parentIps[0] = parentIp;
        parentIps[1] = address(0x10);
        childIps[0] = childIp;
        childIps[1] = address(0x11);
        licensees[0] = licensee;
        licensees[1] = address(0x12);
        licenseTemplates[0] = licenseTemplate;
        licenseTemplates[1] = address(0x13);
        licenseTermsIds[0] = 1;
        licenseTermsIds[1] = 2;
        
        vm.startPrank(owner);
        // Add entries first
        agent.addToWhitelistBatch(parentIps, childIps, licensees, licenseTemplates, licenseTermsIds);
        
        // Try to remove with zero license terms ID
        licenseTermsIds[1] = 0;
        vm.expectRevert(IPDerivativeAgent_InvalidParams.selector);
        agent.removeFromWhitelistBatch(parentIps, childIps, licensees, licenseTemplates, licenseTermsIds);
        vm.stopPrank();
    }
    
    // ========== Registration Tests ==========
    
    function test_RegisterDerivative_Success_WithFee() public {
        uint256 fee = 10 ether;
        licensingModule.setMintingFee(address(token), fee);
        
        // Whitelist the licensee
        vm.prank(owner);
        agent.addToWhitelist(parentIp, childIp, licensee, licenseTemplate, licenseTermsId);
        
        // Approve agent to spend tokens
        vm.prank(licensee);
        token.approve(address(agent), fee);
        
        // Register derivative
        vm.prank(licensee);
        vm.expectEmit(true, true, true, true);
        emit DerivativeRegistered(
            licensee,
            childIp,
            parentIp,
            licenseTermsId,
            licenseTemplate,
            address(token),
            fee,
            block.timestamp
        );
        agent.registerDerivativeViaAgent(childIp, parentIp, licenseTermsId, licenseTemplate, 0);
        
        // Check that tokens were transferred
        assertEq(token.balanceOf(licensee), 1000 ether - fee);
    }
    
    function test_RegisterDerivative_Success_NoFee() public {
        licensingModule.setMintingFee(address(0), 0);
        
        // Whitelist the licensee
        vm.prank(owner);
        agent.addToWhitelist(parentIp, childIp, licensee, licenseTemplate, licenseTermsId);
        
        // Register derivative
        vm.prank(licensee);
        agent.registerDerivativeViaAgent(childIp, parentIp, licenseTermsId, licenseTemplate, 0);
        
        // Check that no tokens were transferred
        assertEq(token.balanceOf(licensee), 1000 ether);
    }
    
    function test_RegisterDerivative_Success_WithWildcard() public {
        uint256 fee = 5 ether;
        licensingModule.setMintingFee(address(token), fee);
        
        // Whitelist with wildcard
        vm.prank(owner);
        agent.addWildcardToWhitelist(parentIp, childIp, licenseTemplate, licenseTermsId);
        
        // Any address can register now
        address anyAddress = address(0x999);
        token.mint(anyAddress, 100 ether);
        
        vm.startPrank(anyAddress);
        token.approve(address(agent), fee);
        agent.registerDerivativeViaAgent(childIp, parentIp, licenseTermsId, licenseTemplate, 0);
        vm.stopPrank();
        
        assertEq(token.balanceOf(anyAddress), 100 ether - fee);
    }
    
    function test_RegisterDerivative_RevertIf_NotWhitelisted() public {
        vm.prank(licensee);
        vm.expectRevert(
            abi.encodeWithSelector(
                IPDerivativeAgent_NotWhitelisted.selector,
                parentIp,
                childIp,
                licenseTemplate,
                licenseTermsId,
                licensee
            )
        );
        agent.registerDerivativeViaAgent(childIp, parentIp, licenseTermsId, licenseTemplate, 0);
    }
    
    function test_RegisterDerivative_RevertIf_FeeTooHigh() public {
        uint256 fee = 10 ether;
        uint256 maxFee = 5 ether;
        licensingModule.setMintingFee(address(token), fee);
        
        vm.prank(owner);
        agent.addToWhitelist(parentIp, childIp, licensee, licenseTemplate, licenseTermsId);
        
        vm.prank(licensee);
        token.approve(address(agent), fee);
        
        vm.prank(licensee);
        vm.expectRevert(
            abi.encodeWithSelector(IPDerivativeAgent_FeeTooHigh.selector, fee, maxFee)
        );
        agent.registerDerivativeViaAgent(childIp, parentIp, licenseTermsId, licenseTemplate, maxFee);
    }
    
    function test_RegisterDerivative_RevertIf_Paused() public {
        vm.prank(owner);
        agent.addToWhitelist(parentIp, childIp, licensee, licenseTemplate, licenseTermsId);
        
        vm.prank(owner);
        agent.pause();
        
        vm.prank(licensee);
        vm.expectRevert("Pausable: paused");
        agent.registerDerivativeViaAgent(childIp, parentIp, licenseTermsId, licenseTemplate, 0);
    }
    
    // ========== Pausable Tests ==========
    
    function test_Pause_Success() public {
        vm.prank(owner);
        agent.pause();
        assertTrue(agent.paused());
    }
    
    function test_Unpause_Success() public {
        vm.startPrank(owner);
        agent.pause();
        agent.unpause();
        vm.stopPrank();
        assertFalse(agent.paused());
    }
    
    function test_Pause_RevertIf_NotOwner() public {
        vm.prank(address(0x999));
        vm.expectRevert("Ownable: caller is not the owner");
        agent.pause();
    }
    
    // ========== Emergency Withdraw Tests ==========
    
    function test_EmergencyWithdraw_ERC20_Success() public {
        // Send tokens to agent
        token.mint(address(agent), 100 ether);
        
        vm.startPrank(owner);
        agent.pause();
        agent.emergencyWithdraw(address(token), owner, 100 ether);
        vm.stopPrank();
        
        assertEq(token.balanceOf(owner), 100 ether);
        assertEq(token.balanceOf(address(agent)), 0);
    }
    
    function test_EmergencyWithdraw_Native_Success() public {
        // Send native tokens to agent
        vm.deal(address(agent), 10 ether);
        
        uint256 ownerBalanceBefore = owner.balance;
        
        vm.startPrank(owner);
        agent.pause();
        agent.emergencyWithdraw(address(0), owner, 10 ether);
        vm.stopPrank();
        
        assertEq(owner.balance, ownerBalanceBefore + 10 ether);
        assertEq(address(agent).balance, 0);
    }
    
    function test_EmergencyWithdraw_RevertIf_NotPaused() public {
        token.mint(address(agent), 100 ether);
        
        vm.prank(owner);
        vm.expectRevert("Pausable: not paused");
        agent.emergencyWithdraw(address(token), owner, 100 ether);
    }
    
    function test_EmergencyWithdraw_RevertIf_ToIsContract() public {
        token.mint(address(agent), 100 ether);
        
        vm.startPrank(owner);
        agent.pause();
        vm.expectRevert(IPDerivativeAgent_InvalidParams.selector);
        agent.emergencyWithdraw(address(token), address(agent), 100 ether);
        vm.stopPrank();
    }
    
    // ========== View Functions Tests ==========
    
    function test_GetWhitelistKey() public view {
        bytes32 key = agent.getWhitelistKey(parentIp, childIp, licenseTemplate, licenseTermsId, licensee);
        assertEq(
            key,
            keccak256(abi.encodePacked(parentIp, childIp, licenseTemplate, licenseTermsId, licensee))
        );
    }
    
    function test_GetWhitelistStatusByKey() public {
        vm.prank(owner);
        agent.addToWhitelist(parentIp, childIp, licensee, licenseTemplate, licenseTermsId);
        
        bytes32 key = agent.getWhitelistKey(parentIp, childIp, licenseTemplate, licenseTermsId, licensee);
        assertTrue(agent.getWhitelistStatusByKey(key));
    }
}
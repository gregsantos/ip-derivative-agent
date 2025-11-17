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
    
    address public yokoa = address(0x1);
    address public royaltyModule = address(0x2);
    address public parentIp = address(0x3);
    address public childIp = address(0x4);
    address public licenseTemplate = address(0x5);
    address public licensee = address(0x6);
    uint256 public licenseId = 1;
    
    event WhitelistedAdded(
        address indexed parentIpId,
        address indexed childIpId,
        address indexed licenseTemplate,
        uint256 licenseId,
        address licensee
    );
    
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
    
    function setUp() public {
        // Deploy mocks
        licensingModule = new MockLicensingModule();
        token = new MockERC20("Mock Token", "MTK");
        
        // Deploy agent
        vm.prank(yokoa);
        agent = new IPDerivativeAgent(yokoa, address(licensingModule), royaltyModule);
        
        // Mint tokens to licensee
        token.mint(licensee, 1000 ether);
    }
    
    // ========== Constructor Tests ==========
    
    function test_Constructor_Success() public view {
        assertEq(address(agent.LICENSING_MODULE()), address(licensingModule));
        assertEq(agent.ROYALTY_MODULE(), royaltyModule);
        assertEq(agent.owner(), yokoa);
    }
    
    function test_Constructor_RevertIf_ZeroLicensingModule() public {
        vm.expectRevert(IPDerivativeAgent_ZeroAddress.selector);
        new IPDerivativeAgent(yokoa, address(0), royaltyModule);
    }
    
    function test_Constructor_RevertIf_ZeroRoyaltyModule() public {
        vm.expectRevert(IPDerivativeAgent_ZeroAddress.selector);
        new IPDerivativeAgent(yokoa, address(licensingModule), address(0));
    }
    
    // ========== Whitelist Management Tests ==========
    
    function test_AddToWhitelist_Success() public {
        vm.prank(yokoa);
        vm.expectEmit(true, true, true, true);
        emit WhitelistedAdded(parentIp, childIp, licenseTemplate, licenseId, licensee);
        agent.addToWhitelist(parentIp, childIp, licensee, licenseTemplate, licenseId);
        
        assertTrue(agent.isWhitelisted(parentIp, childIp, licenseTemplate, licenseId, licensee));
    }
    
    function test_AddToWhitelist_RevertIf_NotOwner() public {
        vm.prank(address(0x999));
        vm.expectRevert("Ownable: caller is not the owner");
        agent.addToWhitelist(parentIp, childIp, licensee, licenseTemplate, licenseId);
    }
    
    function test_AddToWhitelist_RevertIf_ZeroParentIp() public {
        vm.prank(yokoa);
        vm.expectRevert(IPDerivativeAgent_InvalidParams.selector);
        agent.addToWhitelist(address(0), childIp, licensee, licenseTemplate, licenseId);
    }
    
    function test_AddToWhitelist_RevertIf_AlreadyWhitelisted() public {
        vm.startPrank(yokoa);
        agent.addToWhitelist(parentIp, childIp, licensee, licenseTemplate, licenseId);
        
        vm.expectRevert(
            abi.encodeWithSelector(
                IPDerivativeAgent_AlreadyWhitelisted.selector,
                parentIp,
                childIp,
                licenseTemplate,
                licenseId,
                licensee
            )
        );
        agent.addToWhitelist(parentIp, childIp, licensee, licenseTemplate, licenseId);
        vm.stopPrank();
    }
    
    function test_AddWildcardToWhitelist_Success() public {
        vm.prank(yokoa);
        agent.addWildcardToWhitelist(parentIp, childIp, licenseTemplate, licenseId);
        
        assertTrue(agent.isWhitelisted(parentIp, childIp, licenseTemplate, licenseId, address(0x999)));
        assertTrue(agent.isWhitelisted(parentIp, childIp, licenseTemplate, licenseId, licensee));
    }
    
    function test_RemoveFromWhitelist_Success() public {
        vm.startPrank(yokoa);
        agent.addToWhitelist(parentIp, childIp, licensee, licenseTemplate, licenseId);
        agent.removeFromWhitelist(parentIp, childIp, licensee, licenseTemplate, licenseId);
        vm.stopPrank();
        
        assertFalse(agent.isWhitelisted(parentIp, childIp, licenseTemplate, licenseId, licensee));
    }
    
    function test_BatchAddToWhitelist_Success() public {
        address[] memory parentIps = new address[](2);
        address[] memory childIps = new address[](2);
        address[] memory licensees = new address[](2);
        address[] memory licenseTemplates = new address[](2);
        uint256[] memory licenseIds = new uint256[](2);
        
        parentIps[0] = parentIp;
        parentIps[1] = address(0x10);
        childIps[0] = childIp;
        childIps[1] = address(0x11);
        licensees[0] = licensee;
        licensees[1] = address(0x12);
        licenseTemplates[0] = licenseTemplate;
        licenseTemplates[1] = address(0x13);
        licenseIds[0] = 1;
        licenseIds[1] = 2;
        
        vm.prank(yokoa);
        agent.addToWhitelistBatch(parentIps, childIps, licensees, licenseTemplates, licenseIds);
        
        assertTrue(agent.isWhitelisted(parentIps[0], childIps[0], licenseTemplates[0], licenseIds[0], licensees[0]));
        assertTrue(agent.isWhitelisted(parentIps[1], childIps[1], licenseTemplates[1], licenseIds[1], licensees[1]));
    }
    
    function test_BatchAddToWhitelist_RevertIf_LengthMismatch() public {
        address[] memory parentIps = new address[](2);
        address[] memory childIps = new address[](1); // Different length
        address[] memory licensees = new address[](2);
        address[] memory licenseTemplates = new address[](2);
        uint256[] memory licenseIds = new uint256[](2);
        
        vm.prank(yokoa);
        vm.expectRevert(IPDerivativeAgent_BatchLengthMismatch.selector);
        agent.addToWhitelistBatch(parentIps, childIps, licensees, licenseTemplates, licenseIds);
    }
    
    // ========== Registration Tests ==========
    
    function test_RegisterDerivative_Success_WithFee() public {
        uint256 fee = 10 ether;
        licensingModule.setMintingFee(address(token), fee);
        
        // Whitelist the licensee
        vm.prank(yokoa);
        agent.addToWhitelist(parentIp, childIp, licensee, licenseTemplate, licenseId);
        
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
            licenseId,
            licenseTemplate,
            address(token),
            fee,
            block.timestamp
        );
        agent.registerDerivativeViaYokoa(childIp, parentIp, licenseId, licenseTemplate, 0);
        
        // Check that tokens were transferred
        assertEq(token.balanceOf(licensee), 1000 ether - fee);
    }
    
    function test_RegisterDerivative_Success_NoFee() public {
        licensingModule.setMintingFee(address(0), 0);
        
        // Whitelist the licensee
        vm.prank(yokoa);
        agent.addToWhitelist(parentIp, childIp, licensee, licenseTemplate, licenseId);
        
        // Register derivative
        vm.prank(licensee);
        agent.registerDerivativeViaYokoa(childIp, parentIp, licenseId, licenseTemplate, 0);
        
        // Check that no tokens were transferred
        assertEq(token.balanceOf(licensee), 1000 ether);
    }
    
    function test_RegisterDerivative_Success_WithWildcard() public {
        uint256 fee = 5 ether;
        licensingModule.setMintingFee(address(token), fee);
        
        // Whitelist with wildcard
        vm.prank(yokoa);
        agent.addWildcardToWhitelist(parentIp, childIp, licenseTemplate, licenseId);
        
        // Any address can register now
        address anyAddress = address(0x999);
        token.mint(anyAddress, 100 ether);
        
        vm.startPrank(anyAddress);
        token.approve(address(agent), fee);
        agent.registerDerivativeViaYokoa(childIp, parentIp, licenseId, licenseTemplate, 0);
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
                licenseId,
                licensee
            )
        );
        agent.registerDerivativeViaYokoa(childIp, parentIp, licenseId, licenseTemplate, 0);
    }
    
    function test_RegisterDerivative_RevertIf_FeeTooHigh() public {
        uint256 fee = 10 ether;
        uint256 maxFee = 5 ether;
        licensingModule.setMintingFee(address(token), fee);
        
        vm.prank(yokoa);
        agent.addToWhitelist(parentIp, childIp, licensee, licenseTemplate, licenseId);
        
        vm.prank(licensee);
        token.approve(address(agent), fee);
        
        vm.prank(licensee);
        vm.expectRevert(
            abi.encodeWithSelector(IPDerivativeAgent_FeeTooHigh.selector, fee, maxFee)
        );
        agent.registerDerivativeViaYokoa(childIp, parentIp, licenseId, licenseTemplate, maxFee);
    }
    
    function test_RegisterDerivative_RevertIf_Paused() public {
        vm.prank(yokoa);
        agent.addToWhitelist(parentIp, childIp, licensee, licenseTemplate, licenseId);
        
        vm.prank(yokoa);
        agent.pause();
        
        vm.prank(licensee);
        vm.expectRevert("Pausable: paused");
        agent.registerDerivativeViaYokoa(childIp, parentIp, licenseId, licenseTemplate, 0);
    }
    
    // ========== Pausable Tests ==========
    
    function test_Pause_Success() public {
        vm.prank(yokoa);
        agent.pause();
        assertTrue(agent.paused());
    }
    
    function test_Unpause_Success() public {
        vm.startPrank(yokoa);
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
        
        vm.startPrank(yokoa);
        agent.pause();
        agent.emergencyWithdraw(address(token), yokoa, 100 ether);
        vm.stopPrank();
        
        assertEq(token.balanceOf(yokoa), 100 ether);
        assertEq(token.balanceOf(address(agent)), 0);
    }
    
    function test_EmergencyWithdraw_Native_Success() public {
        // Send native tokens to agent
        vm.deal(address(agent), 10 ether);
        
        uint256 yokoaBalanceBefore = yokoa.balance;
        
        vm.startPrank(yokoa);
        agent.pause();
        agent.emergencyWithdraw(address(0), yokoa, 10 ether);
        vm.stopPrank();
        
        assertEq(yokoa.balance, yokoaBalanceBefore + 10 ether);
        assertEq(address(agent).balance, 0);
    }
    
    function test_EmergencyWithdraw_RevertIf_NotPaused() public {
        token.mint(address(agent), 100 ether);
        
        vm.prank(yokoa);
        vm.expectRevert("Pausable: not paused");
        agent.emergencyWithdraw(address(token), yokoa, 100 ether);
    }
    
    function test_EmergencyWithdraw_RevertIf_ToIsContract() public {
        token.mint(address(agent), 100 ether);
        
        vm.startPrank(yokoa);
        agent.pause();
        vm.expectRevert(IPDerivativeAgent_InvalidParams.selector);
        agent.emergencyWithdraw(address(token), address(agent), 100 ether);
        vm.stopPrank();
    }
    
    // ========== View Functions Tests ==========
    
    function test_GetWhitelistKey() public view {
        bytes32 key = agent.getWhitelistKey(parentIp, childIp, licenseTemplate, licenseId, licensee);
        assertEq(
            key,
            keccak256(abi.encodePacked(parentIp, childIp, licenseTemplate, licenseId, licensee))
        );
    }
    
    function test_GetWhitelistStatusByKey() public {
        vm.prank(yokoa);
        agent.addToWhitelist(parentIp, childIp, licensee, licenseTemplate, licenseId);
        
        bytes32 key = agent.getWhitelistKey(parentIp, childIp, licenseTemplate, licenseId, licensee);
        assertTrue(agent.getWhitelistStatusByKey(key));
    }
}
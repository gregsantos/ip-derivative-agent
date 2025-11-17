// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import "../src/IPDerivativeAgent.sol";

contract DeployScript is Script {
    function run() external {
        // Read environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address yokoa = vm.envAddress("AGENT_ADDRESS");
        address licensingModule = vm.envAddress("LICENSING_MODULE");
        address royaltyModule = vm.envAddress("ROYALTY_MODULE");
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy IPDerivativeAgent
        IPDerivativeAgent agent = new IPDerivativeAgent(
            yokoa,
            licensingModule,
            royaltyModule
        );
        
        console.log("IPDerivativeAgent deployed at:", address(agent));
        console.log("Owner:", agent.owner());
        console.log("LicensingModule:", address(agent.LICENSING_MODULE()));
        console.log("RoyaltyModule:", agent.ROYALTY_MODULE());
        
        vm.stopBroadcast();
    }
}
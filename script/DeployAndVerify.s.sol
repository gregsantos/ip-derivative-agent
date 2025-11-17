// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import "../src/IPDerivativeAgent.sol";

contract DeployAndVerifyScript is Script {
    function run() external {
        // Read environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address yokoa = vm.envAddress("AGENT_ADDRESS");
        address licensingModule = vm.envAddress("LICENSING_MODULE");
        address royaltyModule = vm.envAddress("ROYALTY_MODULE");
        
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("========================================");
        console.log("Deployment Configuration");
        console.log("========================================");
        console.log("Deployer:", deployer);
        console.log("Yokoa Owner:", yokoa);
        console.log("LicensingModule:", licensingModule);
        console.log("RoyaltyModule:", royaltyModule);
        console.log("========================================");
        
        // Validate addresses
        require(yokoa != address(0), "AGENT_ADDRESS not set");
        require(licensingModule != address(0), "LICENSING_MODULE not set");
        require(royaltyModule != address(0), "ROYALTY_MODULE not set");
        
        // Start broadcasting
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy IPDerivativeAgent
        IPDerivativeAgent agent = new IPDerivativeAgent(
            yokoa,
            licensingModule,
            royaltyModule
        );
        
        console.log("\n========================================");
        console.log("Deployment Successful!");
        console.log("========================================");
        console.log("IPDerivativeAgent:", address(agent));
        console.log("Owner:", agent.owner());
        console.log("Paused:", agent.paused());
        console.log("========================================");
        
        vm.stopBroadcast();
        
        // Save deployment info
        string memory deploymentInfo = string.concat(
            "IPDerivativeAgent deployed at: ", vm.toString(address(agent)), "\n",
            "Owner: ", vm.toString(agent.owner()), "\n",
            "LicensingModule: ", vm.toString(address(agent.LICENSING_MODULE())), "\n",
            "RoyaltyModule: ", vm.toString(agent.ROYALTY_MODULE()), "\n"
        );
        
        vm.writeFile("deployment.txt", deploymentInfo);
        console.log("\nDeployment info saved to deployment.txt");
    }
}
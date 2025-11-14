// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {Moloch, Shares, Loot, Badges, Summoner, Call} from "../src/Moloch.sol";

contract BytecodeSizeTest is Test {
    uint256 constant MAX_CONTRACT_SIZE = 24576; // 24KB

    // Use this in your test files to check contract sizes
    function testContractSize() public {
        // Example usage - replace with your contracts
        assertContractSizeOk("Moloch");
    }

    function assertContractSizeOk(string memory contractName) public {
        bytes memory bytecode = getDeploymentBytecode(contractName);
        uint256 size = bytecode.length;

        console.log(string.concat("Checking ", contractName, " size..."));
        console.log("Size:", size, "bytes");

        assertLe(
            size,
            MAX_CONTRACT_SIZE,
            string.concat(
                contractName,
                " exceeds maximum contract size. Size: ",
                vm.toString(size),
                " bytes, Max: ",
                vm.toString(MAX_CONTRACT_SIZE),
                " bytes"
            )
        );
    }

    function getDeploymentBytecode(string memory contractName)
        internal
        view
        returns (bytes memory)
    {
        string memory artifactPath = string.concat(
            "out/", contractName, ".sol/", contractName, ".json"
        );

        string memory artifact = vm.readFile(artifactPath);
        return vm.parseJsonBytes(artifact, ".bytecode.object");
    }

    // Helper to get exact size without assertions
    function getContractSize(string memory contractName) public returns (uint256) {
        bytes memory bytecode = getDeploymentBytecode(contractName);
        return bytecode.length;
    }

    // Check runtime size of already deployed contract
    function getDeployedSize(address target) public view returns (uint256 size) {
        assembly {
            size := extcodesize(target)
        }
    }

    // Detailed size breakdown
    function logDetailedSize(string memory contractName) public {
        bytes memory bytecode = getDeploymentBytecode(contractName);
        uint256 size = bytecode.length;
        uint256 percentage = (size * 100) / MAX_CONTRACT_SIZE;

        console.log("\n=== Bytecode Size Analysis ===");
        console.log("Contract:", contractName);
        console.log("Total Size:", size, "bytes");
        console.log("Size (KB):", size / 1024);
        console.log("Max Allowed:", MAX_CONTRACT_SIZE, "bytes");
        console.log("Usage:", percentage, "%");
        console.log("Remaining:", MAX_CONTRACT_SIZE - size, "bytes");

        if (size > MAX_CONTRACT_SIZE) {
            console.log("STATUS: EXCEEDS LIMIT by", size - MAX_CONTRACT_SIZE, "bytes");
        } else if (percentage > 90) {
            console.log("STATUS: WARNING - Over 90% of limit");
        } else {
            console.log("STATUS: OK");
        }
        console.log("==============================\n");
    }
}

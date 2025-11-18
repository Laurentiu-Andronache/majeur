// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

/**
 * @title DeploymentPredictor
 * @notice Helper contract to predict Moloch DAO and token clone deployment addresses
 * @dev Can be used on-chain or off-chain via eth_call
 *
 * This contract implements the same CREATE2 address prediction logic used by the Summoner
 * contract to deploy Moloch DAOs and their associated token clones.
 */
contract DeploymentPredictor {
    /**
     * @notice Predict the deployment address of a Moloch DAO
     * @param summoner The address of the Summoner contract
     * @param implementation The address of the Moloch implementation
     * @param initHolders Initial token holders
     * @param initShares Initial share amounts
     * @param salt Custom salt parameter
     * @return dao The predicted Moloch DAO address
     */
    function predictMolochAddress(
        address summoner,
        address implementation,
        address[] calldata initHolders,
        uint256[] calldata initShares,
        bytes32 salt
    ) public pure returns (address dao) {
        // Compute the salt as done in Summoner.summon()
        bytes32 _salt = keccak256(abi.encode(initHolders, initShares, salt));

        // Compute the init code hash of the minimal proxy
        bytes32 initCodeHash = keccak256(_getMinimalProxyBytecode(implementation));

        // Compute CREATE2 address
        dao = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            summoner,
                            _salt,
                            initCodeHash
                        )
                    )
                )
            )
        );
    }

    /**
     * @notice Predict the deployment addresses of token clones
     * @param molochDAO The address of the Moloch DAO (or predicted address)
     * @param sharesImpl The address of the Shares implementation
     * @param badgesImpl The address of the Badges implementation
     * @param lootImpl The address of the Loot implementation
     * @return shares The predicted Shares token address
     * @return badges The predicted Badges token address
     * @return loot The predicted Loot token address
     */
    function predictTokenAddresses(
        address molochDAO,
        address sharesImpl,
        address badgesImpl,
        address lootImpl
    ) public pure returns (address shares, address badges, address loot) {
        // Token clones use the Moloch address as salt
        bytes32 _salt = bytes32(bytes20(molochDAO));

        shares = _predictClone(molochDAO, sharesImpl, _salt);
        badges = _predictClone(molochDAO, badgesImpl, _salt);
        loot = _predictClone(molochDAO, lootImpl, _salt);
    }

    /**
     * @notice Predict all deployment addresses in one call
     * @dev This is the most convenient function for UI integration
     * @param summoner The address of the Summoner contract
     * @param molochImpl The address of the Moloch implementation
     * @param sharesImpl The address of the Shares implementation
     * @param badgesImpl The address of the Badges implementation
     * @param lootImpl The address of the Loot implementation
     * @param initHolders Initial token holders
     * @param initShares Initial share amounts
     * @param salt Custom salt parameter
     * @return molochDAO The predicted Moloch DAO address
     * @return sharesToken The predicted Shares token address
     * @return badgesToken The predicted Badges token address
     * @return lootToken The predicted Loot token address
     */
    function predictAllAddresses(
        address summoner,
        address molochImpl,
        address sharesImpl,
        address badgesImpl,
        address lootImpl,
        address[] calldata initHolders,
        uint256[] calldata initShares,
        bytes32 salt
    ) external pure returns (
        address molochDAO,
        address sharesToken,
        address badgesToken,
        address lootToken
    ) {
        // First predict Moloch DAO address
        molochDAO = predictMolochAddress(
            summoner,
            molochImpl,
            initHolders,
            initShares,
            salt
        );

        // Then predict token addresses
        (sharesToken, badgesToken, lootToken) = predictTokenAddresses(
            molochDAO,
            sharesImpl,
            badgesImpl,
            lootImpl
        );
    }

    /**
     * @notice Compute the salt used for Moloch DAO deployment
     * @param initHolders Initial token holders
     * @param initShares Initial share amounts
     * @param salt Custom salt parameter
     * @return The computed salt
     */
    function computeMolochSalt(
        address[] calldata initHolders,
        uint256[] calldata initShares,
        bytes32 salt
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(initHolders, initShares, salt));
    }

    /**
     * @notice Compute the salt used for token clone deployment
     * @param molochDAO The Moloch DAO address
     * @return The computed salt (Moloch address as bytes32)
     */
    function computeTokenSalt(address molochDAO) public pure returns (bytes32) {
        return bytes32(bytes20(molochDAO));
    }

    /**
     * @notice Get the init code hash for a minimal proxy
     * @param implementation The implementation address
     * @return The keccak256 hash of the minimal proxy bytecode
     */
    function getMinimalProxyInitCodeHash(address implementation) public pure returns (bytes32) {
        return keccak256(_getMinimalProxyBytecode(implementation));
    }

    // ============ Internal Functions ============

    /**
     * @dev Predict a clone address using CREATE2
     */
    function _predictClone(
        address deployer,
        address implementation,
        bytes32 salt
    ) internal pure returns (address predicted) {
        bytes32 initCodeHash = keccak256(_getMinimalProxyBytecode(implementation));

        predicted = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            deployer,
                            salt,
                            initCodeHash
                        )
                    )
                )
            )
        );
    }

    /**
     * @dev Get the minimal proxy bytecode for a given implementation
     * @dev This matches the assembly in Moloch._init() and Summoner.summon()
     */
    function _getMinimalProxyBytecode(address implementation) internal pure returns (bytes memory) {
        // The bytecode format from the assembly:
        // mstore(0x00, 0x602d5f8160095f39f35f5f365f5f37365f73)
        // mstore(0x14, implementation)
        // mstore(0x24, 0x5af43d5f5f3e6029573d5ffd5b3d5ff3)
        // Returns bytes at offset 0x0e, length 0x36 (54 bytes)

        return abi.encodePacked(
            hex"602d5f8160095f39f35f5f365f5f37365f73",
            implementation,
            hex"5af43d5f5f3e6029573d5ffd5b3d5ff3"
        );
    }
}

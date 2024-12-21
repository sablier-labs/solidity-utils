// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable no-console
pragma solidity >=0.8.22;

import { console } from "forge-std/src/console.sol";
import { Script } from "forge-std/src/Script.sol";
import { stdJson } from "forge-std/src/StdJson.sol";

abstract contract BaseScript is Script {
    using stdJson for string;

    /// @dev The salt used for deterministic deployments.
    bytes32 internal immutable SALT;

    /// @dev Included to enable compilation of the script without a $MNEMONIC environment variable.
    string internal constant TEST_MNEMONIC = "test test test test test test test test test test test junk";

    /// @dev The address of the transaction broadcaster.
    address internal broadcaster;

    /// @dev Used to derive the broadcaster's address if $ETH_FROM is not defined.
    string internal mnemonic;

    /// @dev Initializes the transaction broadcaster like this:
    ///
    /// - If $ETH_FROM is defined, use it.
    /// - Otherwise, derive the broadcaster address from $MNEMONIC.
    /// - If $MNEMONIC is not defined, default to a test mnemonic.
    ///
    /// The use case for $ETH_FROM is to specify the broadcaster key and its address via the command line.
    constructor() {
        address from = vm.envOr({ name: "ETH_FROM", defaultValue: address(0) });
        if (from != address(0)) {
            broadcaster = from;
        } else {
            mnemonic = vm.envOr({ name: "MNEMONIC", defaultValue: TEST_MNEMONIC });
            (broadcaster,) = deriveRememberKey({ mnemonic: mnemonic, index: 0 });
        }

        // Construct the salt for deterministic deployments.
        SALT = constructCreate2Salt();
    }

    modifier broadcast() {
        vm.startBroadcast(broadcaster);
        _;
        vm.stopBroadcast();
    }

    /// @dev The presence of the salt instructs Forge to deploy contracts via this deterministic CREATE2 factory:
    /// https://github.com/Arachnid/deterministic-deployment-proxy
    ///
    /// Notes:
    /// - The salt format is "ChainID <chainid>, Version <version>".
    function constructCreate2Salt() internal view returns (bytes32) {
        string memory chainId = vm.toString(block.chainid);
        string memory version = getVersion();
        string memory create2Salt = string.concat("ChainID ", chainId, ", Version ", version);
        console.log("The CREATE2 salt is %s", create2Salt);
        return bytes32(abi.encodePacked(create2Salt));
    }

    /// @dev The version is obtained from `package.json`.
    function getVersion() internal view returns (string memory) {
        string memory json = vm.readFile("package.json");
        return json.readString(".version");
    }
}
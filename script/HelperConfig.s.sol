// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {Script} from "lib/forge-std/src/Script.sol";
import {VRFCoordinatorV2Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract HelperConfig is Script {
    VRFCoordinatorV2Mock vrfCoordinatorV2Mock;

    // this scruct will hold all the variables IN ORDER needed for the constructor of the smart contract
    struct NetworkConfig {
        address vrfCoordinator;
        uint256 entranceFee;
        uint256 interval;
        bytes32 keyHash;
        uint64 subId;
        uint32 callbackGasLimit;
        address linkToken;
        uint256 deployerKey;
    }

    // This gets populated after the contract is run/deployed / new HelperConfig();
    NetworkConfig public activeConfig;

    // default Anvil Key
    uint256 public constant anvilDefaultlKey =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    // sepolia chain id: 11155111
    // mainnet eth: 1
    // anvil: 31337
    constructor() {
        if (block.chainid == 1) {
            activeConfig = getMainnetETHConfig();
        } else if (block.chainid == 11155111) {
            activeConfig = getSepoliaConfig();
        }
        /* (block.chainid == 31337)*/
        else {
            activeConfig = getAnvilConfig();
        }
    }

    function getSepoliaConfig() public view returns (NetworkConfig memory) {
        NetworkConfig memory sepoliaConfig = NetworkConfig({
            vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
            entranceFee: 0.01 ether,
            interval: 30 seconds,
            keyHash: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            subId: 3495,
            callbackGasLimit: 2500000,
            linkToken: 0x779877A7B0D9E8603169DdbD7836e478b4624789, // sepolia Link Token ERC20 contract
            deployerKey: vm.envUint("private_key")
        });

        return sepoliaConfig;
    }

    function getMainnetETHConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory mainnetConfig = NetworkConfig({
            vrfCoordinator: 0x271682DEB8C4E0901D1a1550aD2e64D568E69909,
            entranceFee: 0.01 ether,
            interval: 30 seconds,
            keyHash: 0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef,
            subId: 3495,
            callbackGasLimit: 2500000,
            linkToken: 0x514910771AF9Ca656af840dff83E8264EcF986CA, // mainnet ETH LINK token ERC20
            deployerKey: 0
        });

        return mainnetConfig;
    }

    function getAnvilConfig() public returns (NetworkConfig memory) {
        if (activeConfig.vrfCoordinator != address(0)) {
            return activeConfig;
        }

        uint96 Base_Fee = .25 ether; //.25 Link
        uint96 GasPriceLink = 1e9; // 1 gwei LINK

        // Deploy Mocks
        // return Mock addresses
        vm.startBroadcast();
        vrfCoordinatorV2Mock = new VRFCoordinatorV2Mock(Base_Fee, GasPriceLink);
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        NetworkConfig memory anvilConfig = NetworkConfig({
            vrfCoordinator: address(vrfCoordinatorV2Mock),
            entranceFee: 0.01 ether,
            interval: 30 seconds,
            keyHash: 0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef,
            subId: 0, // interactions.s.sol script will add this value!!
            callbackGasLimit: 2500000,
            linkToken: address(linkToken),
            deployerKey: anvilDefaultlKey
        });

        return anvilConfig;
    }
}

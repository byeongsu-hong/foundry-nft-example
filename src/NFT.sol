// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin/upgrade/token/ERC721/presets/ERC721PresetMinterPauserAutoIdUpgradeable.sol";

contract NFT is ERC721PresetMinterPauserAutoIdUpgradeable {
    function initialize(
        string memory name,
        string memory symbol,
        string memory baseTokenURI
    ) public override initializer {
        __ERC721PresetMinterPauserAutoId_init(name, symbol, baseTokenURI);
    }
}

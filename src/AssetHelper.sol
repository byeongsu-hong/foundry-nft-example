// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface Mintable {
    function mint() external;
}

interface Permitable {
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}

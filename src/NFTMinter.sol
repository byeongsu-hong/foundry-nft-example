// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin/std/token/ERC20/IERC20.sol";
import "openzeppelin/std/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin/upgrade/proxy/utils/Initializable.sol";

import "./AssetHelper.sol";

enum AssetType {
    Native,
    ERC20
}

struct Asset {
    AssetType typ;
    address addr;
}

struct Signature {
    uint8 v;
    bytes32 r;
    bytes32 s;
}

contract NFTMinter is Initializable {
    using SafeERC20 for IERC20;

    string public constant NAME = "Bracelet Minter";

    address private authorizer_;
    address private nft_;
    address private beneficiary_;

    Asset private asset_;
    uint256 private price_;

    bytes32 public DOMAIN_SEPARATOR;
    // keccak256("Mint(address authorizer,address consumer,uint256 quantity,uint256 deadline)");
    bytes32 public constant MINT_TYPEHASH =
        0xa74d368158da60fbd4749531cca560dcd241b8f9eaca69cc0d1ede56ef056b70;

    function initialize(
        address _authorizer,
        address _nft,
        address _beneficiary,
        Asset memory _asset,
        uint256 _price
    ) public initializer {
        authorizer_ = _authorizer;
        nft_ = _nft;
        beneficiary_ = _beneficiary;

        asset_ = _asset;
        require(
            (asset_.typ != AssetType.Native && asset_.typ != AssetType.ERC20) ||
                (asset_.typ == AssetType.ERC20 && asset_.addr != address(0)) ||
                (asset_.typ == AssetType.Native && asset_.addr == address(0)),
            "NFTMinter: invalid asset value"
        );

        price_ = _price;

        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(NAME)),
                keccak256(bytes("1")),
                chainId,
                address(this)
            )
        );
    }

    // queries

    /***
     * @return authorizer address of authorizer for a mint action
     */
    function authorizer() external view returns (address) {
        return authorizer_;
    }

    /***
     * @return nft address of nft contract
     */
    function nft() external view returns (address) {
        return nft_;
    }

    // txs

    /***
     * @dev uses each "owner" / "spender" of pemit scheme to authorizer, msg.sender.
     */
    function _checkSignature(
        uint256 _quantity,
        uint256 _deadline,
        Signature memory _authority
    ) internal view {
        require(_deadline >= block.timestamp, "NFTMinter: EXPIRED");
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(
                        MINT_TYPEHASH,
                        authorizer_,
                        msg.sender,
                        _quantity,
                        _deadline
                    )
                )
            )
        );
        address recovered = ecrecover(
            digest,
            _authority.v,
            _authority.r,
            _authority.s
        );
        require(
            recovered != address(0) && recovered == authorizer_,
            "NFTMinter: INVALID_SIGNATURE"
        );
    }

    function _checkAsset(uint256 _quantity) internal {
        uint256 required = price_ * _quantity;

        // NATIVE
        if (asset_.typ == AssetType.Native) {
            require(msg.value == required, "NFTMinter: not enough funds");
            payable(beneficiary_).transfer(required);
            return;
        }

        // ERC20
        if (asset_.typ == AssetType.ERC20) {
            IERC20(asset_.addr).safeTransferFrom(
                msg.sender,
                beneficiary_,
                required
            );
            return;
        }

        revert("NFTMinter: invalid asset type");
    }

    function _checkAsset(
        uint256 _quantity,
        uint256 _deadline,
        Signature memory _authority
    ) internal {
        uint256 required = price_ * _quantity;

        require(
            asset_.typ == AssetType.ERC20,
            "NFTMinter: only erc20 can operate"
        );
        Permitable(asset_.addr).permit(
            msg.sender,
            address(this),
            required,
            _deadline,
            _authority.v,
            _authority.r,
            _authority.s
        );
        IERC20(asset_.addr).safeTransferFrom(
            msg.sender,
            beneficiary_,
            required
        );
    }

    function _mint(uint256 _quantity) internal {
        for (uint256 i = 0; i < _quantity; i++) {
            Mintable(nft_).mint();
        }
    }

    function mint(
        uint256 _quantity,
        uint256 _deadline,
        Signature memory _mintAuthority
    ) external payable {
        _checkSignature(_quantity, _deadline, _mintAuthority);
        _checkAsset(_quantity);
        _mint(_quantity);
    }

    function mint(
        uint256 _quantity,
        uint256 _deadline,
        Signature memory _mintAuthority,
        Signature memory _tokenAuthority
    ) external {
        _checkSignature(_quantity, _deadline, _mintAuthority);
        _checkAsset(_quantity, _deadline, _tokenAuthority);
        _mint(_quantity);
    }
}

//SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract GCBankMeta {
    struct EIP712Domain {
        string name;
        string version;
        uint256 chainId;
        address verifyingContract;
    }

    struct MetaTransaction {
        uint256 nonce;
        address from;
    }

    mapping(address => uint256) public nonces;
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH = keccak256(bytes("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"));
    bytes32 internal constant META_TRANSACTION_TYPEHASH = keccak256(bytes("MetaTransaction(uint256 nonce,address from)"));
    bytes32 internal DOMAIN_SEPARATOR;

    constructor(uint256 _chainId) {
        DOMAIN_SEPARATOR= keccak256(abi.encode(
            EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes("GCBank")),
                keccak256(bytes("1")),
                _chainId,
                address(this)
        ));
    }
}

contract GCBank is Ownable, GCBankMeta {

    address GcrAddress;

    event MoneySent(address indexed _beneficiary, uint _amount);
    event MoneyReceived(address indexed _from, uint _amount);

    constructor(address _tokenAddress, uint256 _chainId) GCBankMeta(_chainId) {
        GcrAddress = _tokenAddress;
    }

    function withdrawPoints (
        uint256 _amount, address _receiverAddress, bytes32 r, bytes32 s, uint8 v
    ) public {

        IERC20 GCR = IERC20(GcrAddress);
        address contractOwner = owner();

        require(GCR.balanceOf(address(this)) >= _amount, "Contract doesn't have enough GCR");

        MetaTransaction memory metaTx = MetaTransaction({
            nonce: nonces[contractOwner],
            from: contractOwner
        });

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(META_TRANSACTION_TYPEHASH, metaTx.nonce, metaTx.from))
            )
        );

        require(contractOwner == ecrecover(digest, v, r, s), "GCBank:invalid-signature");

        nonces[contractOwner] += 1;

        GCR.transfer(_receiverAddress, _amount);

        emit MoneySent(_receiverAddress, _amount);
    }

    // receive() external payable {
    //     emit MoneyReceived(msg.sender, msg.value);
    // }

    function renounceOwnership () public pure override {
        revert("Can't renounceOwnership here"); //not possible with this smart contract
    }

}

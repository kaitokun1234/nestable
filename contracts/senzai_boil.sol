// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "erc721a/contracts/ERC721A.sol";

contract senzai_boil is ERC721A, Ownable {
    using Strings for uint256;

    string baseURI = "https://senzai.app/senzai/metadata/";
    uint256 public preCost = 0.07 ether;
    uint256 public publicCost = 0.09 ether;

    bool public revealed = false;
    bool public presale = true;
    string public notRevealedUri;

    uint256 public maxSupply = 2500;
    uint256 public publicMaxPerTx = 10;
    uint256 public presaleMaxPerWallet = 10;
    string constant baseExtension = ".json";
    bytes32 public merkleRoot;
    address public multisigAddr = 0xDe06d97711392FD5248637B27428a4d257Fb976D;

    mapping(address => uint256) private whiteListClaimed;

    constructor(
        string memory _name,
        string memory _symbol
    ) ERC721A(_name, _symbol) {}

    // internal
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    // public mint
    function publicMint(uint256 _mintAmount) public payable {
        uint256 supply = totalSupply();
        uint256 cost = publicCost * _mintAmount;
        mintCheck(_mintAmount, supply, cost);
        require(!presale, "Public mint is paused while Presale is active.");
        require(
            _mintAmount <= publicMaxPerTx,
            "Mint amount cannot exceed 10 per Tx."
        );
        _mint(msg.sender, _mintAmount);
    }

    function preMint(uint256 _mintAmount, bytes32[] calldata _merkleProof)
        public
        payable
    {
        uint256 supply = totalSupply();
        uint256 cost = preCost * _mintAmount;
        mintCheck(_mintAmount, supply, cost);
        require(presale, "Presale is not active.");

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(
            MerkleProof.verify(_merkleProof, merkleRoot, leaf),
            "Invalid Merkle Proof"
        );

        require(
            whiteListClaimed[msg.sender] + _mintAmount <= presaleMaxPerWallet,
            "Address already claimed max amount"
        );
        _mint(msg.sender, _mintAmount);
        whiteListClaimed[msg.sender] += _mintAmount;
    }

    function mintCheck(
        uint256 _mintAmount,
        uint256 supply,
        uint256 cost
    ) private view {
        require(_mintAmount > 0, "Mint amount cannot be zero");
        require(
            supply + _mintAmount <= maxSupply,
            "Total supply cannot exceed maxSupply"
        );
        require(msg.value >= cost, "Not enough funds provided for mint");
    }

    function ownerMint(uint256 _amount) public onlyOwner {
        uint256 supply = totalSupply();
        mintCheck(_amount, supply, 0);
        _mint(msg.sender, _amount);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        if (revealed == false) {
            return notRevealedUri;
        }

        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        tokenId.toString(),
                        baseExtension
                    )
                )
                : "";
    }

    function reveal() public onlyOwner {
        revealed = true;
    }

    function setPresale(bool _state) public onlyOwner {
        presale = _state;
    }

    function setPreCost(uint256 _preCost) public onlyOwner {
        preCost = _preCost;
    }

    function setPublicCost(uint256 _publicCost) public onlyOwner {
        publicCost = _publicCost;
    }

    function getCurrentCost() public view returns (uint256) {
        if (presale) {
            return preCost;
        } else {
            return publicCost;
        }
    }

    function setNotRevealedURI(string memory _notRevealedURI) public onlyOwner {
        notRevealedUri = _notRevealedURI;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function setPublicMaxPerTx(uint _newPublicMaxPerTx) public onlyOwner {
        publicMaxPerTx = _newPublicMaxPerTx;
    }

    function setPresaleMaxPerWallet(uint _newPresaleMaxPerWallet) public onlyOwner {
        presaleMaxPerWallet = _newPresaleMaxPerWallet;
    }

    function addMaxSupply(uint _addInt) public onlyOwner {
        maxSupply = _addInt;
    }

    function withdraw() external onlyOwner {
        uint256 royalty = address(this).balance;
        Address.sendValue(payable(multisigAddr), royalty);
    }

    function setMultisigAddr(address _newAddr) public{
        require(msg.sender == multisigAddr, "require from multisig");
        multisigAddr = _newAddr;
    }

    /**
     * @notice Set the merkle root for the allow list mint
     */
    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }
}

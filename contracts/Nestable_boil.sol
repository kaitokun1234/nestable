// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract ERC721Interface {
  function tokenURI(uint256 tokenId) external view returns (string memory) {}
  function ownerOf(uint256 tokenId) external view returns(address) {}
}

contract Nestable_boil is ERC721Enumerable, Ownable {

    using Strings for uint256;
  
    struct Parent {
        address contractAddr;
        uint tokenId;
        uint[] children;
    }

    struct Child {
        uint tokenId;
        //address owner;
        bool nesting;
        uint parentId;
    }

    mapping(uint => Child) children;
    mapping(uint => Parent) parents;
    
    uint parentsCount = 1;

    string baseURI = "https://senzai.app/senzai/metadata/";
    uint256 public publicCost = 0.09 ether;

    bool public revealed = false;
    string public notRevealedUri;

    uint256 public maxSupply = 2500;
    uint256 public publicMaxPerTx = 10;
    string constant baseExtension = ".json";
    address public multisigAddr = 0xDe06d97711392FD5248637B27428a4d257Fb976D;

    constructor(
        string memory _name,
        string memory _symbol
    ) ERC721(_name, _symbol) {}
/*
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
      Child memory _child = children[tokenId];
      require(msg.sender == from, "your address is not from address");
      require(!_child.nesting, "this element is nesting");
      require(msg.sender == ownerOf(tokenId), "you are not owner");
      super._transfer(from, to, tokenId);
    }

    function ownerOf(uint tokenId) public view virtual override(ERC721, IERC721) returns (address) {
      Child memory _child = children[tokenId];
      if(_child.nesting){
        Parent memory _parent = parents[_child.parentId];
        return parentRawOwnerOf(_parent.contractAddr, _parent.tokenId);
      }else{
        return super.ownerOf(tokenId);
      }
    }
*/
    function parentRawTokenURI(address _contractAddr, uint _tokenId) public view returns(string memory) {
      ERC721Interface erc721contract = ERC721Interface(_contractAddr);
      return erc721contract.tokenURI(_tokenId);
    }

    function parentRawOwnerOf(address _contractAddr, uint _tokenId) public view returns(address) {
      ERC721Interface erc721contract = ERC721Interface(_contractAddr);
      return erc721contract.ownerOf(_tokenId);
    }

    function makeParent(address _contractAddr, uint _tokenId) public {
      Child[] memory initChildren;
      Parent memory newParent = Parent(_contractAddr, _tokenId, initChildren);
      parents[parentsCount] = newParent;
      parentsCount ++;
    }

    // internal
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    // public mint
    function publicMint(uint256 _mintAmount) public payable {
        uint256 supply = totalSupply();
        uint256 cost = publicCost * _mintAmount;
        mintCheck(_mintAmount, supply, cost);
        require(
            _mintAmount <= publicMaxPerTx,
            "Mint amount cannot exceed 10 per Tx."
        );
        _mint(msg.sender, _mintAmount);
        Child memory newChild = Child(supply, false, 0);
        children[supply] = newChild;
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

    function nest(uint _childId, uint _parentId) public{
      require(parentRawOwnerOf(parents[_parentId].contractAddr, parents[_parentId].tokenId) == msg.sender, "you are not parent owner");
      require(ownerOf(_childId) == msg.sender, "you are not owner");
      require(!children[_childId].nesting, "this is nesting");
      require(children[_childId].parentId == 0, "this is nesting");
      children[_childId].parentId = _parentId;
      children[_childId].nesting = true;
    }

    function unnest(uint _childId) public{
      require(children[_childId].nesting, "this is nesting");
      require(ownerOf(_childId) == msg.sender, "you are not owner");
      children[_childId].parentId = 0;
      children[_childId].nesting = false;
      ownerOf(_childId) == msg.sender;
      super._transfer(ownerOf(_childId), parents[children[_childId].parentId].contractAddr, _childId);
    }

    function isNesting(uint _childId) public view returns(bool) {
      return children[_childId].nesting;
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
    
    function setPublicCost(uint256 _publicCost) public onlyOwner {
        publicCost = _publicCost;
    }

    function getCurrentCost() public view returns (uint256) {
      return publicCost;
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
}

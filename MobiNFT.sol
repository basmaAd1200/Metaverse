// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MobiNFT is ERC721 {
    mapping(uint256 => string) private _tokenURIs;
    address contractPublisher;
    
    constructor() ERC721("Bored Apes", "BOAP") {
        contractPublisher = msg.sender;
    }

     // Define a modifier that checks the caller is the owner
    modifier onlyOwner() {
        require(msg.sender == contractPublisher, "Not owner");
        _;
    }

    function mint(address to, uint256 tokenId, string memory _tokenURI) public onlyOwner  {
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, _tokenURI);
    }

    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal {
        _tokenURIs[tokenId] = _tokenURI;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return _tokenURIs[tokenId];
    }
}

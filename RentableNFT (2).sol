// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RentableNFT is ERC721 {
    mapping(uint256 => string) private _tokenURIs;
    mapping(uint256 => NFTInfo) private _NFTInfo;
    uint256 public count = 0;

    address contractPublisher;
    address contractCurrencyAddress;

     struct NFTInfo {
        string name;
        string description;
        bool availableForRenting;
        bool availableForSale;
        bool allowedToVisit;
        address[] accessNFTAddress;
        uint256[] accessNFTID;
        uint256 nftPrice;
        address currencyAddress;
        RentalInfo rentalInfo;
    }

    struct RentalInfo {
        address RenterAddress;
        bool allowedToVisit;
        address[] accessNFTAddress;
        uint256[] accessNFTID;
        uint256 pricePerHour;
        uint256 MaxRentalHours;
        uint256 StartRentTime;
        uint256 EndRentTime;
    }

    
    constructor(address _contractCurrencyAddress) ERC721("Rentable NFT", "RNFT") {
        contractPublisher = msg.sender;
        contractCurrencyAddress = _contractCurrencyAddress;
    }

    // Define a modifier that checks the caller is the owner
    modifier onlyOwner() {
        require(msg.sender == contractPublisher, "Not owner");
        _;
    }

    function mint(address to, string memory _tokenURI) public onlyOwner  {
        count++;
        uint256 tokenId = count;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, _tokenURI);
        //setNFTInfo(tokenId, "NFT", "Rentable NFT");

        NFTInfo memory nftInfo = _NFTInfo[tokenId];
        nftInfo.name = "NFT";
        nftInfo.description = "Rentable NFT";
        nftInfo.availableForRenting = false;
        nftInfo.availableForSale = false;
        nftInfo.allowedToVisit = true;
        nftInfo.nftPrice = 0;
        nftInfo.currencyAddress = contractCurrencyAddress;
        // Initialize empty arrays
        nftInfo.accessNFTAddress = new address[](0);
        nftInfo.accessNFTID = new uint256[](0);
        nftInfo.rentalInfo = RentalInfo(
            address(0), // RenterAddress
            true,
            new address[](0) , // accessNFTAddress
            new uint256[](0) , // accessNFTID
            0, // pricePerHour
            72, // MaxRentalHours
            0, // StartRentTime
            0 // EndRentTime
        );

        _NFTInfo[tokenId] = nftInfo;
    }

    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal {
        _tokenURIs[tokenId] = _tokenURI;
    }
    
    function setNFTInfo(uint256 tokenId, string memory name, string memory description) public{
        require(msg.sender == ownerOf(tokenId), "Only owner can set NFT info");

        NFTInfo memory nftInfo = _NFTInfo[tokenId];
        nftInfo.name = name;
        nftInfo.description = description;

        _NFTInfo[tokenId] = nftInfo;
    }
    
    function setAccessNFT(uint256 tokenId, bool _allowedToVisit, address[] memory NFTaddress, uint256[] memory NFTId) public {
        NFTInfo storage nftInfo = _NFTInfo[tokenId];

        require(msg.sender == ownerOf(tokenId) || msg.sender == nftInfo.rentalInfo.RenterAddress, "Only owner or renter can add access addresses");

        if(msg.sender == ownerOf(tokenId)){
            nftInfo.accessNFTAddress = NFTaddress;
            nftInfo.accessNFTID = NFTId;
            nftInfo.allowedToVisit = _allowedToVisit;
        }else{
            nftInfo.rentalInfo.accessNFTAddress = NFTaddress;
            nftInfo.rentalInfo.accessNFTID = NFTId;
            nftInfo.rentalInfo.allowedToVisit = _allowedToVisit;
        }
        _NFTInfo[tokenId] = nftInfo;
        
    }


    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return _tokenURIs[tokenId];
    }


    // Updated function to return individual fields
    function getNFTInfo(uint256 tokenId) public view returns (string memory name, string memory description, bool availableForRenting, bool availableForSale, bool allowedToVisit,
    address[] memory accessNFTAddress, uint256[] memory accessNFTID, uint256 nftPrice, address currencyAddress, RentalInfo memory rentalInfo) {
        require(_exists(tokenId), "ERC721Metadata: Additional data query for nonexistent token");
        NFTInfo storage data = _NFTInfo[tokenId];
        return (data.name,data.description,data.availableForRenting, data.availableForSale, data.allowedToVisit, data.accessNFTAddress, data.accessNFTID,
        data.nftPrice, data.currencyAddress, data.rentalInfo);
    }

   function _exists(uint256 tokenId) internal view returns (bool) {
    return _ownerOf(tokenId) != address(0);
    }


    function setRentingData(uint256 tokenId, bool _availableForRenting, uint256 _pricePerHour, uint _maxRentalHours) public {
        require(msg.sender == ownerOf(tokenId), "Only owner can set NFT info");

        NFTInfo memory nftInfo = _NFTInfo[tokenId];
        require(_maxRentalHours > 0, "Can't set max hours zero");
        require(_pricePerHour > 0, "Can't set price per hour zero");

        nftInfo.availableForRenting = _availableForRenting;
        nftInfo.rentalInfo.pricePerHour = _pricePerHour;
        nftInfo.rentalInfo.MaxRentalHours = _maxRentalHours;
        _NFTInfo[tokenId] = nftInfo;
    }

    function RentNFT(uint256 tokenId, uint256 _numberOfHours) public {
        NFTInfo memory nftInfo = _NFTInfo[tokenId];
        require(nftInfo.availableForRenting == true && isRented(tokenId) == false, "NFT is not available for rent");
        require(msg.sender != ownerOf(tokenId), "Owners cannot rent their own panels");
        require(_numberOfHours <= nftInfo.rentalInfo.MaxRentalHours, "Number of hours must be less than the maximum hours");
        require(_numberOfHours > 0, "You must rent for one hour at least");
        uint256 rentalFee = nftInfo.rentalInfo.pricePerHour * _numberOfHours;
        require(ERC20(nftInfo.currencyAddress).allowance(msg.sender, address(this)) >= rentalFee, "Not enough allowance");
        require(ERC20(nftInfo.currencyAddress).transferFrom(msg.sender, ownerOf(tokenId), rentalFee), "Transfer failed");

        nftInfo.rentalInfo.RenterAddress = msg.sender;
        nftInfo.rentalInfo.StartRentTime = block.timestamp;
        nftInfo.rentalInfo.EndRentTime = block.timestamp + (_numberOfHours * 60 * 60);
        _NFTInfo[tokenId] = nftInfo;
    }

    function EndRent(uint256 tokenId) public {
        NFTInfo memory nftInfo = _NFTInfo[tokenId];
        require(msg.sender != ownerOf(tokenId), "Owners cannot end rent their own panels");
        require(isRented(tokenId) == true && nftInfo.rentalInfo.RenterAddress == msg.sender, "You are not allowed to end the rent");
        nftInfo.rentalInfo.StartRentTime = 0;
        nftInfo.rentalInfo.EndRentTime = 0;
        nftInfo.rentalInfo.RenterAddress = address(0);
        _NFTInfo[tokenId] = nftInfo;
    }

    function isRented(uint256 tokenId) public view returns (bool) {
        NFTInfo memory nftInfo = _NFTInfo[tokenId];
        if (nftInfo.rentalInfo.EndRentTime > block.timestamp) {
            return true;
        } else {
            return false;
        }
    }

    function isERC20Token(address currencyTokenAddress) public view returns (bool) {
        try IERC20(currencyTokenAddress).totalSupply() returns (uint256) {
            return true;
        } catch {
            return false;
        }
    }

    function getRentingData(uint256 tokenId) public view returns (address RenterAddress
    , uint256 pricePerHour, uint256 MaxRentalHours, uint256 StartRentTime,uint256 EndRentTime) {
        require(_exists(tokenId), "Invalid NFT Id");

        NFTInfo memory nftInfo = _NFTInfo[tokenId];
        NFTInfo memory currentNFTInfo = nftInfo;
        if (!isRented(tokenId)) {
            currentNFTInfo.rentalInfo.StartRentTime = 0;
            currentNFTInfo.rentalInfo.EndRentTime = 0;
            currentNFTInfo.rentalInfo.RenterAddress = address(0);
        } else {
            currentNFTInfo.availableForRenting = false;
            
        }

        return (currentNFTInfo.rentalInfo.RenterAddress
        ,currentNFTInfo.rentalInfo.pricePerHour,currentNFTInfo.rentalInfo.MaxRentalHours,currentNFTInfo.rentalInfo.StartRentTime,currentNFTInfo.rentalInfo.EndRentTime);
    }

    function setNFTPrice(uint256 tokenId, uint256 _price, bool _availableForSale) public {
        NFTInfo memory nftInfo = _NFTInfo[tokenId];
        require(msg.sender == ownerOf(tokenId), "Only the owner can change metadata");
        require(_price > 0, "Can't set price lower or equal 0");
        nftInfo.nftPrice = _price;
        nftInfo.availableForSale = _availableForSale;
        _NFTInfo[tokenId] = nftInfo;
    }

    function setCurrencyAddress(uint256 tokenId, address _currencyAddress) public {
        NFTInfo memory nftInfo = _NFTInfo[tokenId];
        require(msg.sender == ownerOf(tokenId), "Only the owner can change metadata");
        require(isERC20Token(_currencyAddress), "The currency address isn't an ERC-20 token");
        
        nftInfo.currencyAddress = _currencyAddress;
        _NFTInfo[tokenId] = nftInfo;
    }

    function transferNFT(address from, address to, uint256 tokenId) internal {
    // Check if the sender owns the NFT
    require(ownerOf(tokenId) == from, "Sender does not own the NFT");

    // Transfer ownership of the NFT to the recipient
    _transfer(from, to, tokenId);
    }

    function buyNFT(uint256 tokenId) public {
        NFTInfo memory nftInfo = _NFTInfo[tokenId];
        require(_exists(tokenId), "NFT does not exist");
        require(nftInfo.availableForSale == true, "No available for sale");
        require(msg.sender != ownerOf(tokenId), "You already own this NFT");
        require(ERC20(nftInfo.currencyAddress).balanceOf(msg.sender) >= nftInfo.nftPrice, "Insufficient balance");
        require(ERC20(nftInfo.currencyAddress).allowance(msg.sender, address(this)) >= nftInfo.nftPrice, "Insufficient allowance");
        
        require(ERC20(nftInfo.currencyAddress).transferFrom(msg.sender, ownerOf(tokenId), nftInfo.nftPrice), "Transfer failed");

        //safeTransferFrom(ownerOf(tokenId), msg.sender, tokenId);
        transferNFT(ownerOf(tokenId), msg.sender, tokenId);
        
        nftInfo.availableForRenting = false;
        nftInfo.availableForSale = false;
        nftInfo.accessNFTAddress = new address[](0);
        nftInfo.accessNFTID = new uint256[](0);
        _NFTInfo[tokenId] = nftInfo;
    }

 

}

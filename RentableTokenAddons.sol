// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NFTHolder {
    // Declare a state variable to store the owner address
        address public contractPublisher;
        string private name;
        string private description;
        address HolderCurrencyToken;

    // Assign the owner address in the constructor
    constructor(string memory _name, string memory _description, address _HolderCurrencyToken) {
        require(isERC20Token(_HolderCurrencyToken), "The currency address isn't an ERC-20 token");
        contractPublisher = msg.sender;
        name = _name;
        description = _description;
        HolderCurrencyToken = _HolderCurrencyToken;
    }
    // Define a struct to store the properties of each rentable token
    struct TokenInfo {
        address owner; // The owner of the rentable token
        uint256 AreaSize;
        bool availableForRenting; // The availability of the rentable token
        bool rentableNFT;
        uint256 holderPrice; // The price of the rentable token
        address currencyToken;
        address NFTAddress;
        uint256 NFTTokenID;
        uint256 NFTPrice;
        TokenTransform tokenTransform;
        RentalInfo rentalInfo; // Rental information
    }

    struct TokenTransform {
        int256 locationX;
        int256 locationY;
        int256 locationZ;

        int256 rotationX;
        int256 rotationY;
        int256 rotationZ;

        int256 scaleX;
        int256 scaleY;
        int256 scaleZ;
    }

    struct RentalInfo {
        address RenterAddress; // The address of the renter
        address NFTAddress; // Link to save NFTAddress for renter metadata
        uint256 NFTTokenID;
        uint256 NFTPrice;
        uint256 pricePerHour; // The price of renting the rentable token per hour
        uint256 MaxRentalHours; // Maximum possible hours to rent the rentable token
        uint256 StartRentTime; // Start renting time
        uint256 EndRentTime; // The duration of the rental in hours
    }

    // Define a modifier that checks the caller is the owner
    modifier onlyOwner() {
        require(msg.sender == contractPublisher, "Not owner");
        _;
    }
    // Define a mapping to associate each rentable token id with its corresponding struct
    mapping (uint256 => TokenInfo) public rentableTokens;

    // Define a counter variable to keep track of the number of rentable token
    uint256 public tokenCount;

    // Define a function to create a new rentable token
    function createRentableToken(uint256 _areaSize) public onlyOwner {
        
        // Increment the rentable token count
        tokenCount++;
        // Create a new rentable token struct with the given parameters and the sender address as the owner
        TokenInfo memory newToken = TokenInfo({
            owner: msg.sender,
            AreaSize: _areaSize,
            availableForRenting: false,
            rentableNFT: false,
            holderPrice: 0,
            currencyToken: HolderCurrencyToken,
            NFTAddress: address(0),
            NFTTokenID: 0,
            NFTPrice: 0,
            tokenTransform: TokenTransform(0,0,0,0,0,0,1,1,1),
            rentalInfo: RentalInfo(address(0),address(0),0, 0, 0, 72, 0, 0)
        });

        // Store the new rentable token struct in the mapping with the rentable token count as the id
        rentableTokens[tokenCount] = newToken;
    }
    
    function isERC20Token(address currencyTokenAddress) public view returns (bool) {
        // Check for ERC-20 functions
        try IERC20(currencyTokenAddress).totalSupply() returns (uint256) {
            return true;
        } catch {
            return false;
        }
    }


    // Define a function to set the availability of a rentable token
    function setTokenData(uint256 _tokenId, address currencyTokenAddress, address _NFTAddress, uint256 _nftTokenID) public {
        // Get the rentable token struct from the mapping
        TokenInfo storage rentableToken = rentableTokens[_tokenId];

        // Check if the caller is the owner of the rentable token
        require(msg.sender == rentableToken.owner, "Only the owner can change the token properites");

        require(isERC20Token(currencyTokenAddress), "The currency address isn't an ERC-20 token");

        rentableToken.currencyToken = currencyTokenAddress;
        rentableToken.NFTAddress = _NFTAddress;
        rentableToken.NFTTokenID = _nftTokenID;

    }

    // Define a function to rent a rentable token for a specific duration
    function RentToken(uint256 _tokenId, uint256 _numberOfHours) public{
        // Get the rentable token struct from the mapping
        TokenInfo storage rentableToken = rentableTokens[_tokenId];

        // Check if the rentable token is available for rent
        require(rentableToken.availableForRenting == true && isRented(_tokenId) == false, "Panel is not available for rent");
        // Check if the caller is not the owner of the rentable token
        require(msg.sender != rentableToken.owner, "Owners cannot rent their own panels");
        // Check that renting hours are less than the max number of hours
        require(_numberOfHours <= rentableToken.rentalInfo.MaxRentalHours, "Number of hours must be less than the maximum hours");
        require(_numberOfHours > 0, "You must rent for one hour at least");
        // Calculate the rental fee
        uint256 rentalFee = rentableToken.rentalInfo.pricePerHour * _numberOfHours;
        // Check if the renter has sent enough tokens
        //require(msg.value >= rentalFee, "Insufficient funds");
        require(ERC20(rentableToken.currencyToken).allowance(msg.sender, address(this)) >= rentalFee, "Not enough allowance");
        // Transfer the rental fee to the owner of the rentable token
        //payable(panel.owner).transfer(rentalFee);
        require(ERC20(rentableToken.currencyToken).transferFrom(msg.sender, rentableToken.owner, rentalFee), "Transfer failed");

        // Update the panel struct
        rentableToken.rentalInfo.RenterAddress = msg.sender;
        rentableToken.rentalInfo.NFTAddress = address(0);
        rentableToken.rentalInfo.NFTTokenID = 0;
        rentableToken.rentalInfo.StartRentTime = block.timestamp;
        rentableToken.rentalInfo.EndRentTime = block.timestamp + (_numberOfHours * 60 * 60);

       
    }

    // Define a function to end the rental of a rentable token
    function EndRent(uint256 _tokenId) public {
        // Get the rentable token struct from the mapping
        TokenInfo storage rentableToken = rentableTokens[_tokenId];

        // Check if the caller is not the owner of the rentable token
        require(msg.sender != rentableToken.owner, "Owners cannot end rent their own panels");

        // Check if the rentable token is rented and the sender is the renter
        require(isRented(_tokenId) == true && rentableToken.rentalInfo.RenterAddress == msg.sender, "You are not allowed to end the rent");

        // Update the rentable token struct
        rentableToken.rentalInfo.StartRentTime = 0;
        rentableToken.rentalInfo.EndRentTime = 0;
        rentableToken.rentalInfo.NFTAddress = address(0);
        rentableToken.rentalInfo.NFTTokenID = 0;
        rentableToken.rentalInfo.RenterAddress = address(0);
    }

  // Define a function to get rentable token data
    function getTokenData(uint256 _tokenId) public view returns (string memory _name, string memory _description
        ,address owner,uint256 AreaSize, uint256 Price, bool rentableNFT, bool avaliableForRenting, address currencyToken, address NFTAddress
        ,uint256 nftTokenID, TokenTransform memory tokenTransform, RentalInfo memory rentalInfo) {
        require(_tokenId > 0 && _tokenId <= tokenCount, "Invalid panelId");

        TokenInfo memory rentableToken = rentableTokens[_tokenId];

        return (name,description, rentableToken.owner,rentableToken.AreaSize, rentableToken.holderPrice, rentableToken.rentableNFT, rentableToken.availableForRenting, rentableToken.currencyToken, rentableToken.NFTAddress
        , rentableToken.NFTTokenID, rentableToken.tokenTransform, rentableToken.rentalInfo);
    }

    function getTokenTransform(uint256 _tokenId) public view returns (int256 locationX, int256 locationY, int256 locationZ
    ,int256 rotationX, int256 rotationY, int256 rotationZ, int256 scaleX, int256 scaleY, int256 scaleZ) {
        require(_tokenId > 0 && _tokenId <= tokenCount, "Invalid panelId");

        TokenInfo memory rentableToken = rentableTokens[_tokenId];
        TokenTransform memory tokenTransform = rentableToken.tokenTransform;

        return (tokenTransform.locationX,tokenTransform.locationY,tokenTransform.locationZ,tokenTransform.rotationX,tokenTransform.rotationY
        ,tokenTransform.rotationZ,tokenTransform.scaleX,tokenTransform.scaleY,tokenTransform.scaleZ);
    }


    // Define a function to get rentable token data
    function getRentingData(uint256 _tokenId) public view returns (address RenterAddress, address NFTAddress, uint256 NFTTokenID
    , uint256 pricePerHour, uint256 MaxRentalHours, uint256 StartRentTime,uint256 EndRentTime) {
        require(_tokenId > 0 && _tokenId <= tokenCount, "Invalid panelId");

        TokenInfo memory rentableToken = rentableTokens[_tokenId];
        TokenInfo memory tokenData = rentableToken;
        if (!isRented(_tokenId)) {
            tokenData.rentalInfo.StartRentTime = 0;
            tokenData.rentalInfo.EndRentTime = 0;
            tokenData.rentalInfo.RenterAddress = address(0);
            tokenData.rentalInfo.NFTAddress = rentableToken.NFTAddress;
            tokenData.rentalInfo.NFTTokenID = rentableToken.NFTTokenID;
        } else {
            tokenData.availableForRenting = false;

            if(rentableToken.rentableNFT == true && rentableToken.rentalInfo.NFTAddress == address(0)){
                tokenData.rentalInfo.NFTAddress = rentableToken.NFTAddress;
                tokenData.rentalInfo.NFTTokenID = rentableToken.NFTTokenID;
            }
        }

        return (tokenData.rentalInfo.RenterAddress, tokenData.rentalInfo.NFTAddress, tokenData.rentalInfo.NFTTokenID
        ,tokenData.rentalInfo.pricePerHour,tokenData.rentalInfo.MaxRentalHours,tokenData.rentalInfo.StartRentTime,tokenData.rentalInfo.EndRentTime);
    }


    
    // Function to set the transformation of a token
    function setTokenTransform (
        uint256 _tokenId,
        int256 _locationX,
        int256 _locationY,
        int256 _locationZ,
        int256 _rotationX,
        int256 _rotationY,
        int256 _rotationZ,
        int256 _scaleX,
        int256 _scaleY,
        int256 _scaleZ
    ) public onlyOwner{
        require(_tokenId > 0 && _tokenId <= tokenCount, "Invalid tokenId");

        TokenInfo storage rentableToken = rentableTokens[_tokenId];
        TokenTransform storage tokenTransform = rentableToken.tokenTransform;

        // Update the transformation values
        tokenTransform.locationX = _locationX;
        tokenTransform.locationY = _locationY;
        tokenTransform.locationZ = _locationZ;
        tokenTransform.rotationX = _rotationX;
        tokenTransform.rotationY = _rotationY;
        tokenTransform.rotationZ = _rotationZ;
        tokenTransform.scaleX = _scaleX;
        tokenTransform.scaleY = _scaleY;
        tokenTransform.scaleZ = _scaleZ;
    }

    // Define a function to check if a rentable token is currently rented
    function isRented(uint256 _tokenId) public view returns (bool) {
        require(_tokenId > 0 && _tokenId <= tokenCount, "Invalid panelId");
        TokenInfo memory rentableToken = rentableTokens[_tokenId];

        bool isRentedVal = false;
        if (block.timestamp < rentableToken.rentalInfo.EndRentTime) {
            isRentedVal = true;
        }
        return isRentedVal;
    }

   

     // Define a function to set the availability of a rentable token
    function setRentingAvailability(uint256 _tokenId, bool _available, bool _rentableNFT, uint256 _pricePerHour, uint _maxRentalHours) public {
        // Get the rentable token struct from the mapping
        TokenInfo storage rentableToken = rentableTokens[_tokenId];

        // Check if the caller is the owner of the rentable token
        require(msg.sender == rentableToken.owner, "Only the owner can change the availability of the panel");

        // Set the availability of the panel
        rentableToken.availableForRenting = _available;
        rentableToken.rentableNFT = _rentableNFT;
        rentableToken.rentalInfo.pricePerHour = _pricePerHour;
        rentableToken.rentalInfo.MaxRentalHours = _maxRentalHours;

    }

    function setTokenPrice(uint256 _tokenId, uint256 _price) public {
        // Get the rentable token struct from the mapping
        TokenInfo storage rentableToken = rentableTokens[_tokenId];

        // Check if the caller is the owner of the rentable token or the renter
        require(msg.sender == rentableToken.owner , "Only the owner can change metadata");

        // Set the price of the rentable token
        rentableToken.holderPrice = _price;
        // Set the sale statement of the rentable token

    }

      function checkNFTOwner(address _userAddress, address NFTAddress, uint256 tokenId) public view returns (bool) {
        // Check if the contract supports ERC721 or ERC1155 interfaces
        require(
            IERC165(NFTAddress).supportsInterface(type(IERC721).interfaceId) ||
            IERC165(NFTAddress).supportsInterface(type(IERC1155).interfaceId),
            "Unsupported NFT contract"
        );

        // Check if the _user is the owner of the specified NFT
        if (IERC165(NFTAddress).supportsInterface(type(IERC721).interfaceId)) {
            // If it's ERC721
            return IERC721(NFTAddress).ownerOf(tokenId) == _userAddress;
        } else if (IERC165(NFTAddress).supportsInterface(type(IERC1155).interfaceId)) {
            // If it's ERC1155
            return IERC1155(NFTAddress).balanceOf(_userAddress, tokenId) > 0;
        } else {
            // Handle other types of NFT contracts as needed
            revert("Unsupported NFT contract");
        }
    }
       // Define a function to set the metadata of a rentable token
    function setNFTAddress(uint256 _tokenId, address _NFTAddress, uint256 _nftTokenId, uint256 _NFTPrice) public {
        // Get the rentable token struct from the mapping
        TokenInfo storage rentableToken = rentableTokens[_tokenId];
        
        // Check if the caller is the owner of the rentable token or the renter
        require(msg.sender == rentableToken.owner && isRented(_tokenId) == false 
        ||
        msg.sender == rentableToken.rentalInfo.RenterAddress && isRented(_tokenId) == true, "Only the owner or renter can change nft address");
        
        require(checkNFTOwner(msg.sender ,_NFTAddress, _nftTokenId) == true 
        || (rentableToken.rentableNFT == true && checkNFTOwner(rentableToken.owner, _NFTAddress, _nftTokenId) == true) 
        || _NFTAddress == address(0)
        , "Sender is not allowed to use this NFT");

        // Set the nft address of the rentable token for the owner
        if(msg.sender == rentableToken.owner){
            //require(isNFTApproved(rentableToken.owner, rentableToken.NFTAddress, rentableToken.NFTTokenID) == true, "NFT isn't approved for the contract to use it");
            rentableToken.NFTAddress = _NFTAddress;
            rentableToken.NFTTokenID = _nftTokenId;
            rentableToken.NFTPrice = _NFTPrice;
        }
        // Set the metadata of the rentable token for the renter
        if(msg.sender == rentableToken.rentalInfo.RenterAddress && isRented(_tokenId) == true){
            //require(isNFTApproved(rentableToken.rentalInfo.RenterAddress, rentableToken.rentalInfo.NFTAddress, rentableToken.rentalInfo.NFTTokenID) == true, "NFT isn't approved for the contract to use it");
            rentableToken.rentalInfo.NFTAddress = _NFTAddress;
            rentableToken.rentalInfo.NFTTokenID = _nftTokenId;
            rentableToken.rentalInfo.NFTPrice = _NFTPrice;
        }
        
    }

    // Define a function to check if the contract supports ERC721 interface
    function supportsERC721(address contractAddress) internal view returns (bool) {
        bytes4 interfaceId = 0x80ac58cd; // ERC721 interface ID
        (bool success, bytes memory result) = contractAddress.staticcall(abi.encodeWithSelector(IERC165.supportsInterface.selector, interfaceId));
        return success && result.length > 0;
    }

    // Define a function to check if the contract supports ERC1155 interface
    function supportsERC1155(address contractAddress) internal view returns (bool) {
        bytes4 interfaceId = 0xd9b67a26; // ERC1155 interface ID
        (bool success, bytes memory result) = contractAddress.staticcall(abi.encodeWithSelector(IERC165.supportsInterface.selector, interfaceId));
        return success && result.length > 0;
    }


    // Define a function to check if the NFT is approved for the current contract
    function isNFTApproved(address nftOwner,address nftContractAddress, uint256 tokenId) internal view returns (bool) {
        // Check if the contract supports ERC721 or ERC1155 interface
        bool isSupportsERC721 = supportsERC721(nftContractAddress);
        bool isSupportsERC1155 = supportsERC1155(nftContractAddress);

        require(isSupportsERC721 || isSupportsERC1155, "Unsupported NFT type");

        // If ERC721 is supported, check ERC721 approval
        if (isSupportsERC721) {
            address owner = IERC721(nftContractAddress).ownerOf(tokenId);
            return owner == address(this) || IERC721(nftContractAddress).getApproved(tokenId) == address(this) || IERC721(nftContractAddress).isApprovedForAll(owner, address(this));
        }
        // If ERC1155 is supported, check ERC1155 approval
        else if (isSupportsERC1155) {
            return IERC1155(nftContractAddress).isApprovedForAll(nftOwner, address(this));
        }

        revert("Unsupported NFT type");
    }




    // Define a function to get rentable token metadata
    function getNFTAddress(uint256 _tokenId) public view returns (address _NFTAddress, uint256 _nftTokenId) {
        require(_tokenId > 0 && _tokenId <= tokenCount, "Invalid panelId");
        TokenInfo memory rentableToken = rentableTokens[_tokenId];

        if (isRented(_tokenId)) {
            if(rentableToken.rentableNFT == true && rentableToken.rentalInfo.NFTAddress == address(0)){
                _NFTAddress = rentableToken.NFTAddress;
                _nftTokenId = rentableToken.NFTTokenID;
            }else{
                _NFTAddress = rentableToken.rentalInfo.NFTAddress;
                _nftTokenId = rentableToken.rentalInfo.NFTTokenID;
            }
            
        } else {
            _NFTAddress = rentableToken.NFTAddress;
            _nftTokenId = rentableToken.NFTTokenID;
        }
        return (_NFTAddress, _nftTokenId);
    }

    // Define a function to buy a rentable token
    function BuyHolder(uint256 _tokenId) public {
        // Get the rentable token struct from the mapping
        TokenInfo storage rentableToken = rentableTokens[_tokenId];
        // Check if the rentable token is available for sale
        require(rentableToken.holderPrice > 0, "Token is not available for sale");
        // Check if the buyer isn't the owner of the rentable token
        require(msg.sender != rentableToken.owner, "Owners cannot buy their own tokens");
        // Check if the buyer has sent enough tokens
        require(ERC20(rentableToken.currencyToken).allowance(msg.sender, address(this)) >= rentableToken.holderPrice, "Not enough tokens");
         // Transfer the price to the owner of the rentable token
        require(ERC20(rentableToken.currencyToken).transferFrom(msg.sender, rentableToken.owner, rentableToken.holderPrice), "Transfer failed");

        // Transfer the rentable token ownership to the buyer
        rentableToken.owner = msg.sender;
        rentableToken.NFTAddress = address(0);
        rentableToken.NFTTokenID = 0;
        // Set the availability of the rentable token to false
        rentableToken.availableForRenting = false;
        rentableToken.holderPrice = 0;
    }

    function BuyNFT(uint256 _tokenId) public {
        // Get the rentable token struct from the mapping
        TokenInfo storage rentableToken = rentableTokens[_tokenId];
        
        if(isRented(_tokenId)){

            require(rentableToken.rentalInfo.NFTPrice > 0, "NFT is not available for sale");
            require(checkNFTOwner(msg.sender, rentableToken.rentalInfo.NFTAddress, rentableToken.rentalInfo.NFTTokenID), "Owners cannot buy their own tokens");
            //require(isNFTApproved(rentableToken.owner, rentableToken.NFTAddress, rentableToken.NFTTokenID), "NFT isn't approved for this contract currently");
            require(ERC20(rentableToken.currencyToken).allowance(msg.sender, address(this)) >= rentableToken.rentalInfo.NFTPrice, "Not enough tokens");
            
             if (supportsERC721(rentableToken.rentalInfo.NFTAddress)) {
            IERC721(rentableToken.rentalInfo.NFTAddress).safeTransferFrom(rentableToken.rentalInfo.RenterAddress, msg.sender, rentableToken.rentalInfo.NFTTokenID);
            } else if (supportsERC1155(rentableToken.rentalInfo.NFTAddress)) {
                IERC1155(rentableToken.rentalInfo.NFTAddress).safeTransferFrom(rentableToken.rentalInfo.RenterAddress, msg.sender, rentableToken.rentalInfo.NFTTokenID, 1, "");
            } else {
                revert("Unsupported NFT type");
            }
            
            require(ERC20(rentableToken.currencyToken).transferFrom(msg.sender, rentableToken.rentalInfo.RenterAddress, rentableToken.rentalInfo.NFTPrice), "Transfer failed");

            rentableToken.rentalInfo.NFTAddress = address(0);
            rentableToken.rentalInfo.NFTTokenID = 0;
            rentableToken.rentalInfo.NFTPrice = 0;
            
        }else{
            require(rentableToken.NFTPrice > 0, "NFT is not available for sale");
            require(checkNFTOwner(msg.sender, rentableToken.NFTAddress, rentableToken.NFTTokenID), "Owners cannot buy their own tokens");
            //require(isNFTApproved(rentableToken.rentalInfo.RenterAddress, rentableToken.rentalInfo.NFTAddress, rentableToken.rentalInfo.NFTTokenID), "NFT isn't approved for this contract currently");
            require(ERC20(rentableToken.currencyToken).allowance(msg.sender, address(this)) >= rentableToken.NFTPrice, "Not enough tokens");
            
            if (supportsERC721(rentableToken.NFTAddress)) {
            IERC721(rentableToken.NFTAddress).safeTransferFrom(rentableToken.owner, msg.sender, rentableToken.NFTTokenID);
            } else if (supportsERC1155(rentableToken.NFTAddress)) {
                IERC1155(rentableToken.NFTAddress).safeTransferFrom(rentableToken.owner, msg.sender, rentableToken.NFTTokenID, 1, "");
            }
            require(ERC20(rentableToken.currencyToken).transferFrom(msg.sender, rentableToken.owner, rentableToken.NFTPrice), "Transfer failed");

            

            rentableToken.NFTAddress = address(0);
            rentableToken.NFTTokenID = 0;
            rentableToken.NFTPrice = 0;
            
        }

        
    }


    // Define a function to buy a rentable token
    function ChangeOwnership(uint256 _tokenId, address _to) public {
        // Get the rentable token struct from the mapping
        TokenInfo storage rentableToken = rentableTokens[_tokenId];
        // Check if the buyer isn't the owner of the rentable token
        require(msg.sender == rentableToken.owner, "Only Owner can change the ownership");

        rentableToken.owner = _to;
        rentableToken.NFTAddress = address(0);
        rentableToken.NFTTokenID = 0;
        // Set the availability of the rentable token to false
        rentableToken.availableForRenting = false;
        rentableToken.holderPrice = 0;
    }


}




    





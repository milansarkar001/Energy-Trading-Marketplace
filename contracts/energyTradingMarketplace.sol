// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Energy Trading Marketplace
 * @dev A decentralized marketplace for peer-to-peer energy trading
 * @author Energy Trading Team
 */
contract Project {
    
    // Struct to represent an energy listing
    struct EnergyListing {
        uint256 id;
        address seller;
        uint256 energyAmount; // in kWh
        uint256 pricePerKWh; // in wei
        uint256 totalPrice;
        bool isActive;
        uint256 timestamp;
        string energySource; // "solar", "wind", "hydro", etc.
    }
    
    // Struct to represent an energy purchase
    struct EnergyPurchase {
        uint256 listingId;
        address buyer;
        address seller;
        uint256 energyAmount;
        uint256 totalPaid;
        uint256 timestamp;
        bool isCompleted;
    }
    
    // State variables
    mapping(uint256 => EnergyListing) public energyListings;
    mapping(address => uint256) public sellerBalances;
    mapping(uint256 => EnergyPurchase) public energyPurchases;
    
    uint256 public nextListingId;
    uint256 public nextPurchaseId;
    uint256 public constant PLATFORM_FEE_PERCENTAGE = 2; // 2% platform fee
    
    address public owner;
    uint256 public totalEnergyTraded;
    uint256 public totalTransactions;
    
    // Events
    event EnergyListed(
        uint256 indexed listingId,
        address indexed seller,
        uint256 energyAmount,
        uint256 pricePerKWh,
        string energySource
    );
    
    event EnergyPurchased(
        uint256 indexed purchaseId,
        uint256 indexed listingId,
        address indexed buyer,
        address seller,
        uint256 energyAmount,
        uint256 totalPaid
    );
    
    event FundsWithdrawn(
        address indexed seller,
        uint256 amount
    );
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier validListing(uint256 _listingId) {
        require(_listingId < nextListingId, "Invalid listing ID");
        require(energyListings[_listingId].isActive, "Listing is not active");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        nextListingId = 1;
        nextPurchaseId = 1;
    }
    
    /**
     * @dev Core Function 1: List energy for sale
     * @param _energyAmount Amount of energy in kWh
     * @param _pricePerKWh Price per kWh in wei
     * @param _energySource Type of energy source (solar, wind, etc.)
     */
    function listEnergy(
        uint256 _energyAmount,
        uint256 _pricePerKWh,
        string memory _energySource
    ) external {
        require(_energyAmount > 0, "Energy amount must be greater than 0");
        require(_pricePerKWh > 0, "Price per kWh must be greater than 0");
        require(bytes(_energySource).length > 0, "Energy source cannot be empty");
        
        uint256 totalPrice = _energyAmount * _pricePerKWh;
        
        energyListings[nextListingId] = EnergyListing({
            id: nextListingId,
            seller: msg.sender,
            energyAmount: _energyAmount,
            pricePerKWh: _pricePerKWh,
            totalPrice: totalPrice,
            isActive: true,
            timestamp: block.timestamp,
            energySource: _energySource
        });
        
        emit EnergyListed(
            nextListingId,
            msg.sender,
            _energyAmount,
            _pricePerKWh,
            _energySource
        );
        
        nextListingId++;
    }
    
    /**
     * @dev Core Function 2: Purchase energy from a listing
     * @param _listingId ID of the energy listing to purchase
     */
    function purchaseEnergy(uint256 _listingId) 
        external 
        payable 
        validListing(_listingId) 
    {
        EnergyListing storage listing = energyListings[_listingId];
        
        require(msg.sender != listing.seller, "Cannot purchase your own energy");
        require(msg.value == listing.totalPrice, "Incorrect payment amount");
        
        // Calculate platform fee
        uint256 platformFee = (msg.value * PLATFORM_FEE_PERCENTAGE) / 100;
        uint256 sellerAmount = msg.value - platformFee;
        
        // Update seller balance
        sellerBalances[listing.seller] += sellerAmount;
        
        // Create purchase record
        energyPurchases[nextPurchaseId] = EnergyPurchase({
            listingId: _listingId,
            buyer: msg.sender,
            seller: listing.seller,
            energyAmount: listing.energyAmount,
            totalPaid: msg.value,
            timestamp: block.timestamp,
            isCompleted: true
        });
        
        // Update marketplace statistics
        totalEnergyTraded += listing.energyAmount;
        totalTransactions++;
        
        // Deactivate the listing
        listing.isActive = false;
        
        emit EnergyPurchased(
            nextPurchaseId,
            _listingId,
            msg.sender,
            listing.seller,
            listing.energyAmount,
            msg.value
        );
        
        nextPurchaseId++;
    }
    
    /**
     * @dev Core Function 3: Withdraw earnings from energy sales
     */
    function withdrawEarnings() external {
        uint256 balance = sellerBalances[msg.sender];
        require(balance > 0, "No earnings to withdraw");
        
        sellerBalances[msg.sender] = 0;
        
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        require(success, "Withdrawal failed");
        
        emit FundsWithdrawn(msg.sender, balance);
    }
    
    // View functions
    function getActiveListing(uint256 _listingId) 
        external 
        view 
        returns (EnergyListing memory) 
    {
        require(_listingId < nextListingId, "Invalid listing ID");
        return energyListings[_listingId];
    }
    
    function getSellerBalance(address _seller) external view returns (uint256) {
        return sellerBalances[_seller];
    }
    
    function getPurchaseDetails(uint256 _purchaseId) 
        external 
        view 
        returns (EnergyPurchase memory) 
    {
        require(_purchaseId < nextPurchaseId, "Invalid purchase ID");
        return energyPurchases[_purchaseId];
    }
    
    function getMarketplaceStats() 
        external 
        view 
        returns (uint256, uint256, uint256) 
    {
        return (totalEnergyTraded, totalTransactions, nextListingId - 1);
    }
    
    // Owner functions
    function withdrawPlatformFees() external onlyOwner {
        uint256 contractBalance = address(this).balance;
        require(contractBalance > 0, "No fees to withdraw");
        
        (bool success, ) = payable(owner).call{value: contractBalance}("");
        require(success, "Fee withdrawal failed");
    }
    
    // Emergency function to deactivate a listing (only owner)
    function deactivateListing(uint256 _listingId) external onlyOwner {
        require(_listingId < nextListingId, "Invalid listing ID");
        energyListings[_listingId].isActive = false;
    }
}

pragma solidity >= 0.4.20 < 0.6.0;

import "contracts/DeedRepository.sol";
import "openzeppelin-solidity/contracts/token/ERC721/ERC721.sol";

contract AuctionRepository is ERC721{

    string public name;
    string public symbol;

    Auction[] public auctions;

    mapping(uint => Bid[]) auctionBids;
    mapping(address => uint[]) auctionOwner;


    struct Auction{
        string name;
        uint256 blockDeadline;
        uint256 startPrice;
        string metadata;
        uint256 deedId;
        address owner;
        address deedRepositoryAddress;
        bool active;
        bool finalized;
    }

    struct Bid{
        address from;
        uint256 amount;
    }


    modifier isOwner(uint _auctionId){
        require(auctions[_auctionId].owner == msg.sender);
        _;
    }

    modifier contractIsDeedOwner(address _deedRepositoryAddress, uint256 _deedId){
        address deedOwner = DeedRepository(_deedRepositoryAddress).ownerOf(_deedId);
        require(deedOwner == address(this));
        _;
    }

    constructor(string memory _name, string memory _symbol) public {
          name = _name;
          symbol = _symbol;
    }

    function() external{
        revert();
    }

    //need to see replacement for constant
    function getCount() public view returns(uint){
        return auctions.length;
    }

    function getBidsCount(uint _auctionId) public view returns(uint){
        return auctionBids[_auctionId].length;
    }

    function getActionsOf(address _owner) public view returns(uint[] memory) {
        uint[] memory ownedActions = auctionOwner[_owner];
        return ownedActions;
    }

    function getCurrentBid(uint _auctionId) public view returns(uint256, address) {
        uint bidsLength = auctionBids[_auctionId].length;

        if( bidsLength > 0 ) {
            Bid memory lastBid = auctionBids[_auctionId][bidsLength - 1];
            return (lastBid.amount, lastBid.from);
        }
       // return (0,"0");
    }

    function getAuctionsCountOfOwner(address _owner) public returns(uint) {
        return auctionOwner[_owner].length;
    }

    function getAuctionById( uint _auctionId ) public view returns(
        string memory name,
        uint256 blockDeadline,
        uint256 startPrice,
        string memory metadata,
        uint256 deedId,
        address deedRepositoryAddress,
        address owner,
        bool active,
        bool finalized
        ) {

        Auction memory auc = auctions[_auctionId];
        return (
            auc.name,
            auc.blockDeadline,
            auc.startPrice,
            auc.metadata,
            auc.deedId,
            auc.deedRepositoryAddress,
            auc.owner,
            auc.active,
            auc.finalized
            );

    }

    function createAuction(address _deedRepositoryAddress,
                            uint256 _deedId, string memory _auctionTitle,
                            string memory _metadata, uint256 _startPrice,
                            uint _blockDeadline)
                            public contractIsDeedOwner(_deedRepositoryAddress, _deedId )
                            returns(bool){
                                uint aunctionId = auctions.length;
                                Auction memory newAuction;
                                newAuction.name = _auctionTitle;
                                newAuction.blockDeadline = _blockDeadline;
                                newAuction.startPrice = _startPrice;
                                newAuction.metadata  = _metadata;
                                newAuction.deedId = _deedId;
                                newAuction.deedRepositoryAddress = _deedRepositoryAddress;
                                newAuction.owner = msg.sender;
                                newAuction.active = true;
                                newAuction.finalized = false;

                                auctions.push(newAuction);
                                auctionOwner[msg.sender].push(aunctionId);
                                emit AuctionCreated(msg.sender,aunctionId);
}

function approveAndTransfer(
    address _from, address _to,
    address _deedRepositoryAddress,
    uint256 _deedId) internal returns(bool){
        DeedRepository remoteContract = DeedRepository(_deedRepositoryAddress);
        remoteContract.approve(_to, _deedId);
        remoteContract.transferFrom(_from, _to, _deedId);
        return true;
    }

  function cancelAuction(uint _auctionId) public isOwner(_auctionId) {
      Auction memory myAuction = auctions[_auctionId];
      uint bidsLength = auctionBids[_auctionId].length;

        // if there are bids refund the last bid
        if( bidsLength > 0 ) {
            Bid memory lastBid = auctionBids[_auctionId][bidsLength - 1];
            if(!address(uint160(lastBid.from)).send(lastBid.amount)) {
                revert();
            }
        }

        // approve and transfer from this contract to auction owner
        if(approveAndTransfer(address(this), myAuction.owner, myAuction.deedRepositoryAddress, myAuction.deedId)){
            auctions[_auctionId].active = false;
            emit AuctionCanceled(msg.sender, _auctionId);
        }
    }


function finalizeAuction(uint _auctionId) public {
    Auction memory myAuction = auctions[_auctionId];
    uint bidsLength = auctionBids[_auctionId].length;

    if(block.timestamp < myAuction.blockDeadline) revert();

    if(bidsLength == 0){
        cancelAuction(_auctionId);
    }else{
        Bid memory lastBid = auctionBids[_auctionId][bidsLength - 1];
        if(!address(uint160(myAuction.owner)).send(lastBid.amount)) {
         revert();

         if(approveAndTransfer(address(this), lastBid.from, myAuction.deedRepositoryAddress, myAuction.deedId)){
                auctions[_auctionId].active = false;
                auctions[_auctionId].finalized = true;
                emit AuctionFinalized(msg.sender, _auctionId);
            }
    }
}

}

function bidOnAuction(uint _auctionId) public payable{
    uint256 ethAmountSent = msg.value;

    Auction memory myAuction = auctions[_auctionId];
    if(myAuction.owner == msg.sender) revert();
    if(block.timestamp > myAuction.blockDeadline) revert();

    uint bidsLength = auctionBids[_auctionId].length;
    uint256 tempAmount = myAuction.startPrice;
    Bid memory lastBid;

    if(bidsLength > 0){
        lastBid = auctionBids[_auctionId][bidsLength  - 1];
        tempAmount = lastBid.amount;
    }

    if(ethAmountSent < tempAmount) revert();

    if(bidsLength > 0){
        if(!address(uint160(lastBid.from)).send(lastBid.amount)){
            revert();
        }

    }

    Bid memory newBid;
    newBid.from = msg.sender;
    newBid.amount = ethAmountSent;
    auctionBids[_auctionId].push(newBid);
    emit BidSuccess(msg.sender,_auctionId);

}


 event BidSuccess(address _from , uint _auctionId);
    event AuctionCreated(address _owner, uint _auctionId);
    event AuctionCanceled(address _owner, uint _auctionId);
    event AuctionFinalized(address _owner, uint _auctionId);

}

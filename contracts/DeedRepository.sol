pragma solidity >= 0.4.20 < 0.6.0;


import "openzeppelin-solidity/contracts/token/ERC721/ERC721Metadata.sol";
//import "openzeppelin-solidity/contracts/token/ERC721/ERC721.sol";

contract DeedRepository is ERC721Metadata{



    string private name = "Smaution";
    string private symbol = "SMAT";

    event addDeed(address _by,uint256 _tokenId);

    constructor(string memory _name, string memory _symbol) public {

        name = _name;
        symbol = _symbol;
    }

    function registerDeed(uint256 _tokenId, string memory _uri) public {
        _mint(msg.sender, _tokenId);

        //need to create event
        emit addDeed(msg.sender, _tokenId);
    }

    function addDeedMetadata(uint256 _tokenId, string memory _uri) public returns(bool) {
        _setTokenURI(_tokenId,_uri);
        return true;
    }

}

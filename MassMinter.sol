// SPDX-License-Identifier: UNLICENSED
//   __  __                 __  __ _       _            
//  |  \/  |               |  \/  (_)     | |           
//  | \  / | __ _ ___ ___  | \  / |_ _ __ | |_ ___ _ __ 
//  | |\/| |/ _` / __/ __| | |\/| | | '_ \| __/ _ \ '__|
//  | |  | | (_| \__ \__ \ | |  | | | | | | ||  __/ |   
//  |_|  |_|\__,_|___/___/ |_|  |_|_|_| |_|\__\___|_|   

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract Minter is Ownable {

    mapping(address => bool) public Allowed;
    mapping(address => SubMinter[]) public Minters;

    modifier isAllowed {
        require(Allowed[msg.sender] || msg.sender == owner());
        _;
    }

    // Owner Functions

    function destroy() external onlyOwner {
        address payable addr = payable(msg.sender);
        selfdestruct(addr);
    }

    function withdrawEther() external onlyOwner {
        address payable addr = payable(msg.sender);
        addr.transfer(address(this).balance);
    }

    function setAllowed(address _user) external onlyOwner {
        Allowed[_user] = !Allowed[_user];
    }

    // Main Functions

    function spawnMinters(uint256 _qty) external isAllowed {
        for (uint256 i; i < _qty; i++) {
            SubMinter minter = new SubMinter();
            Minters[msg.sender].push(minter);
        }
    }

    function destroyMinters() external isAllowed {
        for (uint256 x = 0; x < Minters[msg.sender].length; x++) {
            Minters[msg.sender][x].destroy();
        }
        delete Minters[msg.sender];
    }

    function transfer(uint256 _minter, address _tokenAddress, uint256 _start, uint256 _end, address _receiver) external isAllowed {
        Minters[msg.sender][_minter].transfer(_tokenAddress, _start, _end, _receiver);
    }

    function mint(address _target, uint256 _cost, bytes memory _data, bool _transfer, uint256 _iterations, uint256 _minters) external payable isAllowed {
        require(_minters <= Minters[msg.sender].length);
        for (uint256 i; i < _minters; i++) {
            Minters[msg.sender][i].settings(msg.sender, _target, _cost, _data, _transfer, _iterations);
            Minters[msg.sender][i].mint{value: _cost}();
        }
    }

}

contract SubMinter is Ownable, IERC721Receiver {

    address public receiver;
    address public target;
    uint256 public cost;
    uint256 public iterations;
    bool    public transferTokens;
    bytes   public data;

    function destroy() external onlyOwner {
        address payable addr = payable(msg.sender);
        selfdestruct(addr);
    }

    function transfer(address _tokenAddress, uint256 _start, uint256 _end, address _receiver) external onlyOwner {
        for (uint256 i = _start; i <= _end; i++) {
            IERC721 sender = IERC721(_tokenAddress);
            sender.transferFrom(address(this), _receiver, i);
        }
    }

    function settings(address _receiver, address _target, uint256 _cost, bytes memory _data, bool _transfer, uint256 _iterations) external onlyOwner {
        receiver = _receiver;
        target = _target;
        cost = _cost;
        data = _data;
        transferTokens = _transfer;
        iterations = _iterations;
    }

    function mint() external payable onlyOwner {
        for (uint256 i; i < iterations; i++) {
            (bool success, ) = target.call{value: cost}(data);
            require(success);
        }
    }

    function onERC721Received(
        address operator,
        address,
        uint256 tokenId,
        bytes memory
    ) public virtual override returns (bytes4) {
        if (transferTokens) {
            IERC721 sender = IERC721(msg.sender);
            sender.transferFrom(operator, receiver, tokenId);
        }
        return this.onERC721Received.selector;
    }

}
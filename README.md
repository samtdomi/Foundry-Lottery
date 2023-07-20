# Verifiable Random Lottery Contract

## About

The purpose of this contract is to create a verifiably random smart contract lottery

## What we want it to do?

1. Users can enter by paying for a ticket
   - Ticket fees are going to the winner after the draw
2. After X period of time, the lottery will automatically draw a winner
   - this step will be done Completely Programatically
3. Using Chainlink VRF and Chainlink Automation
   - Chainlink VRF -> Randomness (Verifiable)
   - Chainlink Automation -> Time Based Trigger
     - Used to randomly trigger the lottery to run/draw, and select a new winner

## Tests!!!!!

1. write some deploy scripts
2. write our tests
   1. local chain - Anvil
   2. forked testnet - Sepolia ETH
   3. forked mainnet - ETH

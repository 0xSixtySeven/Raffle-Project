# Provenly Random Raffle Contract Lottery

## About

This code is to create a provenly random smart contract lottery. The code is based on the [Ethereum Lottery]

## What is this about?

1. Users can enter the paying for a ticket
   1. The ticket fees are going to go to the winner during the draw.
2. After a period amount in time, the lottery will close and automatically a winner will be selected.
   1. And this will be done in a provenly random way by programmatically. 
3. To make this structure we are using two ways to englobe the certantly that it wil be automated and completely random with two tools:
   1. Chainlink VRF: This is a decentralized oracle that will provide the random number to the smart contract. -> Randomness
   2. Chainlink automation: This is a decentralized oracle that will provide the time to the smart contract. -> Time based Trigger
    

## TESTS

1. Write some deploy scripts
2. Write some tests
   1. work on a local test
   2. forked testnet
   3. forked in mainnet
   
# FlightSurety Project

## Project Overview

1. Flight Surety is a project to manage collaboration between multiple airlines for flight delay insurance.
2. Passengers can purchase insurance prior to flight. If flight is delayed, passengers are paid 1.5x the amount they paid for the insurance.
3. By checking the flight status provided by Oracles, the smart contract can decide to give payout if the flight is delayed. The payout is credited automatically to the passenger's Ethereum wallet mapping in the contract, passenger can then withdraw from it.
4. The project will be separated into 4 main parts. The smart contract for data, smart contract for app logic, the front-end dapp client, and an oracle server.

#### Airline
1. For simplicity, when contract is deployed, one airline is automatically registered. It then will have the privilege to add other airline. Any registered airline can add other airlines until there are 4 airlines registered.
2. After there are 4 airlines, registration of subsequent airline will require a multiparty consensus of 50% of the registered airlines
3. After registered, airline need to pay 10 ether for them to be active

#### Passengers
1. Passengers may pay up to 1 ether for the insurance, and if flight is delayed the will be credited 1.5x the amount.
2. For simplicity, flight numbers and timestamp are hardcoded in the front-end dapp parts. We could extend this by connecting to a 3rd party API for the flight info.

#### Oracles
1. There will be 1 backend server which simulates 20 oracles response.
2. Upon startup, 20 oracles are registered and their assigned indexes are persisted in memory.
3. Ideally, when there is a flight status update, our own app server (or 3rd party api or another oracles) will call the smart contract to trigger a function that emit event to the oracles. The oracles will then fetch data and return data to the smart contract. However, since we don't have the mean to check the required flight info, the trigger will be a button in the front-end client dapp.
4. The server (which simulates 20 oracles) will pick oracles which have been chosen by the smart contract, these oracles will response with random status code of Unknown (0), On Time (10) or Late Airline (20), Late Weather (30), Late Technical (40), or Late Other (50)

## Architecture




## Install

This repository contains Smart Contract code in Solidity (using Truffle), tests (also using Truffle), dApp scaffolding (using HTML, CSS and JS) and server app scaffolding.

To install, download or clone the repo, then:

`npm install`
`truffle compile`

## Develop Client

To run truffle tests:

`truffle test ./test/flightSurety.js`
`truffle test ./test/oracles.js`

To use the dapp:

`truffle migrate`
`npm run dapp`

To view dapp:

`http://localhost:8000`

## Develop Server

`npm run server`
`truffle test ./test/oracles.js`

## Deploy

To build dapp for prod:
`npm run dapp:prod`

Deploy the contents of the ./dapp folder


## Resources

* [How does Ethereum work anyway?](https://medium.com/@preethikasireddy/how-does-ethereum-work-anyway-22d1df506369)
* [BIP39 Mnemonic Generator](https://iancoleman.io/bip39/)
* [Truffle Framework](http://truffleframework.com/)
* [Ganache Local Blockchain](http://truffleframework.com/ganache/)
* [Remix Solidity IDE](https://remix.ethereum.org/)
* [Solidity Language Reference](http://solidity.readthedocs.io/en/v0.4.24/)
* [Ethereum Blockchain Explorer](https://etherscan.io/)
* [Web3Js Reference](https://github.com/ethereum/wiki/wiki/JavaScript-API)
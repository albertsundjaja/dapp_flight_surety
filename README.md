# FlightSurety Project

## Project Overview

1. Flight Surety is a project to manage collaboration between multiple airlines for flight delay insurance.
2. Passengers can purchase insurance prior to flight. If flight is delayed because of airline fault, passengers are paid 1.5x the amount they paid for the insurance.
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


## Installation

To avoid errors, make sure that the following tools and versions are installed:
```
Truffle v5.0.13 (core: 5.0.13)
Solidity - 0.5.2 (solc-js)
Node v8.10.0
Web3.js v1.0.0-beta.37
```

This repository contains Smart Contract code in Solidity (using Truffle), tests (also using Truffle), dApp scaffolding (using HTML, CSS and JS) and server app scaffolding.

To install, download or clone the repo, then install dependency:
```
$ npm install
```

1. run `ganache`. by default, the server will assume ganache is running on `port 8545`. make sure there are at least 20 accounts in ganache.

2. change the first airline address inside `2_deploy_contracts.js` to your first desired airline address (if you are using ganache, pick the second account)

3. deploy into ganache

```
$ truffle migrate --reset
```

**note** everytime you redeploy, remember to delete the `build` folder to avoid conflict

4. run the server, and wait until oracle registration completed

```
$ npm run server
```

5. run the dapp, it can then be viewed using your browser at `http://localhost:8000`

```
$ npm run dapp
```

6. Flights are hardcoded. Flight with flight number `ABC123` is the one who is set to be Late Airline fault. Insurance will be credited towards the passenger. To test out the insurance payout, buy insurance for this flight, and then click `Submit to Oracle (fetch flight status)`. Then click withdraw to get the payouts, you can check that the balance in ganace, it should increase by 1.5x the original insurance.

## Testing

To run truffle tests:

```
$ truffle test ./test/flightSurety.js
$ truffle test ./test/oracles.js
```
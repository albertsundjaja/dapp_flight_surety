import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';
import "babel-polyfill";
import cors from 'cors'

console.log("Starting server ...");

// helper functions

// search for flight inside the array
function searchFlight(flights, flightNumber) {
  for(var i = 0; i < flights.length; i++)
  {
    if(flights[i].flight == flightNumber) {
      return flights[i]
    }
    else {
      return null
    }
  }
}

// simulate an oracle
class Oracle {
  
  constructor(_address) {
    this.state = {
      // store assigned index by smart contract
      "indices": [],
      // store the address of this oracle
      "address": _address
    }
  }

  generateFlightInfo = (index, airline, flightNumber) => {
    if (this.state.indices.includes(index)) {
      let flightDetail = searchFlight(flights, flightNumber);
      console.log('flight detail', flightDetail);
      console.log('this oracle address', this.state.address);
      if (flightDetail) {
        flightSuretyApp.methods.submitOracleResponse(index, airline, flightNumber, flightDetail['timestamp'],
          flightDetail['flightStatus']).send({from:this.state.address});
        console.log("Oracle " + this.state.address + " responding " + flightDetail['flightStatus']);
      }
    }
  }

}


const STATUS_CODE_UNKNOWN = 0;
const STATUS_CODE_ON_TIME = 10;
const STATUS_CODE_LATE_AIRLINE = 20;
const STATUS_CODE_LATE_WEATHER = 30;
const STATUS_CODE_LATE_TECHNICAL = 40;
const STATUS_CODE_LATE_OTHER = 50;

// hardcoded flights detail
var now = new Date();
var dayUnix = 86400;
// flightStatus is what the status will be when get flight status is triggered from frontend
let flights = [
  {
    "flight":"ABC123",
    "timestamp":now.getTime() + 3 * dayUnix,
    "flightStatus":STATUS_CODE_LATE_AIRLINE,
    "airline": "0x8a0bc8a5eE22eCdb33b84Aa8D2Bfeb0a357010A4"
  },
  {
    "flight":"DEF321",
    "timestamp":now.getTime() + 3 * dayUnix,
    "flightStatus":STATUS_CODE_LATE_WEATHER,
    "airline": "0x8a0bc8a5eE22eCdb33b84Aa8D2Bfeb0a357010A4"
  },
  {
    "flight":"GHI321",
    "timestamp":now.getTime() + 3 * dayUnix,
    "flightStatus":STATUS_CODE_ON_TIME,
    "airline": "0x8a0bc8a5eE22eCdb33b84Aa8D2Bfeb0a357010A4"
  }
]

// store 20 simulated oracles
let oracles = []; 
var BigNumber = require('bignumber.js');
const weiMultiple = (new BigNumber(10)).pow(18);
let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
let flightSuretyData = new web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);

/* First run only
* comment out this block after first run
*/
/*
console.log("Registering oracles");
console.log(web3.eth.accounts);
web3.eth.getAccounts().then(async (accounts) => {
  console.log(accounts[0]);
  web3.eth.getAccounts().then(async (acc) => {
    console.log(accounts[0]);
    flightSuretyApp.methods.getMyIndexes().call({from:accounts[1]}).then((indices) =>{
      console.log("accounts i ", accounts[1]);
      let newOracle = new Oracle(accounts[1]);
      newOracle.state.indices = indices;
      oracles.push(newOracle);
    })
    .catch((err => {
      console.log(err);
    }))
  });
});
*/
web3.eth.getAccounts().then(async (accounts) => {
  // register 20 oracles and push to list of oracles
  for (var i = 0; i < 20; i++) {
    let account = accounts[i];
    flightSuretyApp.methods.getMyIndexes().call({from:account}).then((indices) =>{
      console.log("Initializing oracle ", account);
      let newOracle = new Oracle(account);
      newOracle.state.indices = indices;
      oracles.push(newOracle);
    })
    .catch((err => {
      // if error, then it is not registered yet
      flightSuretyApp.methods.registerOracle().send({from:account,value:1*weiMultiple,gasLimit: "4600000"}).then(
        (result)=>{
            flightSuretyApp.methods.getMyIndexes().call({from:account}).then((indices) =>{
                console.log("Registering oracle ", account);
                let newOracle = new Oracle(account);
                newOracle.state.indices = indices;
                oracles.push(newOracle);
              })
              .catch((err => {
                console.log(err);
              }))
        })
        .catch((err)=>console.log(err));
    }));
  }

  // register the app contract
  await flightSuretyData.methods.registerContract(config.appAddress).send({from:accounts[0]}).catch((err) => {
    console.log(err);
  });

  // pay ante for first airline, so that it is active
  await flightSuretyData.methods.isAirlineActive(accounts[1]).call().then(async (active) => {
    if (!active) {
      await flightSuretyData.methods.payAnte().send({from:accounts[1], value: 10 * weiMultiple}).catch((err) => {
        console.log(err);
      });
    }
  }).catch((err) => {
    console.log('is active');
    console.log(err);
  })

  // register flights
  for (var j = 0; j < flights.length; j++) {
    let flight = flights[j];
    flightSuretyData.methods.getFlight(flight['flight']).call().then((result) => {
      // if flight is not registered then register
      if (!result['_isRegistered']) {
        flightSuretyApp.methods.registerFlight(flight['flight'], flight['timestamp'])
        .send({from:accounts[1],gasLimit: "4600000"})
        .catch((err) => {
          console.log(err);
        })
      }
    })
    .catch((err) => {
      console.log('getflight');
      console.log(err)
    });
  
  }
});

// subscribe to event
console.log("Subscribing to event");

web3.eth.getBlockNumber().then((blockNumber) => {
  flightSuretyApp.events.FlightStatusInfo({
    fromBlock: blockNumber
  }, function (error, event) {
    if (error) console.log(error)

    console.log(event);
  });

  flightSuretyApp.events.OracleRequest({
    fromBlock: 0
  }, function (error, event) {
    if (error) console.log(error)
    let flight = event['returnValues']['flight'];
    let index = event['returnValues']['index'];
    let airline = event['returnValues']['airline'];
    for (var i = 0; i < oracles.length; i++) {
      oracles[i].generateFlightInfo(index, airline, flight);
    }
    
  });
})



const app = express();
app.use(cors());
app.get('/api', (req, res) => {
    res.send({
      message: 'An API for use with your Dapp!'
    })
})

app.get('/flights', (req, res) => {
  res.send({
    flights: flights
  })
})


export default app;



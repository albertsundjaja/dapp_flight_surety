import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import Config from './config.json';
import Web3 from 'web3';

export default class Contract {
    constructor(network, callback) {

        let config = Config[network];
        this.web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http','ws')));
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
        this.flightSuretyData = new this.web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);
        this.initialize(callback);
        this.owner = null;
        this.airlines = [];
        this.passengers = [];
    }

    initialize(callback) {
        this.web3.eth.getAccounts((error, accts) => {
           
            this.owner = accts[0];

            let counter = 1;
            
            while(this.airlines.length < 5) {
                this.airlines.push(accts[counter++]);
            }

            while(this.passengers.length < 5) {
                this.passengers.push(accts[counter++]);
            }


            callback();
        });
    }

    isOperational(callback) {
       let self = this;
       self.flightSuretyApp.methods
            .isOperational()
            .call({ from: self.owner}, callback);
    }

    fetchFlightStatus(flight, callback) {
        let self = this;
        self.flightSuretyApp.methods
            .fetchFlightStatus(flight.airline, flight.flight, flight.timestamp)
            .send({ from: self.owner}, (error) => {
                callback(error, flight);
            });
    }

    buyInsurance(flight, amount, callback) {
        let self = this;
        let amountInt = parseInt(amount);
        self.flightSuretyData.methods.buy(flight)
            .send({from:self.owner, value:amountInt, gasLimit: "4600000"})
            .then((res) => {
                callback(null, "Insurance bought")
            })
            .catch((err) => {
                console.log(err)
                callback(err, "");
            });
    }

    withdraw(callback) {
        let self = this;
        self.flightSuretyData.methods.checkInsurance('ABC123').call({from:self.owner})
        .then((res) => {
            console.log(res);
        })
        self.flightSuretyData.methods.checkPayouts().call({from:self.owner})
        .then((res) => {
            console.log(res);
        })
        self.flightSuretyData.methods.pay()
            .send({from:self.owner, gasLimit: "4600000"})
            .then((res) => {
                callback(null, "Withdraw success")
            })
            .catch((err) => {
                console.log(err)
                callback(err, null);
            });
    }

}
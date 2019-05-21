
import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';
import axios from 'axios';

let allFlights = [];

// search for flight inside the array
function searchFlight(flights, flightNumber) {
    for(var i = 0; i < flights.length; i++) {
      if(flights[i].flight == flightNumber) {
        return flights[i]
      }
    }
    return null;
}

(async() => {

    let result = null;

    // fill flights
    populateSelectFlight();

    let contract = new Contract('localhost', () => {

        // Read transaction
        contract.isOperational((error, result) => {
            console.log(error,result);
            display('Operational Status', 'Check if contract is operational', [ { label: 'Operational Status', error: error, value: result} ]);
        });
    
        // User-submitted transaction

        // fetch flight status
        DOM.elid('submit-oracle').addEventListener('click', () => {
            let flightNumber = DOM.elid('flight-number').value;
            let flight = searchFlight(allFlights, flightNumber);
            // Write transaction
            contract.fetchFlightStatus(flight, (error, result) => {
                display('Oracles', 'Trigger oracles', [ { label: 'Fetch Flight Status', error: error, value: result.flight + ' ' + result.timestamp} ]);
            });
        })

        // Buy insurance
        DOM.elid('buy-btn').addEventListener('click', () => {
            let flight = DOM.elid('buy-flight-number').value;
            let amount = DOM.elid('buy-amount').value;
            contract.buyInsurance(flight, amount, (err, result) => {
                display('FlightSuretyApp', 'Buy Insurance', [ { label: 'Buy Insurance', error: err, value: result} ]);
            });
        })

        // Withdraw
        DOM.elid('withdraw-btn').addEventListener('click', () => {
            contract.withdraw((err, result) => {
                if (err) {
                    display('FlightSuretyApp', 'Withdraw Payment', [ { label: 'Withdraw', error: err, value: result} ]);
                } else {
                    display('FlightSuretyApp', 'Withdraw Payment', [ { label: 'Withdraw', error: err, value: result} ]);
                }
            })
        })

        
        // subscribe to event
        contract.web3.eth.getBlockNumber().then((blockNumber) => {
            contract.flightSuretyApp.events.FlightStatusInfo({
                fromBlock: blockNumber
              }, function (error, event) {
                if (error) console.log(error)
                let status = event['returnValues']['status'];
                if (status === "20") {
                    status = "Status 20. Flight is late. Insurance will be paid out"
                } else {
                    status = "Status " + event['returnValues']['status'].toString() + ". Insurance will not be paid out";
                }
                let flightInfo = event['returnValues']['flight'] + " " + status;
                display('FlightSuretyApp', 'Flight Info Received', [ { label: 'Flight Status', error: error, value: flightInfo} ]);
              });
            
        })
        
    });
    

})();

async function fetchFlight() {
    let config = {
        headers: {
          "Access-Control-Allow-Origin": "*"
        }
      };
    let result = await axios.get('http://localhost:3000/flights', config);
    return result;
}

async function populateSelectFlight() {
    let flightStatusSelect = document.getElementById('flight-number');
    let flightSelect = document.getElementById('buy-flight-number');
    let flightsReq = await fetchFlight();
    let flights = flightsReq.data.flights;
    // store in global array
    allFlights = allFlights.concat(flights);
    for(var i = 0; i < flights.length; i++) {
        var option1 = document.createElement("option");
        option1.text = flights[i]['flight'] + " status " + flights[i]['flightStatus'];
        option1.value = flights[i]['flight'];

        var option2 = document.createElement("option");
        option2.text = flights[i]['flight'];
        option2.value = flights[i]['flight'];

        flightStatusSelect.appendChild(option1);
        flightSelect.appendChild(option2);
    }

}

function display(title, description, results) {
    let displayDiv = DOM.elid("display-wrapper");
    let section = DOM.section();
    section.appendChild(DOM.h2(title));
    section.appendChild(DOM.h5(description));
    results.map((result) => {
        let row = section.appendChild(DOM.div({className:'row'}));
        row.appendChild(DOM.div({className: 'col-sm-4 field'}, result.label));
        row.appendChild(DOM.div({className: 'col-sm-8 field-value'}, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    })
    displayDiv.append(section);

}








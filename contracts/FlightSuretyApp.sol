pragma solidity ^0.5.2;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    FlightSuretyData dataContract;

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    // Constants
    uint8 private constant MIN_AIRLINE_TO_ACTIVATE_CONSENSUS = 4;
    // ante required for airline to be active
    uint256 private constant ANTE_AMOUNT = 10 ether;
    // maximum amount of insurance that passenger can buy
    uint256 private constant MAX_INSURANCE = 1 ether;
    // the payout ratio given if airline is late (note that this will be divided by 10)
    uint16 private constant PAYOUT_RATIO = 15;

    address private contractOwner;          // Account used to deploy contract


    // store the number of calls from other airlines
    struct AirlineConsensus {
        bool isApproved;
        address[] calls;
    }

    bool private operational = true; // Blocks all state changes throughout the contract if false
    mapping(address => AirlineConsensus) private registerConsensus; // Store the consensus info
    uint private numberOfRequiredConsensus; // Store the number of required consensus, which get updated everytime an airline is registered
    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
         // Modify to call data contract's status
        require(true, "Contract is currently not operational");  
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }


    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor(address _dataAddress) public {
        contractOwner = msg.sender;
        dataContract = FlightSuretyData(_dataAddress);
        // !important, on first deploy we need to make sure this number get updated
        // always include this during contract update to prevent bugs in multi party consensus
        updateNumberOfRequiredConsensus();
    }

    /******************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() public view returns(bool) {
        return operational;  // Modify to call data contract's status
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    
    function buyInsurance(string memory _flight) public payable requireIsOperational {
        require (msg.value > 0, "Amount must be greater than zero");
        require (msg.value <= MAX_INSURANCE, "Amount must not exceed 1 ether");
        (bool active, bool unused, address unused2, uint256 unused3) = dataContract.getFlight(_flight);
        require (active == true, "Flight is not currently active");
        uint256 insuranceBought = dataContract.checkInsurance(_flight, msg.sender);
        require (insuranceBought == 0, "You have bought an insurance for this flight");
        dataContract.buy.value(msg.value)(_flight, msg.sender);
    } 
  
   /**
    * @dev Add an airline to the registration queue
    * For the first 4 airlines, it will be automatically registered
    * For the subsequent airline, it will need a 50% consensus
    */
    function registerAirline(address _airlineAddress, string calldata _airlineName) external 
    requireIsOperational returns(bool _success, uint256 _votes)
    {
        require(dataContract.isAirlineActive(msg.sender) == true,
         "You are not yet activated");

        uint airlineStatus = dataContract.getAirlineStatus(_airlineAddress);
        if (airlineStatus != 0) {
            // register airline with WaitingConsensus status
            dataContract.registerAirline(_airlineAddress, _airlineName);
        }
        uint numberOfRegisteredAirline = dataContract.getNumberOfRegisteredAirline();
        // if minimum hasnt been achieved, update status to registered immediately
        if (numberOfRegisteredAirline < MIN_AIRLINE_TO_ACTIVATE_CONSENSUS) {
            dataContract.updateAirlineStatusToRegistered(_airlineAddress);
            // below function is important to ensure the number is updated after registration!
            updateNumberOfRequiredConsensus();
            return (true, numberOfRegisteredAirline);
        }

        // check whether this airline is already listed before
        require(registerConsensus[_airlineAddress].isApproved == false, "This airline is already approved");
        // prevent same user calling twice
        bool isDuplicate = false;
        for(uint c = 0; c < registerConsensus[_airlineAddress].calls.length; c++) {
            if (registerConsensus[_airlineAddress].calls[c] == msg.sender) {
                isDuplicate = true;
                break;
            }
        }
        require(!isDuplicate, "Caller has already called this function.");

        registerConsensus[_airlineAddress].calls.push(msg.sender);
        if (registerConsensus[_airlineAddress].calls.length >= numberOfRequiredConsensus) {
            registerConsensus[_airlineAddress].isApproved = true;
            dataContract.updateAirlineStatusToRegistered(_airlineAddress);
            // below function is important to ensure the number is updated after registration!
            updateNumberOfRequiredConsensus();
            return (true, registerConsensus[_airlineAddress].calls.length);
        }
        return (true, registerConsensus[_airlineAddress].calls.length);
    }

    /**
    * @dev Update the number of required consensus. This function should be called after a registration.
    */
    function updateNumberOfRequiredConsensus() private {
        // number of required consensus is set to 50% of the number of registered airline
        uint numberOfRegisteredAirline = dataContract.getNumberOfRegisteredAirline();

        uint quotient = numberOfRegisteredAirline.div(2);
        uint remainder = numberOfRegisteredAirline - quotient.mul(2);
        // if there is a remainder we should round up to get above 50%
        if (remainder > 0) {
            numberOfRequiredConsensus = quotient + 1;
        } else {
            numberOfRequiredConsensus = quotient;
        }
    }

    /**
    * @dev Pay ante to activate airline, note that the fund will be send to data contract
    * data contract require an already registered airline to pay ante
    */
    function payAnte() public payable requireIsOperational {
        require(msg.value == ANTE_AMOUNT, "Ante paid must be equal to 10 ether");
        dataContract.payAnte.value(ANTE_AMOUNT)(msg.sender);
    }

   /**
    * @dev Register a future flight for insuring.
    *
    */
    function registerFlight(string calldata _flightNumber, uint256 _timestamp) external
    requireIsOperational {
        // check if the caller is one of the registered airline
        bool isCallerRegistered = dataContract.isAirlineActive(msg.sender);
        require (isCallerRegistered == true, "You are not active");

        dataContract.registerFlight(_flightNumber, msg.sender, _timestamp);
    }
    
   /**
    * @dev Called after oracle has updated flight status, credit insurees if flight is late airline
    *
    */  
    function processFlightStatus (address airline, string memory flight,
                                    uint256 timestamp, uint8 statusCode) internal {
        if (statusCode == STATUS_CODE_LATE_AIRLINE) {
            // note that PAYOUT_RATIO will be divided by 10
            dataContract.creditInsurees(flight, PAYOUT_RATIO);
        }
    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus(address airline, string calldata flight,uint256 timestamp) external
    requireIsOperational {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true,
                                                isValid: true
                                            });

        emit OracleRequest(index, airline, flight, timestamp);
    } 


// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        bool isValid;                                   // to identify whether key is valid
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle() external payable requireIsOperational
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    function getMyIndexes() external view returns(uint8[3] memory)
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse(
                            uint8 index,
                            address airline,
                            string calldata flight,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external requireIsOperational
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isValid, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            if (oracleResponses[key].isOpen) {
                emit FlightStatusInfo(airline, flight, timestamp, statusCode);
                // Handle flight status as appropriate
                processFlightStatus(airline, flight, timestamp, statusCode);
            }
            // mark the flight request as closed when number of responses are met
            oracleResponses[key].isOpen = false;

            
        }
    }


    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (                       
                                address account         
                            )
                            internal
                            returns(uint8[3] memory)
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}

contract FlightSuretyData {
    function isAirlineRegistered(address _airlineAddress) public view returns(bool) {}
    function isAirlineActive(address _airlineAddress) public view returns(bool) {}
    function getNumberOfRegisteredAirline() public view returns(uint) {}
    function registerAirline(address _airlineAddress, string calldata _airlineName) external {}
    function updateAirlineStatusToRegistered(address _airlineAddress) external {}
    function getAirlineStatus(address _airlineAddress) external view returns (uint _status) {}
    function registerFlight(string calldata _flightNumber, address _airline, uint256 _timestamp) external {}
    function creditInsurees(string calldata _flightNumber, uint16 payoutRatio) external {}
    function buy(string calldata _flightNumber, address _buyerAddress) external payable {}
    function payAnte(address _airlineAddress) external payable {}
    function fund() external payable {}
    function getFlight(string memory _flightNumber) public view returns(bool _active,
         bool _isRegistered, address _airline, uint256 _timestamp) {}
    function checkInsurance(string memory _flightNumber, address _passengerAddress) public view returns(uint256 _amount) {}
}

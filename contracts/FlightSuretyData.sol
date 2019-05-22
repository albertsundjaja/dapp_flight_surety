pragma solidity ^0.5.2;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/
    enum AirlineStatus {Unregistered, WaitingConsensus, Registered, Active} // Airline status
    struct AirlineInfo {
        string name;
        AirlineStatus status;
        address referrer;
    }

    struct PassengerInfo {
        string name;
        mapping(string => uint) insuranceBought; // Store insurance bought by this passenger
    }

    struct Flight {
        bool isRegistered;
        uint8 statusCode; // status code is defined in App Contract in case we want to modify it
        uint256 updatedTimestamp;
        address airline;
        bool active;
        address[] addressList;
    }

    address private contractOwner; // Account used to deploy contract
    mapping(address => bool) private allowedContracts; // Store allowed contract to call this contract
    bool private operational = true; // Blocks all state changes throughout the contract if false
    mapping(address => AirlineInfo) private airlines; // Store airlines whether they are registered/have paid the fee
    uint numberOfRegisteredAirline = 1; // Store how many airlines are currently registered, first airline registerd during deployment
    mapping(string => Flight) private flights; // Store passenger's wallet for the given flight insurance
    mapping(address => PassengerInfo) private passengers; // Store detail of passenger who bought insurance
    mapping(address => uint) private payouts; // Payouts amount for passenger
    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Event that tells that a new airline is added to the mapping
    */
    event NewAirlineAdded(string _airlineName);

    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
            First airline will be registered
    */
    constructor(address _firstAirlineAddress, string memory _firstAirlineName) public {
        contractOwner = msg.sender;

        // register first airline when contract deployed
        AirlineInfo memory info;
        info.name = _firstAirlineName;
        info.status = AirlineStatus.Registered;
        airlines[_firstAirlineAddress] = info;
    }

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
        require(operational, "Contract is currently not operational");
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

    /**
    * @dev Modifier that requires the origin to be a registered airline
    */
    modifier requireRegisteredContract {
        require(allowedContracts[msg.sender] == true, "Need a registered contract");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
                            requireContractOwner 
    {
        operational = mode;
    }

    /**
    * @dev Add allowed contracts to call this contract
    */
    function registerContract(address _address) external requireContractOwner {
        allowedContracts[_address] = true;
    }

    /**
    * @dev Deregister allowed contracts to call this contract
    */
    function deRegisterContract(address _address) external requireContractOwner {
        allowedContracts[_address] = false;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    function getNumberOfRegisteredAirline() public view returns(uint) {
        return numberOfRegisteredAirline;
    }
   /**
    * @dev Add an airline to the registration queue with WaitingConsensus status
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline(address _airlineAddress, string calldata _airlineName) external requireRegisteredContract 
    requireIsOperational {
        AirlineInfo memory info;
        info.name = _airlineName;
        info.status = AirlineStatus.WaitingConsensus;
        airlines[_airlineAddress] = info;
        emit NewAirlineAdded(_airlineName);
    }

    /**
    * @dev Update status of an airline to the registered status
    *      Can only be called from FlightSuretyApp contract
    *
    */
    function updateAirlineStatusToRegistered(address _airlineAddress) external requireRegisteredContract 
    requireIsOperational {
        airlines[_airlineAddress].status = AirlineStatus.Registered;
        numberOfRegisteredAirline += 1;
    }

    /**
    * @dev Airline has paid ante, activate
    */
    function payAnte(address _airlineAddress) external payable requireRegisteredContract 
    requireIsOperational {
        require(airlines[_airlineAddress].status == AirlineStatus.Registered, "Airline is not yet registered");
        // change status of the airline to active
        airlines[_airlineAddress].status = AirlineStatus.Active;
    }

    /**
    * @dev get the status of an airline address
    * 
    */
    function getAirlineStatus(address _airlineAddress) external view returns (uint _status) {
        _status = uint(airlines[_airlineAddress].status);
    }

    /**
    * @dev check if airline address is listed
    * AirlineStatus.WaitingConsensus or AirlineStatus.Registered or AirlineStatus.Active
    */
    function isAirlineListed(address _airlineAddress) external view returns (bool) {
        if (airlines[_airlineAddress].status != AirlineStatus.Unregistered) {
            return true;
        } else {
            return false;
        }
    }

    /**
    * @dev check if airline address is registered
    * AirlineStatus.Registered
    */
    function isAirlineRegistered(address _airlineAddress) external view returns (bool) {
        if (airlines[_airlineAddress].status == AirlineStatus.Registered) {
            return true;
        } else {
            return false;
        }
    }

     /**
    * @dev check if airline address is active
    * AirlineStatus.Active
    */
    function isAirlineActive(address _airlineAddress) external view returns (bool) {
        if (airlines[_airlineAddress].status == AirlineStatus.Active) {
            return true;
        } else {
            return false;
        }
    }

    /**
    * @dev register a flight and list of insurances available for buying
    *
    */
    function registerFlight(string calldata _flightNumber,
                            address _airline, uint256 _timestamp) external requireRegisteredContract 
                            requireIsOperational {

        require(flights[_flightNumber].isRegistered == false, "Flight is already registered");

        flights[_flightNumber].active = true;
        flights[_flightNumber].isRegistered = true;
        flights[_flightNumber].airline = _airline;
        flights[_flightNumber].updatedTimestamp = _timestamp;
    }

    /**
    * @dev get flight info
    *
    */
    function getFlight(string memory _flightNumber) public view returns(bool _active,
         bool _isRegistered, address _airline, uint256 _timestamp) {

        _active = flights[_flightNumber].active;
        _isRegistered = flights[_flightNumber].isRegistered;
        _airline = flights[_flightNumber].airline;
        _timestamp = flights[_flightNumber].updatedTimestamp;
    }

   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy(string calldata _flightNumber, address _buyerAddress) external payable requireIsOperational {
        require (flights[_flightNumber].active == true, "Flight is not currently active");
        require (msg.value > 0, "Amount must be greater than zero");
        require (passengers[_buyerAddress].insuranceBought[_flightNumber] == 0, "You have bought an insurance for this flight");

        // add into flight number list of passenger who bought insurance
        flights[_flightNumber].addressList.push(_buyerAddress);
        // update this passenger insurance bought
        passengers[_buyerAddress].insuranceBought[_flightNumber] = msg.value;
    }

     /**
    * @dev Check insurance detail
    *
    */   
    function checkInsurance(string memory _flightNumber, address _passengerAddress) public view returns(uint256 _amount) {
        return passengers[_passengerAddress].insuranceBought[_flightNumber];
    }

    /**
    * @dev Check payouts
    *
    */   
    function checkPayouts() public view returns(uint256 _amount) {
        return payouts[msg.sender];
    }

    /**
     *  @dev Credits payouts to insuree
     * WARNING there is a for loop in this function
    */
    function creditInsurees(string calldata _flightNumber, uint16 _payoutRatio) external requireRegisteredContract 
    requireIsOperational {
        address[] memory addresses = flights[_flightNumber].addressList;
        flights[_flightNumber].active = false;

        for (uint i = 0; i < addresses.length; i++) {
            uint insuranceAmount = passengers[addresses[i]].insuranceBought[_flightNumber];
            // empty out the insurance for this passenger
            passengers[addresses[i]].insuranceBought[_flightNumber] = 0;
            payouts[addresses[i]] += insuranceAmount.mul(_payoutRatio).div(10);
        }
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay() external requireIsOperational {
        require(payouts[msg.sender] > 0, "Balance is zero");
        uint amount = payouts[msg.sender];
        payouts[msg.sender] = 0;
        msg.sender.transfer(amount);
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund() public payable
    {
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

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() 
                            external 
                            payable 
    {
        fund();
    }


}


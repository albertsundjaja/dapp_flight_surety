
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.registerContract(config.flightSuretyApp.address);

    // first airline should pay ante to activate
    //await config.flightSuretyApp.registerAirline(config.firstAirline, "First Airline", {from:config.owner});
    await config.flightSuretyData.payAnte({from:config.firstAirline,value:10 * config.weiMultiple});
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
            
  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false);
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
      
  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

      await config.flightSuretyData.setOperatingStatus(false);

      let reverted = false;
      try 
      {
          await config.flightSurety.setTestingMode(true);
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, true, "Access not blocked for requireIsOperational");      

      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);

  });

  it("can't register airline when sender is not an active airline", async () => {
    let caller = accounts[3];
    let newAirline = accounts[2];
    let err = null;
    try {
        await config.flightSuretyApp.registerAirline(newAirline, "Test Airline", {from:caller});
    }
    catch(e) {
        err = e;
    }
    assert.notEqual(err, null, "Contract should throw an error if inactive caller try to register an airline");
    let result = await config.flightSuretyData.isAirlineRegistered.call(newAirline);
    assert.equal(result, false, "Inactive caller should not be able to register airline");
  });

  it('can register airline when sender is an active airline and number of registered airline <4', async () => {
    let newAirline = accounts[2];
    await config.flightSuretyApp.registerAirline(newAirline, "Test Airline", {from:config.firstAirline});
    let result = await config.flightSuretyData.isAirlineRegistered.call(newAirline);
    assert.equal(result, true, "Owner cannot register airline");
  });

  it("cant pay Ante if it is not 10 ether", async () => {
    let caller = accounts[2];

    let err = null;
    try {
        await config.flightSuretyData.payAnte({from:caller, value:1});
    }
    catch (e) {
        //console.log(e);
        err = e;
    }
    assert.notEqual(err, null, "Paying ante less than 10 ether should give error");

    err = null;
    try {
        await config.flightSuretyData.payAnte({from:caller, value:20* config.weiMultiple});
    }
    catch (e) {
        //console.log(e);
        err = e;
    }
    assert.notEqual(err, null, "Paying ante more than 10 ether should give error");
  });

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
    
    // ARRANGE
    let notPaidAirline = accounts[2];
    let newAirline = accounts[3];

    // ACT
    try {
        await config.flightSuretyApp.registerAirline(newAirline, "Test Airline 2", {from: config.notPaidAirline});
    }
    catch(e) {

    }
    let result = await config.flightSuretyData.isAirlineListed.call(newAirline); 

    // ASSERT
    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

  });

  it('require multiparty consensus when number of registered airline is >= 4', async () => {

    // pay the second airline for ante
    await config.flightSuretyData.payAnte({from:accounts[2],value:10 * config.weiMultiple});
    
    let newAirline3 = accounts[3];
    let newAirline4 = accounts[4];
    
    // register and pay for third and fourth airline
    await config.flightSuretyApp.registerAirline(newAirline3, "Test Airline 3", {from: config.firstAirline});
    await config.flightSuretyApp.registerAirline(newAirline4, "Test Airline 4", {from: config.firstAirline});
    await config.flightSuretyData.payAnte({from:newAirline3,value:10 * config.weiMultiple});
    await config.flightSuretyData.payAnte({from:newAirline4,value:10 * config.weiMultiple});
    
    let newAirline5 = accounts[5];
    await config.flightSuretyApp.registerAirline(newAirline5, "Test Airline 5", {from: config.firstAirline});
    let result = await config.flightSuretyData.isAirlineRegistered(newAirline5);

    assert.equal(result, false, "Airline registration should require multiparty consensus");
    
  });

  it('requires a 50% consensus (2 votes) to register the 5th airline', async () => {
    // register 2nd vote
    let newAirline5 = accounts[5];
    await config.flightSuretyApp.registerAirline(newAirline5, "Test Airline 5", {from: accounts[2]});
    let result = await config.flightSuretyData.isAirlineRegistered(newAirline5);
    assert.equal(result, true, "With 50% consensus, airline should be registered");
  });

  it('requires a 50% consensus (3 votes) to register the 6th airline', async () => {
    let newAirline6 = accounts[6];
    await config.flightSuretyApp.registerAirline(newAirline6, "Test Airline 6", {from: config.firstAirline});
    let result = await config.flightSuretyData.isAirlineRegistered(newAirline6);
    assert.equal(result, false, "Registration of 6th airline should require 3 votes, only 1 vote submitted");

    // 2nd vote
    await config.flightSuretyApp.registerAirline(newAirline6, "Test Airline 6", {from: accounts[2]});
    result = await config.flightSuretyData.isAirlineRegistered(newAirline6);
    assert.equal(result, false, "Registration of 6th airline should require 3 votes, only 2 votes submitted");

    // 3rd vote
    await config.flightSuretyApp.registerAirline(newAirline6, "Test Airline 6", {from: accounts[3]});
    result = await config.flightSuretyData.isAirlineRegistered(newAirline6);
    assert.equal(result, true, "With 3 votes, the airline should pass the registration process");
  });

  it('can register a flight', async () => {
    const flightNumber = "Test123";
    await config.flightSuretyApp.registerFlight(flightNumber, (new Date).getTime(), {from:config.firstAirline});
    let result = await config.flightSuretyData.getFlight(flightNumber);
    assert(result['_active'], true, "Flight should be registered");
  });
  
  it('allows passenger to buy insurance', async () => {
    let passenger = accounts[6];
    const flightNumber = "Test123";
    await config.flightSuretyData.buy(flightNumber, {from:passenger, value:1000});
    let result = await config.flightSuretyData.checkInsurance(flightNumber, {from:passenger});
    assert(result, 1000, "Insurance bought must be equal to 1000 in value");
  });

  /* for testing this, we need to change processFlightStatus in data contract to public */
  /*
  it('credit insurees when flight is late - airline', async () => {
    let passenger = accounts[6];
    const flightNumber = "Test123";
    let amountPassengerBought = await config.flightSuretyData.checkInsurance(flightNumber, {from:passenger});
    assert(amountPassengerBought, 1000, "Insurance bought should be equal to 1000 in value");
    await config.flightSuretyApp.processFlightStatus(config.firstAirline, flightNumber, 1000, 20);
    let payouts = await config.flightSuretyData.checkPayouts({from:passenger});
    assert(payouts, 1500, "Payouts should be 1500");
  });
  */
  
});

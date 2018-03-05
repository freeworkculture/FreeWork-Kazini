pragma solidity ^0.4.19;
import "./ControlAbstract.sol";
import "./Oraclize.sol";
pragma experimental ABIEncoderV2;

//////////////////////
// BaseController
//////////////////////
/// @dev `BaseController` is a base level contract that assigns an `controller` that can be
///  later changed
contract BaseController is UserDefined {

/* Constants */

    bytes32 constant public VERSION = "BaseController 0.2.3";

/* State Variables */

    Able public contrl;
	address public owner;
	address public controller;
	bool mutex;
	bytes32 public cName;
	uint8 V;
	bytes32 R;
	bytes32 S;

/* Events */

    event Log(string message);
    event ChangedOwner(address indexed oldOwner, address indexed newOwner);
	event ChangedContrl(address indexed oldContrl, address indexed newContrl);
	event ChangedController(address indexed oldController, address indexed newController);
    event ContractEvent(address indexed _this, address indexed _sender, address indexed _origin);
	event ContractCallEvent(address indexed _this, address indexed _sender, address indexed _origin, bytes32 _data);
	event PlanEvent(address indexed _from, address indexed _to, uint256 _amount);
    event PromiseEvent(address indexed _from, address indexed _to, uint256 _amount);
    event Fulfill(address indexed _from, address indexed _to, uint256 _amount);
	event LogNewOraclizeQuery(string description);
    event LogNewResult(string result, bytes proof);

/* Modifiers */

	/// @dev `Able` is the controller.
	/// @notice The address of the controller is the only address that can call
    ///  a function with this modifier
    modifier onlyController { 
        require(msg.sender == controller); 
        _; 
	}

	/// @notice The address of the controller is the only address that can call
    ///  a function with this modifier
    modifier onlyControlled { 
        require(contrl.contracts(msg.sender) != 0x0); 
        _; 
	}

    /// @dev `owner` is the only address that can call a function with this
    /// modifier
    modifier onlyOwner {
        require (msg.sender == owner); 
        _;
    }

    // This modifier can be used on functions with external calls to
    // prevent reentry attacks.
    // Constraints:
    //   Protected functions must have only one point of exit.
    //   Protected functions cannot use the `return` keyword
    //   Protected functions return values must be through return parameters.
    modifier preventReentry() {
        if (mutex) 
		revert();
        else 
		mutex = true;
        _;
        delete mutex;
        return;
    }

    // This modifier can be applied to pulic access state mutation functions
    // to protect against reentry if a `mutextProtect` function is already
    // on the call stack.
    modifier noReentry() {
        require(!mutex);
        _;
    }

    // Same as noReentry() but intended to be overloaded
    modifier canEnter() {
        require(!mutex);
        _;
    }
    
/* Functions */ 

    /// @notice The Constructor assigns the message sender to be `owner`
    function BaseController() internal {
        owner = tx.origin;
    }

    function getContrl() view public returns (Able) {
        return contrl;
    }

	function isAble() view public returns (bytes32) {
		contrl.KEYID;
	}

    // Change the owner of a contract
    /// @notice `setOwner` can step down and assign some other address to this role
    /// @param _newOwner The address of the new owner. 0x0 can be used to create
    ///  an unowned neutral vault, however that cannot be undone
    function setOwner(address _newOwner) internal onlyOwner returns (bool) {
		assert(owner != _newOwner);
        owner = _newOwner;
        ChangedOwner(msg.sender, owner);
        return true;
    }

    /// @notice `setContrl` can step down and assign some other address to this role
    /// @param _newCtrl The address of the new owner. 0x0 can be used to create
    ///  an unowned neutral vault, however that cannot be undone
    function setContrl(Able _newCtrl) internal onlyOwner returns (bool) {
		assert(contrl != _newCtrl);
        contrl = _newCtrl;
		ChangedContrl(msg.sender, owner);
        return true;
    }

    /// @notice `setController` can step down and assign some other address to this role
    ///  The address of the new controller is the address of the contrl. 
	///  0x0 can be used to create an unowned neutral vault, however that cannot be undone
    function setController(uint8 _v, bytes32 _r, bytes32 _s) internal onlyOwner returns (bool) {
		V = _v;
		R = _r;
		S = _s;
    }

    /// @notice `setController` can step down and assign some other address to this role
    ///  The address of the new controller is the address of the contrl. 
	///  0x0 can be used to create an unowned neutral vault, however that cannot be undone
    function setController() internal onlyOwner returns (bool) {
		assert(controller != address(contrl));
        controller = address(contrl);
		ChangedController(msg.sender, owner);
    }

  	function verify(bytes32 _message, uint8 _v, bytes32 _r, bytes32 _s) view public returns (address) {
		bytes memory prefix = "\x19Ethereum Signed Message:\n32";
		bytes32 prefixedHash = keccak256(prefix, _message);
		return ecrecover(prefixedHash, _v, _r, _s);
	}

	function verified(bytes32 _message, uint8 _v, bytes32 _r, bytes32 _s) view external returns (bool success) {
		verify(_message,_v,_r,_s) == msg.sender ? success = true : success = false;
	}

/* End of BaseController */
}


///////////////////
// Token Controller
///////////////////

/// @dev The token controller contract must implement these functions
contract TokenController {
    /// @notice Called when `_owner` sends ether to the Doit Token contract
    /// @param _owner The address that sent the ether to create tokens
    /// @return True if the ether is accepted, false if it throws
    function proxyPayment(address _owner) public payable returns(bool);

    /// @notice Notifies the controller about a token transfer allowing the
    ///  controller to react if desired
    /// @param _from The origin of the transfer
    /// @param _to The destination of the transfer
    /// @param _amount The amount of the transfer
    /// @return False if the controller does not authorize the transfer
    function onTransfer(address _from, address _to, uint _amount) public returns(bool);

    /// @notice Notifies the controller about an approval allowing the
    ///  controller to react if desired
    /// @param _owner The address that calls `approve()`
    /// @param _spender The spender in the `approve()` call
    /// @param _amount The amount in the `approve()` call
    /// @return False if the controller does not authorize the approval
    function onApprove(address _owner, address _spender, uint _amount) public
        returns(bool);
}

//////////////////
// Data Controller
//////////////////
/// @dev `Data` is a base level contract that is a `database controller` that can be
///  later changed
contract DataController is BaseController {

/* State Variables */
    
    Database internal database;
    
    Userbase internal userbase;

/* Modifiers */

	modifier onlyCreator {
		require(userbase.isCreator());
		_;
	}

	modifier onlyDoer {
		require (userbase.isDoer()); 
		_;
	}
    
/* Functions */ 

	/// @notice `anybody` can Get the address of an existing contract frrom the controller.
    function getDatabase() view public returns (Database) {
        return database;   
    }
}
/* End of Data */

////////////////
// Able Contract
////////////////
contract Able is DataController {

/* Constants */
// !!! ******** FOR TEST ONLY CHANGE TO ACTUAL 40 BYTES FPRINT ***********
	bytes32 constant public KEYID = 0x9BCB2540EBAC30FC9E9EFF3D259B64A2;
	bytes32 constant internal CONTRACTNAME = "Able";

/* State Variables */

    // This is where we keep all the contracts.
    mapping (address => bytes32) public contracts;

/* Events */
/* Modifiers */
/* Functions */ 

    function Able() public { 
        contrl = Able(this);
        controller = this;
        cName = CONTRACTNAME;
        contracts[this] = cName;
		//	database = Database(makeContract("database"));
		//  userbase = Userbase(makeContract("userbase"));
		// 	ContractEvent(this,msg.sender,tx.origin);
	}

	///////////////////
	// Controller Logic

	// Change the owner of a contract
	/// @notice `owner` can step down and assign some other address to this role
	/// @param _newOwner _sig The address of the new owner. 0x0 can be used to create
	///  an unowned neutral vault, however that cannot be undone
	function changeOwner(address _newOwner, bytes32 _sig) public onlyOwner returns (bool) {
		require(_sig == 0x0);
		// require(verify(_sig,_v,_r,_s) == controller);
		setOwner(_newOwner);
	}

	/// @notice `contrl` can step down and assign some other address to this role
	/// @param _newCtrl _sig The address of the new owner. 0x0 can be used to create
	///  an unowned neutral vault, however that cannot be undone
	function changeContrl(Able _newCtrl, bytes32 _sig) public onlyOwner returns (bool) {
		require(_sig == 0x0);
		// require(verify(_sig,_v,_r,_s) == controller);
		setContrl(_newCtrl);
		// _e.delegatecall(bytes4(sha3("setN(uint256)")), _n); // D's storage is set, E is not modified
		// contrl.delegatecall(bytes4(sha3("setContrl(address)")),_newCtrl);
		
	}

	/// @notice `controller` can step down and assign some other address to this role
	/// @param _sig The address of the new controller is the address of the contrl. 
	///  0x0 can be used to create an unowned neutral vault, however that cannot be undone
	function changeController(bytes32 _sig) public onlyOwner returns (bool) {
		require(_sig == 0x0);
		// require(verify(_sig,_v,_r,_s) == controller);
		setController();
	}
	///////////////////


    /// @notice Get the address of an existing contract frrom the controller.
    /// @param _address The new controller of the contract
	//  @dev `Controller` can retrive a registered contract
    function getContract(address _address) view external onlyOwner returns (bytes32) {
        return contracts[_address];
    }

    /// @notice Add a new contract to the controller. This will not overwrite an existing contract.
    /// @param _address _name The address of the new owner. 0x0 can be used to create
	//  @dev `Controller` can register a contract and assign to it some role
    function registerContract(
		address _address, 
		bytes32 _name,
		bytes32 _sig) external onlyOwner returns (bool)	 // This guard exhibits buglike behaviour, 
		{													// Only do validation if there is an actions contract. stops contract from overwriting itself.
			require(_sig == 0x0);
			// require(verify(_sig,_v,_r,_s) == controller);
			require(contracts[_address] == 0x0);
			contracts[_address] = _name;
			ContractCallEvent(this,msg.sender,tx.origin,_name);
			return true;
	}

    // Remove a contract from the controller. We could also selfdestruct if we want to.
    function removeContract(address _address, bytes32 _sig) onlyOwner external returns (bool result) {
		require(_sig == 0x0);
		// require(verify(_sig,_v,_r,_s) == controller);
        require(contracts[_address] != 0x0);
        // Kill any contracts we remove, for now.
		bytes32 reset;
		contracts[_address] = reset;
		ContractCallEvent(this,msg.sender,tx.origin,CONTRACTNAME);
		return true;
    }
                
    // // Make a new contract.
    // function makeContract(bytes32 _base, bytes32 _sig) public returns (address contract_) {
	// 	require(_sig == 0x0);
	// 	// require(verify(_sig,_v,_r,_s) == controller);
    //     if (_base == "database") {
    //         contract_ = new Database(contrl);
    //         contracts[contract_] = Database(contract_).cName();
    //     } else if (_base == "userbase") {
    //         contract_ = new Userbase(contrl);
    //         contracts[contract_] = Userbase(contract_).cName();
    //     } else if (_base == "creator") {
    //         contract_ = new Creators(this,userbase,_base);
    //         contracts[contract_] = Creators(contract_).cName();
    //     }
    // }
        
                
    // // Make a new creators contract.
    // function makeCreators(bytes32 _name) onlyController public returns (Creators create) {
    //     create = new Creators(this,userbase,_name);
    //     contracts[create] = create.cName();
    // }
/* End of Able */
}


////////////////////
// Database Contract
////////////////////
contract Database is BaseController {
    
/* Constants */

    bytes32 constant internal CONTRACTNAME = "Database";
	uint8 constant internal BASE = 2;

/* Enums*/


/* Structs*/


/* State Variables */
    
	uint public GEN = 1000;
	uint public plansCount;
	uint public promiseCount;
    uint public orderCount;
    uint public fulfillmentCount;
	uint public verificationCount;
	Userbase userbase;

	/// @dev `Initialised data structures
	/// @notice `Creator && Doer lookup` is the type that defines a strategy model of an actual agent
	// @dev Interp. myBelief {Qualification, Experience, Reputation, Talent} is an agent with
	// Qualification is (<ISO 3166-1 numeric-3>,<Conferring Authority>,<Score>)
	// experience is period from qualification in seconds
	// reputaion is PGP trust level flag !!! CITE RFC PART
	// talent is user declared string of talents

    mapping(bytes32 => Plans) public plans;

	mapping(bytes32 => address[]) public allPromises;

    bytes32[] public allPlans;

/* Events */

	event NewPlan(address indexed _from, address indexed _sender, address indexed _creator, bytes32 _intention, bytes32 _prequalification);

/* Modifiers */    
    
	modifier onlyCreator {
		require(uint8(userbase.getDoer()) == uint8(IS.CREATOR));
		_;
	}

	modifier onlyDoer {
		require (uint8(userbase.getDoer()) != uint8(IS.CREATOR)); 
		_;
	}

	modifier onlyCurator {
		require (uint8(userbase.getDoer()) == uint8(IS.CURATOR)); 
		_;
	}

	modifier onlyTrustee {
		require (uint8(userbase.getDoer()) == uint8(IS.ACTIVE)); 
		_;
	}

	modifier onlyProver {
		require (uint8(userbase.getDoer()) == uint8(IS.PROVER)); 
		_;
	}
/* Functions */ 

    function Database(Able _ctrl) public {
        cName = CONTRACTNAME;
        contrl = _ctrl;
		owner = contrl.owner();
		controller = contrl.controller();
		ContractEvent(this,msg.sender,tx.origin);
	}

/////////////////
// All METAS
/////////////////

	function setAllPlans(bytes32 _planId) external onlyController {
		allPlans.push(_planId);
	}
	
	function setPromise(bytes32 _serviceId) external onlyController {
		require(promiseCount++ < 2^256);
		allPromises[_serviceId].push(tx.origin);
	}

	function getBase() pure public returns (uint8) {
		return BASE;
	}

/////////////////
// All ASSERTS
/////////////////

	function isPlanning(bytes32 _intention) public view returns (uint256) { 
        return uint256(plans[_intention].state);
    }

/////////////////
// All GETTERS FOR FUTURE USE
/////////////////

	/// @notice Get the initialisation data of a plan created by a Creator. 
    /// @param _intention The query condition of the contract
	//  @dev `anybody` can retrive the plan data in the contract Plan has five levels
    function getPlan(
		bytes32 _intention) 
		view external returns (Plan,Project) 
		{
        return (plans[_intention].plan, plans[_intention].state);
    }

    function getServiceCondP(
		bytes32 _intention, bytes32 _serviceId) 
		view external returns (Merits) 
		{
        return plans[_intention].services[_serviceId].definition.preCondition.merits;
    }

    function getServiceCondP(
		bytes32 _intention, bytes32 _serviceId, KBase _index) 
		view external returns (Qualification) 
		{
        return plans[_intention].services[_serviceId].definition.preCondition.qualification[BASE^uint8(_index)];
    }

    function getServiceCondQ(
		bytes32 _intention, bytes32 _serviceId) 
		view external returns (Desire) 
		{
        return plans[_intention].services[_serviceId].definition.postCondition;
    }

    function getServiceMetas(
		bytes32 _intention, bytes32 _serviceId) 
		view external returns (Metas) 
		{
        return plans[_intention].services[_serviceId].definition.metas;
    }

    function getPromise(
		bytes32 _intention, bytes32 _serviceId, address _address) 
		view external returns (Promise) 
		{
        return plans[_intention].services[_serviceId].procure[_address].promise;
    }
	
	function getFulfillment(
		bytes32 _intention, bytes32 _serviceId, address _doer) 
		view external returns (Fulfillment) 
		{
		return plans[_intention].services[_serviceId].procure[_doer].fulfillment;
	}

	function getVerification(
		bytes32 _intention, bytes32 _serviceId, address _doer,address _prover) 
		view external returns (Verification) 
		{
		return plans[_intention].services[_serviceId].procure[_doer].verification[_prover];
	}


//////////////////////////////
// ALL GETTERS FOR CURRENT USE
//////////////////////////////
	function planState(
		bytes32 _intention) view external returns (Project) {
			return plans[_intention].state;
		}

	function planGoal(
		bytes32 _intention) view external returns (
			bytes32 goal,
			bool status) 
			{
				return (
					plans[_intention].plan.postCondition.goal,
					plans[_intention].plan.postCondition.status);
		}
	function planProject(
		bytes32 _intention) view external returns (
			bytes32 preCondition,
			uint time,
			uint budget,
			bytes32 projectUrl,
			address creator,
			address curator) 
			{
				return (
					plans[_intention].plan.preCondition,
					plans[_intention].plan.time,
					plans[_intention].plan.budget,
					plans[_intention].plan.projectUrl,
					plans[_intention].plan.creator,
					plans[_intention].plan.curator);
	}

/////////////////
// All SETTERS
/////////////////

	/// @notice Get the initialisation data of a plan created by a Creator. 
    /// @param _intention The query condition of the contract
	//  @dev `anybody` can retrive the plan data in the contract Plan has five levels
	function initPlan(
		bytes32 _intention,
		bytes32 _serviceId,
		Plan _planData,
		Project _state,
		bytes32 _preQualification) public payable onlyCreator {
			require(uint(plans[_intention].state) == 0); // This is a new plan? // Cannot overwrite incomplete Plan // succesful plan??
			plans[_intention].plan = _planData;
			plans[_intention].state = _state;
			plans[_intention].services[_serviceId].definition.preCondition.merits.hash = _preQualification;
			// plans[_intention].project = true;
			NewPlan(tx.origin,msg.sender,plans[_intention].plan.creator,_intention,_preQualification);
			
	}

    function setService(
		bytes32 _intention, 
		bytes32 _serviceId,
		Merits _merits,
		Qualification _qualification,
		KBase _index
		) public onlyCurator {
			plans[_intention].services[_serviceId].definition.preCondition.merits = _merits;
			plans[_intention].services[_serviceId].definition.preCondition.qualification[BASE^uint8(_index)] = _qualification;			
	}

    function setService(
		bytes32 _intention, 
		bytes32 _serviceId,
		Desire _postCondition
		) public onlyCurator {
			plans[_intention].services[_serviceId].definition.postCondition = _postCondition;			
	}

    function setService(
		bytes32 _intention, 
		bytes32 _serviceId,
		uint _timeSoft,  // preferred timeline
		uint _expire,
		bytes32 hash,
		bytes32 _serviceUrl,
		address _doer
		) external onlyCurator
		{
			plans[_intention].services[_serviceId].definition.metas = Metas({ 
				timeSoft: _timeSoft,
				expire: _expire, 
				hash: hash, 
				serviceUrl: _serviceUrl, 
				doer: _doer});
			
	}

    function setService(
		bytes32 _intention, 
		bytes32 _serviceId,
		Metas _metas
		) public onlyController
		{
			plans[_intention].services[_serviceId].definition.metas = _metas;
    }

    function setPromise(
		bytes32 _intention, 
		bytes32 _serviceId, 
		address _doer,
		Intention _thing,
		uint _timeHard,   // proposed timeline
		bytes32 hash
		) public onlyDoer
		{
        	plans[_intention].services[_serviceId].procure[_doer].promise = Promise({
				thing: _thing, 
				timeHard: _timeHard, 
				hash: hash});
	}
	
	function setFulfillment(
		bytes32 _intention, 
		bytes32 _serviceId, 
		address _doer,
		bytes32 _proof,
		Level _rubric,
		uint _timestamp,
		bytes32 hash
		) external onlyTrustee
		{
			plans[_intention].services[_serviceId].procure[_doer].fulfillment = Fulfillment({
				proof: _proof, 
				rubric: _rubric, 
				timestamp: _timestamp, 
				hash: hash});
	}

	function setVerification(
		bytes32 _intention, 
		bytes32 _serviceId, 
		address _doer,
		address _prover,
		bytes32 _verity,
		bool _complete,
		uint _timestamp,
		bytes32 hash
		) external onlyProver
		{
			plans[_intention].services[_serviceId].procure[_doer].verification[_prover] = Verification({
				verity: _verity, 
				complete: _complete, 
				timestampV: _timestamp, 
				hash: hash});
	}

	function setPlan(Plan _data, bytes32 _intention) public onlyController {
		plans[_intention].plan = _data;
    }

    function adminService(bytes32 _intention, bytes32 _serviceId, Merits _merits, Qualification _qualification, KBase _index) public onlyController {
		plans[_intention].services[_serviceId].definition.preCondition.merits = _merits;
		plans[_intention].services[_serviceId].definition.preCondition.qualification[BASE^uint8(_index)] = _qualification;
    }

    function adminService(bytes32 _intention, bytes32 _serviceId, Desire _desire) public onlyController {
			plans[_intention].services[_serviceId].definition.postCondition = _desire;
    }

    function adminService(bytes32 _intention, bytes32 _serviceId, Metas _metas) public onlyController {
		plans[_intention].services[_serviceId].definition.metas = _metas;
    }

    function setPromise(Promise _data, bytes32 _intention, bytes32 _serviceId, address _address) public onlyController {
        plans[_intention].services[_serviceId].procure[_address].promise = _data;
    }
	
	function setFulfillment(Fulfillment _data, bytes32 _intention, bytes32 _serviceId, address _doer) public onlyController {
		plans[_intention].services[_serviceId].procure[_doer].fulfillment = _data;
	}

	function setVerification( Verification _data, bytes32 _intention, bytes32 _serviceId, address _doer, address _prover) public onlyController {
			plans[_intention].services[_serviceId].procure[_doer].verification[_prover] = _data;
	}


/* End of Database */
}

////////////////////
// Userbase Contract
////////////////////
contract Userbase is BaseController {
    
/* Constants */

    bytes32 constant internal CONTRACTNAME = "Userbase";
	uint8 constant internal BASE = 2;

/* Enums */


/* Structs */
	

/* State Variables */
    
	uint public plansCount;
	uint public promiseCount;
    uint public orderCount;
    uint public fulfillmentCount;
	uint public verificationCount;
	
	uint internal talentK; 						// Total number of all identified talents
	uint internal talentI;	  					// Total number of talents of all individuals
	uint internal talentR;						// Total number of unique talents

	uint public doerCount;	// !!! Can I call length of areDoers instead??!!!
    mapping(bytes32 => uint) public talentF; 	// Frequency of occurence of a talent  
        
    mapping(address => Agent) public agents;

	mapping(bytes32 => address) public keyid;

	mapping(address => bytes32[]) public allPromises;

    bytes32[] public allPlans;

	address[] public doersAccts;


/* Events */

	event NewPlan(address indexed _from, address indexed _sender, address indexed _creator, bytes32 _intention, bytes32 _prequalification);

/* Modifiers */    
    
	modifier onlyCreator {
		require(agents[msg.sender].state == IS.CREATOR);
		_;
	}

	modifier onlyDoer {
		require (agents[msg.sender].state != IS.CREATOR); 
		_;
	}

	modifier onlyCurator {
		require (agents[msg.sender].state == IS.CURATOR); 
		_;
	}

	modifier onlyTrustee {
		require (agents[msg.sender].state == IS.ACTIVE); 
		_;
	}

	modifier onlyProver {
		require (agents[msg.sender].state == IS.PROVER); 
		_;
	}
/* Functions */ 

    function Userbase(Able _ctrl) public {
        cName = CONTRACTNAME;
        contrl = _ctrl;
		ContractEvent(this,msg.sender,tx.origin);
	}

/////////////////
// All ASSERTS
/////////////////

	function isAble() view public returns (bytes32) {
		contrl.KEYID;
	}

	function isAgent(address _address) public view returns (bool) {
		return agents[_address].active;
	}

	function isAgent(bytes32 _uuid) public view returns (bool) { // Point this to oraclise service checking MSD on 
		return agents[keyid[_uuid]].active;	// https://pgp.cs.uu.nl/paths/4b6b34649d496584/to/4f723b7662e1f7b5.json
	}
	
	function isCreator() external view returns (bool) {
		agents[msg.sender].state == IS.CREATOR ? true : false;
	}

	function isDoer() external view returns (bool) {
		agents[msg.sender].state != IS.CREATOR ? true : false;
	}

/////////////////
// All GETTERS
/////////////////

	/// @notice Get the data of all Talents in the ecosystem.
    /// @param _data The query condition of the contract
	//  @dev `anybody` can retrive the talent data in the contract
	function getTalents(bytes32 _data) view external returns (uint var1, uint var2, uint var3, uint var4) {
		// check_condition ? true : false;
		var1 = talentI;
		var2 = talentF[_data];
		var3 = talentR;
		var4 = talentK;
	}

	/// @notice Get the number of doers that can be spawned by a Creators.
    /// The query condition of the contract
	//  @dev `anybody` can retrive the count data in the contract
	function getCreatorsNum() view external onlyCreator returns(uint) {
		return agents[tx.origin].myDoers ;
	}

	/// @notice Get the active status of a Creator and its number of doers spawned.
    /// @param _address The query condition of the contract
	//  @dev `anybody` can retrive the count data in the contract
	function getCreators(address _address) view external returns (bool,uint256) {
        return (agents[_address].active, agents[_address].myDoers);
	}

	function getDoer(address _address) public view returns (Agent) {
		return agents[_address];
	}

	function getDoer() public view returns (IS) {
		return agents[msg.sender].state;
	}

	function getDoer(bytes32 _uuid) public view returns (Agent) { // Point this to oraclise service checking MSD on 
		return agents[keyid[_uuid]];	// https://pgp.cs.uu.nl/paths/4b6b34649d496584/to/4f723b7662e1f7b5.json
	}

/////////////////
// All SETTERS
/////////////////

	/// @notice Get the initialisation data of a plan created by a Creator. 
    /// The query condition of the contract
	//  @dev `anybody` can retrive the plan data in the contract Plan has five levels

	function updateTalent() public onlyDoer returns (bool) {
		if (talentF[Doers(msg.sender).getBeliefn("talent_")] == 0) {  // First time Doer 
			require(talentR++ < 2^256);
			}
		require(talentF[Doers(msg.sender).getBeliefn("talent_")]++ < 2^256);
		require(talentI++ < 2^256);
		require(talentK++ < 2^256);
	}

	function changeTalent() public onlyDoer returns (bool) {
		require(talentF[Doers(msg.sender).getBeliefn("talent_")]-- > 0);
		if (talentF[Doers(msg.sender).getBeliefn("talent_")] == 0) {  // First time Doer 
			require(talentR-- > 0);
			}
		require(talentI-- > 0);
	}

	function initDoer(Agent _data, bytes32 _uuid, address _address) public returns (bool) {
		agents[_address] = _data;
		keyid[_uuid] = _address;
	}

	function setAllPlans(bytes32 _planId) external onlyController {
		allPlans.push(_planId);
	}

	function setAllPromises(bytes32 _serviceId) external onlyController {
		require(promiseCount++ < 2^256);
		allPromises[tx.origin].push(_serviceId);
	}

	function setAgent(Agent _data, address _address, bytes32 _keyId) public onlyController {
		agents[_address] = _data;
		keyid[_keyId] = _address;
	}
	function setAgent(address _address, bytes32 _keyId) external onlyController {
		agents[_address].keyId = _keyId;
		keyid[_keyId] = _address;
	}

	function setAgent(address _address, IS _state) external onlyController {
		agents[_address].state = _state;
	}

	function setAgent(address _address, bool _active) external onlyController {
		agents[_address].active = _active;
	}

	function setAgent(address _address, uint _allowed) external onlyController {
		require(agents[_address].state == IS.CREATOR);
		agents[_address].myDoers += _allowed;
	}

	function decMyDoers() public { // Decrement a Creators Doers
	    require(agents[tx.origin].myDoers-- > 0);
		//agents[tx.origin].myDoers -=1;
	}
	
	function incAllDoers() public { // Increment all Doers
		require(doerCount++ < 2^256);
	   // doerCount++;
	}

	function setDoersNum(uint _num) public onlyController {
		doerCount = _num;
	}
	
	function setDoersAdd(address _address) public {
	    doersAccts.push(_address);
	}


/* End of Userbase */
}



// Doers is a class library of natural or artificial entities within A multi-agent system (MAS).
// The agents are collectively capable of reaching goals that are difficult to achieve by an 
// individual agent or monolithic system. The class can be added to, modified and reconstructed, 
// without the need for detailed rewriting. 
// The nature of an agent is: 
// An identity structure
// A behaviour method
// A capability model
// 

///////////////////
// Beginning of Contract
///////////////////

contract Creators is DataController {

/// @dev The actual agent contract, the nature of the agent is identified controller is the msg.sender
///  that deploys the contract, so usually this token will be deployed by a
///  token controller contract.

    bytes32 constant internal CONTRACTNAME = "Creator";

	bytes32 public userName;
	bytes32 public ownUuid;
	address ownAddress;	

	function Creators(Able _ctrl, Userbase _ubs, bytes32 _name) public {
		cName = CONTRACTNAME;
		contrl = _ctrl;
		userbase = _ubs;
		ownAddress = msg.sender;
		userName = _name;
		ContractEvent(this,msg.sender,tx.origin);
	}

	function makeDoer(
		bytes32 _fPrint,
        bytes32 _idNumber,
		bytes32 _lName,
        bytes32 _hash,
		bytes32 _tag,
		bytes32 _data,
        uint _birth,
		bool _active
		) onlyCreator public returns (bool,address) 
		{
			require(userbase.getCreatorsNum() > 0);
			bytes32 uuidCheck = keccak256(_fPrint, _birth, _lName, _idNumber);
			require(!userbase.isAgent(uuidCheck));
			Doers newDoer = new Doers(
				userbase,
				ownUuid, 
				setDoer(_fPrint,_idNumber,_lName,_hash,_tag,_data,_birth,_active));
			userbase.initDoer(Agent(ownUuid, IS.INACTIVE, true, 0), uuidCheck, newDoer);
			userbase.decMyDoers();
			userbase.incAllDoers();
			return (true,newDoer);
	}

/////////////////
// All ASSERTS
/////////////////

	function isDoer(address _address) view external returns (bool) { // Point this to oraclise service checking MSD on 
		return userbase.isAgent(_address);	// https://pgp.cs.uu.nl/paths/4b6b34649d496584/to/4f723b7662e1f7b5.json
	}

	function isDoer(bytes32 _keyId) view external returns (bool) {
		return userbase.isAgent(_keyId);
	}

	function isCreator() external view returns (bool) { // Consider use of delegateCall
		userbase.isCreator();
	}

	function isDoer() view external returns (bool) { // Point this to oraclise service checking MSD on 
		return userbase.isDoer();	// https://pgp.cs.uu.nl/paths/4b6b34649d496584/to/4f723b7662e1f7b5.json
	}

// 	function isPlanning(bytes32 _intention) view external returns (uint256) { 
//         return userbase.isPlanning(_intention);
//     }

/////////////////
// All GETTERS
/////////////////
	
	function getOwner() public view returns (address) {
        return ownAddress;
	}

	function getCreator(address _address) view public returns (bool,uint256) {
        return userbase.getCreators(_address);
	}

	function getDoerCount() view public returns (uint) {
		return userbase.doerCount();
	}

/////////////////
// All SETTERS
/////////////////

	function setMyDoers(bool _active, uint _allowed) external onlyController {
		userbase.setAgent(msg.sender, _active);
		userbase.setAgent(msg.sender, _allowed);
	}

	function initCreator(bytes32 _keyId, bool _active, uint _num) external {
		userbase.setAgent(
			Agent({keyId: _keyId, state: IS.CREATOR, active:_active, myDoers: _num}), msg.sender, _keyId);
	}

	function setDoer(
		bytes32 _fPrint,
		bytes32 _idNumber,
		bytes32 _lName,
		bytes32 _hash,
		bytes32 _tag,
		bytes32 _data,
		uint _birth,
		bool _active
		) internal pure returns (SomeDoer) 
		{
			bytes32 reset;
			return SomeDoer({
				fPrint:_fPrint, 
				idNumber:_idNumber, 
				email: reset, 
				fName: reset, 
				lName:_lName, 
				hash:_hash, 
				tag:_tag, 
				data:_data, 
				age:_birth, 
				active:_active});
	}

/* END OF CREATORS */
}

// Doers is a class library of natural or artificial entities within A multi-agent system (MAS).
// The agents are collectively capable of reaching goals that are difficult to achieve by an 
// individual agent or monolithic system. The class can be added to, modified and reconstructed, 
// without the need for detailed rewriting. 
// The nature of an agent is: 
// An identity structure
// A behaviour method
// A capability model
// 

///////////////////
// Beginning of Contract
///////////////////

contract Doers is usingOraclize, UserDefined {

	modifier onlyCreator {
		require(msg.sender == creatorAdd);
		_;
	}

	modifier onlyDoer {
		require(Me.active && msg.sender == ownAdd);
		_;
	}

	modifier onlyOraclize {
		require (msg.sender == oraclize_cbAddress());
		_;
	}

	Userbase dbs;

	address public Controller;
	address public creatorAdd;
	bytes32 public creatorUuid;
	address public ownAdd;
	bytes32 public ownUuid = Me.fPrint;
	

	SomeDoer public Me;// = SomeDoer(0x4fc6c65443d1b988, "whoiamnottelling", 346896000, "Iam", "Not", false);		
			
	BDI internal myBDI;

	Belief public myBelief = myBDI.beliefs;
	Merits public myMerits = myBDI.beliefs.merits;
	// Qualification public myQualification = myBDI.beliefs.qualification;
	// Desire public myDesire = myBDI.desires;
	// Intention public myIntention = myBDI.intentions;
	
	Promise public myPromises;
	uint256 promiseCount;

	Fulfillment[] myOrders;
	uint256 orderCount;

	uint8 base; // !!! GET THIS DATA FROM DATABASE
	uint8 rate = 10; // !!! GET THIS DATA FROM DATABASE
	uint year = 31536000; // !!! GET THIS DATA FROM DATABASE
	uint period = 31536000; // !!! GET THIS DATA FROM DATABASE

	uint refMSD; // !!! GET THIS DATA FROM DATABASE  **** MAYBE WE SHOULD JUST MEASURE THIS RELATIVE TO THE INDIVIDUAL ****
	uint refRank;  //!!! GET THIS DATA FROM DATABASE
	uint refSigned; //!!! GET THIS DATA FROM DATABASE
	uint refSigs; //!!! GET THIS DATA FROM DATABASE
	uint refTrust; //!!! GET THIS DATA FROM DATABASE

	string[6][] public oraclizeResult;
	bytes32 public oraclizeId;

	mapping (bytes32 => BE) oraclizeCall;
	enum BE {QUALIFICATION, EXPERIENCE, REPUTATION, TALENT}
	
	//Creators.Flag aflag;
	
	function Doers(Userbase _data, bytes32 _creatorUuid, SomeDoer _adoer) public {
		dbs = _data;
		creatorAdd = msg.sender;
		creatorUuid = _creatorUuid;
		ownAdd = tx.origin;
		Me = _adoer;
		// oraclize_setCustomGasPrice(4000000000 wei);
        // oraclize_setProof(proofType_TLSNotary | proofStorage_IPFS); // !!! UNCOMMENT BEFORE DEPLOYING
		ContractEvent(this,msg.sender,tx.origin);
	}

	function bdiIndex() public payable onlyDoer returns (bool,bool,bool,bool) {
		return(
			updateBelief(BE.QUALIFICATION),
			bdiExperience(),
			updateBelief(BE.REPUTATION),
			bdiTalent());
	}

	function updateBelief(BE _data) public payable onlyDoer returns (bool) {
		if (_data == BE.QUALIFICATION) {
			if (oraclize_getPrice("URL") > this.balance) {
            LogNewOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
			return false;
			} else {
				// Oraclize can be queried
				string memory str1 = "BHluq1rq39/VBA1k0cNeu69ZJRQXQiJ/B5+OMTNLsDNhdhUCn1+YR5vgsHP4ItXS3pcBlDIGQi/e1pY7/YrHA/JLR/GXKRxuXWbsW4cMeSRZJy7qplB7GCqHEbKzdHU1U15UNpV7RnMowdrzlzZ1udA=";
				// bytes32 memory var1 = dbs.isAble();
				string memory str2 = "BIaV+ikiLqBIDcKCAVVZhXnP7o3A1G8qkDQONXWcpi6I0taLjZ4Zc3i4HAiaDf0d1PtSfslHXLYZ9Cm+zxdYGfluSCuZX8f2nFvRvcdwA50nkMWPvg==";
				string memory str3 = "BP1VdQXD/Toz4lMdKC11Ot/AhhJPAznk6Lt/mfWuFF2bBeKastnqGoIyw0DL+vKS+w8xM0qIBcv8uqx4cK5rMQFBSrzrDVU0fuYKSEK3+J8X6HRahPse+ntbJcrGYbhs";
				// oraclizeId = oraclize_query("URL", "json(https://pgp.cs.uu.nl/paths/dc80f2a6d5327cb9/to/8b962943fc243f3c.json).xpaths.0");
				oraclizeId = oraclize_query("URL", strConcat(str1,bytesToString(dbs.isAble()),str2,bytesToString(ownUuid),str3));
				oraclizeCall[oraclizeId] = BE.QUALIFICATION;
				LogNewOraclizeQuery("Oraclize query was sent for QUALIFICATION, standing by for the answer..");
				return true;
				}
		}

		if (_data == BE.REPUTATION) {
			if (oraclize_getPrice("URL") > this.balance) {
            LogNewOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
			return false;
			} else {
				// Oraclize can be queried
				string memory strn1 = "BBc6eMv0JDgmEpODSfeusLPyoi8iBF7Axk8vrf9mNlNgxDnPHzB/udAp57ZQqGe8DmGDn8Z7v2c1TnVWT41KFYhMQDn9XKM3H5jeR3Ee9T9qcaZHQre4orpfzdhyIUApA6fzrmeirWsQL5DEQmAa+K0=";
				string memory strn2 = "BDQ9sBW3jkEZSqJc5jTxdgkBZ7TL32siPHOIR1+GMAQ4hNjkNMp5IiStdJFh64yja0IkWpLHafdyNuMWg7qq/fqp64dClvaJuf9/XvHpcNdbJNkbza/NDkWyAw==";
				// oraclizeId = oraclize_query("URL", "json(https://pgp.cs.uu.nl/stats/8b962943fc243f3c.json).KEY");
				oraclizeId = oraclize_query("URL", strConcat(strn1,bytesToString(ownUuid),strn2));
				oraclizeCall[oraclizeId] = BE.REPUTATION;
				LogNewOraclizeQuery("Oraclize query was sent for REPUTATION, standing by for the answer..");
				return true;
				}
		}
	}
	
	function __callBack(bytes32 myid, string[6][] result, bytes proof) onlyOraclize {
		oraclizeResult = result;
		LogNewResult(result, proof);
		ContractCallEvent(this,msg.sender,tx.origin,myid);
		if (oraclizeCall[myid] == BE.QUALIFICATION) {
			bdiQualification(result);
		}

		if (oraclizeCall[myid] == BE.REPUTATION) {
			bdiReputation(result);
		}

	}		
	
	function bdiQualification(string[6][] _wotPath) internal returns (bool) {
		uint8 merit = uint8(KBase.DOCTORATE);
		while (myBDI.beliefs.qualification[merit].cAuthority == 0x0) {
			// merit == 0 ? myBDI.beliefs.index = merit : merit --;
			if (merit == 0) {
				myBDI.beliefs.merits.index = 0;
				return false;}
			merit--;
		}
		// require(insert here oraclise function to check MSD path from creatorUuid -> cAuth_kid -> doerUuid == 2hops)
		//creatorUuid;
		//myBDI.beliefs.qualification[merit].cAuthority;
		//doerUuid; 
		uint hops = _wotPath.length; // Length of the Path is 2 ABLE -> CA -> DOER
		uint hop1MSD = parseInt(_wotPath[1][1],0); // CA is also the cAuthority
		uint hop1Rank = parseInt(_wotPath[2][1],0); // Insert here result from oraclise callback

		if (hops < 3 && hop1MSD < refMSD && hop1Rank < refRank) {
			// Calculate experience
			myBDI.beliefs.merits.index += base ** merit;
			QualificationEvent(this,msg.sender,tx.origin,"0x66616c7365",bytes(_wotPath[0][1]));
			return true;
		} else { 
			return false;}
			QualificationEvent(this,msg.sender,tx.origin,"0x74727565",bytes(_wotPath[0][1]));
	}

	function bdiExperience() internal returns (bool) {
		// uint experience = myBDI.beliefs.experience;
		// Insert here function to convert experience to epoch time format here

		if ((block.timestamp - myBDI.beliefs.merits.experience) > year) {
			// !!! Maybe subtract Reputation and Talent first here before proceeding
			myBDI.beliefs.merits.index = myBDI.beliefs.merits.index * ((1 + rate/100) ** uint8(myBDI.beliefs.merits.experience / period));
			year += period;
			return true;
			} else {
				return false;
			}
	}

	function bdiReputation(string[6][] _wotStats) internal returns (bool) {
		uint trust = parseInt(_wotStats[0][0]);
		uint msd = parseInt(_wotStats[0][2]);
		uint rank = parseInt(_wotStats[0][3]);
		uint signed = parseInt(_wotStats[0][4]);
		uint sigs = parseInt(_wotStats[0][5]);
		

		if (msd >= refMSD && rank >= refRank && trust >= refTrust) {
			myBDI.beliefs.merits.reputation = bytes32(signed / sigs); //
		}

		// insert here oraclise function to check nodes networkx.algorithms.shortest_paths.weighted
		// oraclise function to check nodes clustering coefficient (weighted)
		// networkx.algorithms.centrality.closeness_centrality
		// networkx.algorithms.shortest_paths.weighted.multi_source_dijkstra_path
		
		return true;

	}

	function bdiTalent() internal returns (bool) {
		bytes32 talent = myBDI.beliefs.merits.talent;

		return true;
	}

/////////////////
// All HELPERS
/////////////////
function bytesToString(bytes32 _bytes) public constant returns (string) {

    // string memory str = string(_bytes);
    // TypeError: Explicit type conversion not allowed from "bytes32" to "string storage pointer"
    // thus we should fist convert bytes32 to bytes (to dynamically-sized byte array)

    bytes memory bytesArray = new bytes(_bytes.length);
    for (uint256 i; i < _bytes.length; i++) {
        bytesArray[i] = _bytes[i];
        }
    return string(bytesArray);
    }

/////////////////
// All ASSERTERS
/////////////////

	function isDoer() view public returns (bool) {
		if (Me.active) {
			return true;}
			return false;
	}

/////////////////
// All GETTERS
/////////////////


	function viewBelief() view public returns (uint,bytes32,bytes32,uint8,bytes32) {
	    return (myBDI.beliefs.merits.experience,
        	    myBDI.beliefs.merits.reputation,
        	    myBDI.beliefs.merits.talent,
        	    myBDI.beliefs.merits.index,
        	    myBDI.beliefs.merits.hash);
	}
	
	function viewBelief(KBase _kbase) view external returns (bytes32,bytes32,bytes32) {
		return (myBDI.beliefs.qualification[uint8(_kbase)].country,
		        myBDI.beliefs.qualification[uint8(_kbase)].cAuthority,
		        myBDI.beliefs.qualification[uint8(_kbase)].score);
	}
	
	function viewDesire(bytes1 _desire) view public returns (bytes32,bool) {
		return (
			myBDI.desires[_desire].goal,
			myBDI.desires[_desire].status);
	}

	function viewIntention(bool _check) view public returns (IS,bytes32,uint256) {
		return (
			myBDI.intentions[_check].state,
			myBDI.intentions[_check].service,
			myBDI.intentions[_check].payout);
	}

	function getInfo() constant public returns (address,address,bytes32) {
		return (creatorAdd, ownAdd, ownUuid);
	}
	
	function getDoer() view public returns (bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,uint,bool) {
		return (Me.fPrint,Me.idNumber,Me.email,Me.fName,Me.lName,Me.hash,Me.tag,Me.data,Me.age,Me.active);
	}

	function getBelief(bytes32 _index) view public returns (uint) {
		if (_index == "experience") {
			return myBDI.beliefs.merits.experience;
			} else if (_index == "index") {
			return myBDI.beliefs.merits.index;
			} else {
				getBeliefn(_index);
				}
	}
	function getBeliefn(bytes32 _index) view public returns (bytes32) {
		if (_index == "reputation") {
			return myBDI.beliefs.merits.reputation;
			} else if (_index == "talent") {
			return myBDI.beliefs.merits.talent;
			} else if (_index == "hash") {
			return myBDI.beliefs.merits.hash;
			}
	}

	function getQualification(KBase _kbase) view external returns (Qualification) {
		return (myBDI.beliefs.qualification[uint8(_kbase)]);
	}

	///@dev In use
	// @param _desire
	function getDesire(bytes1 _desire) view public returns (Desire) {
		return myBDI.desires[_desire];
	}
	
	function getIntention(bool _check) view external returns (Intention) {
		return myBDI.intentions[_check];
	}
	
	function getPromise() internal view onlyDoer returns (Intention,uint,bytes32) {
		return (myPromises.thing, myPromises.timeHard, myPromises.hash);
	}

/////////////////
// All SETTERS
/////////////////

	function setBDI(
		Flag _flag, bytes1 _goal, 
		bool _intent, 
		bytes32 _var, 
		bool _status,
		KBase _kbase, 
		IS _avar) internal onlyDoer returns (bool) 
		{
			if ((_flag == Flag.talent) || (_flag == Flag.t)) {
				return true;
				} else if ((_flag == Flag.country) || (_flag == Flag.c)) {
					myBDI.beliefs.qualification[uint8(_kbase)].country = _var;
					return true;
				} else if ((_flag == Flag.cAuthority) || (_flag == Flag.CA)) {
					myBDI.beliefs.qualification[uint8(_kbase)].cAuthority = _var;
					return true;
				} else if ((_flag == Flag.score) || (_flag == Flag.s)) {
					myBDI.beliefs.qualification[uint8(_kbase)].score = _var;
					return true;
				} else if ((_flag == Flag.goal) || (_flag == Flag.g)) {
					myBDI.desires[_goal].goal = _var;
					return true;
				} else if ((_flag == Flag.statusD) || (_flag == Flag.SD)) {
					myBDI.desires[_goal].status = _status;
					return true;
				} else if ((_flag == Flag.statusI) || (_flag == Flag.SI)) {
					myBDI.intentions[_intent].state = _avar;
					return true;
				} else if ((_flag == Flag.service) || (_flag == Flag.S)) {
					myBDI.intentions[_intent].service = _var;
					return true;
					} else {
						return false;
						}
	}
	
	function setDoer(SomeDoer _aDoer) public onlyCreator {
		Me = _aDoer;
	}

	function setTalent(bytes32 _talent) internal onlyDoer {
		if (myBDI.beliefs.merits.talent == 0x00) {
			myBDI.beliefs.merits.talent = _talent;
			dbs.updateTalent();
		} else {
			dbs.changeTalent();
			myBDI.beliefs.merits.talent = _talent;
			dbs.updateTalent();
		}
		
	}

	function setQualification(
		KBase _kbase, 
		bytes32 _country, 
		bytes32 _cAuthority, 
		bytes32 _score, 
		uint _year
		) internal onlyDoer
		{
			if (_kbase != KBase.LICENSE) { // exclude Bachelors from prerequisite of having a License
				require(myBDI.beliefs.qualification[uint8(_kbase) - 1].cAuthority != 0x0);
			}			
			myBDI.beliefs.qualification[uint8(_kbase)] = Qualification({
				country: _country, 
				cAuthority: _cAuthority, 
				score: _score});
			myBDI.beliefs.merits.experience = _year;
	}
	
	function setDesire(Desire _goal, bytes1 _desire) internal onlyDoer {
		myBDI.desires[_desire] = _goal;
	}

	function setIntention(Intention _service, bool _intention) internal onlyDoer {
		myBDI.intentions[_intention] = _service;
	}

////////////////
// Events
////////////////
    event ContractEvent(address indexed _this, address indexed _sender, address indexed _origin);
	event ContractCallEvent(address indexed _this, address indexed _sender, address indexed _origin, bytes32 _data);
	event QualificationEvent(address indexed _this, address indexed _sender, address indexed _origin, bytes16 _message, bytes _data);
	event PlanEvent(address indexed _from, address indexed _to, uint256 _amount);
    event PromiseEvent(address indexed _from, address indexed _to, uint256 _amount);
    event Fulfill(address indexed _from, address indexed _to, uint256 _amount);
	event LogNewOraclizeQuery(string description);
    event LogNewResult(string[6][] result, bytes proof);
}

// interface SomeDoers {
// 	function Doers(SomeDoer _aDoer) returns (bool);
// 	}
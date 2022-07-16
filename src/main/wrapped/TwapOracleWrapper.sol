pragma solidity >=0.6.0;
pragma experimental ABIEncoderV2;

import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.6/interfaces/FlagsInterface.sol";
import { OracleLibrary } from "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";

interface IOracleWrapper {
	struct SavedResponse {
		uint256 currentPrice;
		uint256 lastPrice;
		uint256 lastUpdate;
	}

	function fetchPrice(address _token) external;

	function retriveSavedResponses(address _token) external returns (SavedResponse memory currentResponse);

	function getLastPrice(address _token) external view returns (uint256);

	function getCurrentPrice(address _token) external view returns (uint256);
}

/*
Uniswap V3's TWAP oracle wrapper
*/
contract TwapOracleWrapper is IOracleWrapper {
	event TwapChanged(uint32 newTwap);

	uint256 public constant TARGET_DIGITS = 18;
	address public owner;

	address public flagSEQOffline;
	FlagsInterface public flagsContract;
	AggregatorV3Interface public ethChainlinkAggregator;

	address public weth;
	uint32 public twapPeriodInSeconds = 1800;
	uint256 public latestEthPriceFetched;

	mapping(address => address) public uniswapV3Pools;
	mapping(address => SavedResponse) public savedResponses;

	modifier onlyOwner() {
		require(owner == msg.sender, "Ownable: caller is not the owner");
		_;
	}

	modifier notNull(address _address) {
		require(_address != address(0), "Invalid Address");
		_;
	}

	modifier isContract(address _address) {
		require(_address != address(0), "Invalid Address");

		uint256 size;
		assembly {
			size := extcodesize(_address)
		}

		require(size > 0, "Address is not a contract");
		_;
	}

	constructor(
		address _weth,
		address _ethChainlinkAggregator,
		address _flagSEQ,
		address _flagContract
	) public isContract(_weth) isContract(_ethChainlinkAggregator) notNull(_flagSEQ) isContract(_flagContract) {
		owner = msg.sender;

		weth = _weth;
		ethChainlinkAggregator = AggregatorV3Interface(_ethChainlinkAggregator);
		flagSEQOffline = _flagSEQ;
		flagsContract = FlagsInterface(_flagContract);

		if (fetchEthPrice() == 0) {
			revert("Chainlink is offline.");
		}
	}

	function transferOwnership(address _user) external onlyOwner {
		owner = _user;
	}

	function changeTwapPeriod(uint32 _timeInSecond) external onlyOwner {
		twapPeriodInSeconds = _timeInSecond;
		emit TwapChanged(_timeInSecond);
	}

	function addOracle(address _token, address _uniswapV3Pool)
		external
		isContract(_token)
		isContract(_uniswapV3Pool)
		onlyOwner
	{
		uniswapV3Pools[_token] = _uniswapV3Pool;
		fetchPrice(_token);
	}

	function removeOracle(address _token) external onlyOwner {
		delete uniswapV3Pools[_token];
		delete savedResponses[_token];
	}

	function fetchPrice(address _token) public override {
		uint256 tokenPrice = _getResponse(_token);

		SavedResponse storage response = savedResponses[_token];
		response.currentPrice = tokenPrice;
		response.lastPrice = tokenPrice;
		response.lastUpdate = block.timestamp;
	}

	function _getResponse(address _token) internal returns (uint256) {
		uint256 priceInETH = getTokenPriceInETH(_token, twapPeriodInSeconds);
		uint256 ethPriceInUSD = fetchEthPrice();

		return (priceInETH * ethPriceInUSD) / 1e18;
	}

	function retriveSavedResponses(address _token) external override returns (SavedResponse memory currentResponse) {
		fetchPrice(_token);
		return savedResponses[_token];
	}

	function getLastPrice(address _token) external view override returns (uint256) {
		return savedResponses[_token].lastPrice;
	}

	function getCurrentPrice(address _token) external view override returns (uint256) {
		return savedResponses[_token].currentPrice;
	}

	function getTokenPriceInETH(address _token, uint32 _twapPeriod) public view returns (uint256) {
		address v3Pool = uniswapV3Pools[_token];
		require(v3Pool != address(0), "TokenIsNotRegistered");

		(int24 arithmeticMeanTick, ) = OracleLibrary.consult(v3Pool, _twapPeriod);
		return OracleLibrary.getQuoteAtTick(arithmeticMeanTick, 1e18, _token, weth);
	}

	function fetchEthPrice() public returns (uint256) {
		if (flagsContract.getFlag(flagSEQOffline)) {
			return latestEthPriceFetched;
		}

		(uint80 roundId, int256 price, , , ) = ethChainlinkAggregator.latestRoundData();

		if (roundId == 0 || price == 0) return latestEthPriceFetched;

		uint8 decimals = ethChainlinkAggregator.decimals();

		latestEthPriceFetched = scalePriceByDigits(uint256(price), decimals);
		return latestEthPriceFetched;
	}

	function scalePriceByDigits(uint256 _price, uint256 _answerDigits) internal pure returns (uint256) {
		return
			_answerDigits < TARGET_DIGITS
				? _price * (10**(TARGET_DIGITS - _answerDigits))
				: _price / (10**(_answerDigits - TARGET_DIGITS));
	}
}

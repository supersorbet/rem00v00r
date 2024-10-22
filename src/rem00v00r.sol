// SPDX-License-Identifier: kek
pragma solidity ^0.8.23;

import {Ownable} from "solady/src/auth/Ownable.sol";
import {ReentrancyGuard} from "solady/src/utils/ReentrancyGuard.sol";


 interface IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4);
}

contract reM00v0000r is IERC721Receiver, Ownable, ReentrancyGuard {
    /// @notice The Uniswap V3-like NonFungiblePositionManager contract
    INonfungiblePositionManager public nonfungiblePositionManager;

    /// @dev Maximum value for uint128
    uint128 private constant MAX_UINT128 = type(uint128).max;

    /// @notice Invalid recipient address provided
    error InvalidRecipient();

    /// @notice Unauthorized NFT transfer attempted
    error UnauthorizedNFT();

    /// @notice Transaction deadline has passed
    error DeadlineExceeded();

    /// @notice Slippage tolerance exceeded
    /// @param expected Expected amount
    /// @param actual Actual amount received
    /// @param isToken0 Whether the slippage occurred for token0 or token1
    error SlippageExceeded(uint256 expected, uint256 actual, bool isToken0);

    /// @notice Insufficient liquidity in the position
    /// @param requested Amount of liquidity requested
    /// @param available Amount of liquidity available
    error InsufficientLiquidity(uint128 requested, uint128 available);

    /// @notice Invalid position manager address provided
    error InvalidPositionManager();

    /// @notice Initializes the contract with a position manager address
    /// @param _nonfungiblePositionManager Address of the NonFungiblePositionManager contract
    constructor(INonfungiblePositionManager _nonfungiblePositionManager) {
        if (address(_nonfungiblePositionManager) == address(0)) revert InvalidPositionManager();
        nonfungiblePositionManager = _nonfungiblePositionManager;
        _initializeOwner(msg.sender);
    }

    /// @notice Removes liquidity from a Uniswap V3-like position and collects tokens
    /// @param tokenId ID of the position token
    /// @param liquidity Amount of liquidity to remove
    /// @param amount0Min Minimum amount of token0 to receive
    /// @param amount1Min Minimum amount of token1 to receive
    /// @param deadline Timestamp after which the transaction will revert
    /// @param recipient Address to receive the collected tokens
    function reMoooo(
        uint256 tokenId,
        uint128 liquidity,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 deadline,
        address recipient
    ) external nonReentrant {
        if (recipient == address(0)) revert InvalidRecipient();
        if (block.timestamp > deadline) revert DeadlineExceeded();

        (, , , , , , , uint128 positionLiquidity, , , , ) = nonfungiblePositionManager.positions(tokenId);
        if (liquidity > positionLiquidity) revert InsufficientLiquidity(liquidity, positionLiquidity);

        nonfungiblePositionManager.safeTransferFrom(msg.sender, address(this), tokenId);

        (uint256 amount0, uint256 amount1) = nonfungiblePositionManager.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: liquidity,
                amount0Min: amount0Min,
                amount1Min: amount1Min,
                deadline: deadline
            })
        );

        if (amount0 < amount0Min) revert SlippageExceeded(amount0Min, amount0, true);
        if (amount1 < amount1Min) revert SlippageExceeded(amount1Min, amount1, false);

        (amount0, amount1) = nonfungiblePositionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: recipient,
                amount0Max: MAX_UINT128,
                amount1Max: MAX_UINT128
            })
        );

        (, , , , , , , uint128 liquidityRemaining, , , , ) = nonfungiblePositionManager.positions(tokenId);
        if (liquidityRemaining > 0) {
            nonfungiblePositionManager.safeTransferFrom(address(this), msg.sender, tokenId);
        }

        emit LPRemovedededed(msg.sender, tokenId, liquidity, amount0, amount1, recipient);
    }

    /// @notice Handles the receipt of an NFT
    /// @dev The ERC721 smart contract calls this function on the recipient
    /// after a `safeTransfer`. This function MAY throw to revert and reject the
    /// transfer. Return of other than the magic value MUST result in the
    /// transaction being reverted.
    /// @return `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
    /// unless throwing
    function onERC721Received(address, address, uint256, bytes calldata) external view override returns (bytes4) {
        if (msg.sender != address(nonfungiblePositionManager)) revert UnauthorizedNFT();
        return this.onERC721Received.selector;
    }

    /// @notice Updates the address of the NonFungiblePositionManager
    function updateManager(INonfungiblePositionManager _newPositionManager) external onlyOwner {
        if (address(_newPositionManager) == address(0)) revert InvalidPositionManager();
        nonfungiblePositionManager = _newPositionManager;
    }

    /// @notice Withdraws an NFT from the contract to the owner
    /// @param tokenId ID of the NFT to withdraw
    function wdNFT(uint256 tokenId) external onlyOwner {
        nonfungiblePositionManager.safeTransferFrom(address(this), owner(), tokenId);
    }

    /// @notice Withdraws ERC20 tokens from the contract to the owner
    /// @param tokenAddress Address of the ERC20 token to withdraw
    /// @param tokenAmount Amount of tokens to withdraw
    function plungeToken(address tokenAddress, uint256 tokenAmount) external onlyOwner {
        IERC20(tokenAddress).transfer(owner(), tokenAmount);
    }

    /// @notice Emitted when liquidity is successfully removed
    /// @param user Address of the user who removed liquidity
    /// @param tokenId ID of the position token
    /// @param liquidity Amount of liquidity removed
    /// @param amount0 Amount of token0 received
    /// @param amount1 Amount of token1 received
    /// @param recipient Address receiving the tokens
    event LPRemovedededed(address indexed user, uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1, address recipient);

}

/// @title Non-fungible Position Manager
/// @notice Wraps Uniswap V3 positions in a non-fungible token interface
interface INonfungiblePositionManager {
    struct DecreaseLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    function positions(uint256 tokenId) external view returns (
        uint96 nonce,
        address operator,
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 feeGrowthInside0LastX128,
        uint256 feeGrowthInside1LastX128,
        uint128 tokensOwed0,
        uint128 tokensOwed1
    );

    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function decreaseLiquidity(DecreaseLiquidityParams calldata params) external payable returns (uint256 amount0, uint256 amount1);
    function collect(CollectParams calldata params) external payable returns (uint256 amount0, uint256 amount1);
}

/// @title ERC20 Token Standard Interface
/// @dev Interface of the ERC20 standard as defined in the EIP.
interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

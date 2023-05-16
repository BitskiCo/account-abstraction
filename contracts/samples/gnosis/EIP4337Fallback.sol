//SPDX-License-Identifier: GPL
pragma solidity ^0.8.7;

/* solhint-disable no-inline-assembly */

import "@safe-global/safe-contracts/contracts/handler/TokenCallbackHandler.sol";
import "@safe-global/safe-contracts/contracts/Safe.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../../interfaces/IAccount.sol";
import "./EIP4337Manager.sol";

using ECDSA for bytes32;

/**
 * The Safe enables adding custom functions implementation to the Safe by setting a 'fallbackHandler'.
 * This 'fallbackHandler' adds an implementation of 'validateUserOp' to the Safe.
 * Note that the implementation of the 'validateUserOp' method is located in the EIP4337Manager.
 * Upon receiving the 'validateUserOp', a Safe with EIP4337Fallback enabled makes a 'delegatecall' to EIP4337Manager.
 */
contract EIP4337Fallback is TokenCallbackHandler, IAccount, IERC1271 {
    bytes4 internal constant ERC1271_MAGIC_VALUE = 0x1626ba7e;

    address immutable public eip4337manager;
    constructor(address _eip4337manager) {
        eip4337manager = _eip4337manager;
    }

    /**
     * delegate the contract call to the EIP4337Manager
     */
    function delegateToManager() internal returns (bytes memory) {
        // delegate entire msg.data (including the appended "msg.sender") to the EIP4337Manager
        // will work only for Safe contracts
        Safe safe = Safe(payable(msg.sender));
        (bool success, bytes memory ret) = safe.execTransactionFromModuleReturnData(eip4337manager, 0, msg.data, Enum.Operation.DelegateCall);
        if (!success) {
            assembly {
                revert(add(ret, 32), mload(ret))
            }
        }
        return ret;
    }

    /**
     * called from the Safe. delegate actual work to EIP4337Manager
     */
    function validateUserOp(UserOperation calldata, bytes32, uint256) override external returns (uint256 deadline){
        bytes memory ret = delegateToManager();
        return abi.decode(ret, (uint256));
    }

    /**
     * Helper for wallet to get the next nonce.
     */
    function getNonce() public returns (uint256 nonce) {
        bytes memory ret = delegateToManager();
        (nonce) = abi.decode(ret, (uint256));
    }

    /**
     * called from the Safe. delegate actual work to EIP4337Manager
     */
    function executeAndRevert(
        address,
        uint256,
        bytes memory,
        Enum.Operation
    ) external {
        delegateToManager();
    }

    function isValidSignature(
        bytes32 _hash,
        bytes memory _signature
    ) external override view returns (bytes4) {
        bytes32 hash = _hash.toEthSignedMessageHash();
        address recovered = hash.recover(_signature);

        Safe safe = Safe(payable(address(msg.sender)));

        // Validate signatures
        if (safe.isOwner(recovered)) {
            return ERC1271_MAGIC_VALUE;
        } else {
            return 0xffffffff;
        }
    }
}

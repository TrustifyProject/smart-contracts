// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Batch } from "./Batch.sol";
import { String } from "./String.sol";
import { Errors } from "./Errors.sol";
import { BatchTypes } from "./BatchTypes.sol";
import { AccessManager } from "./AccessManager.sol";

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
* @title Batch Manager.
* @dev Maintains the necessary on-chain batch state, keeping in sync with the underlying collection.
* @custom:security-contact @captainunknown7@gmail.com
*/
abstract contract BatchManager is Batch {
    using EnumerableSet for EnumerableSet.UintSet;

    uint256 internal _distributionEventId;
    uint256 internal _retailEventId;
    uint256 internal _internalBatchId;

    mapping(uint256 => EnumerableSet.UintSet) internal distributorsIdsForBatchId;
    mapping(uint256 => EnumerableSet.UintSet) internal retailersIdsForBatchId;
    mapping(uint256 => BatchTypes.BatchInfo) public batchInfoForId;

    event BatchCreated(uint256 indexed batchId, uint256 indexed actorId, string hash, uint256 timestamp);
    event BatchStatusUpdated(uint256 indexed batchId, BatchTypes.BatchState state, uint256 indexed actorId, string hash, uint256 timestamp);

    /**
    * @dev Sets the ACL and determines the hash AUTHORIZED_CONTRACT_ROLE.
    */
    constructor() Batch("Batch", "B") {}

    /**
    * @dev Creates the batch & updates the on-chain state if the metadata validation succeeds.
    * @param _farmerId - The ID of the farmer who created the batch.
    * @param hash - The hash of the metadata of the batch.
    */
    function createBatch(
        uint256 _farmerId,
        string calldata hash
    )
        internal
    {
        BatchTypes.BatchInfo memory _batch;
        _batch.farmerId = _farmerId;
        
        // Assumption: The Contract creates the batches on behalf of the farmers
        uint256 _batchId = _createBatch(address(this), hash);
        batchInfoForId[_batchId] = _batch;
        if (!performBatchCreation(_batchId)) revert Errors.FulfillmentFailed();
        emit BatchCreated(_batchId, _farmerId, hash, block.timestamp);
    }

    /**
    * @dev Updates the metadata of the batch if the metadata validation succeeds.
    * @param _batch - The new updated batch info itself.
    * @param participant - The Actor participating int the current batch update.
    * @param hash - The hash of the new dynamically updated metadata.
    */
    function updateBatch(
        uint256 _batchId,
        BatchTypes.BatchInfo memory _batch,
        uint256 participant,
        string calldata hash
    )
        internal
    {
        if (!(idExists(_batchId))) revert Errors.InvalidTokenId();
        
        _updateBatch(_batchId, hash);
        batchInfoForId[_batchId] = _batch;
        if (!performBatchUpdate(_batchId)) revert Errors.FulfillmentFailed();
        emit BatchStatusUpdated(_batchId, _batch.state, participant, hash, block.timestamp);
    }

    /**
    * @dev To retrieve the batch URI.
    * @param batchId - The ID of the batch.
    * @return The hash of the batch.
    */
    function getBatchURI(uint256 batchId)
        public
        view
        returns(string memory)
    {
        return tokenURI(batchId);
    }

    /**
    * @dev To retrieve the batch URIs in a chunk, chunk size cannot exceed 100.
    * @param cursor - The starting index or the first BatchID.
    * @param pageSize - Total request size.
    * @return The hashes of the batches.
    */
    function getBatchURIsInBatch(uint256 cursor, uint256 pageSize)
        public
        view
        returns (string[] memory)
    {
        if (!(pageSize < 101)) revert Errors.OutOfBounds(pageSize, 100);
        uint256 totalSupply = totalSupply();
        if (!(cursor < totalSupply)) revert Errors.OutOfBounds(cursor, totalSupply);

        uint256 endIndex = cursor + pageSize;
        if (endIndex > totalSupply) endIndex = totalSupply;

        uint256 actualPageSize = endIndex - cursor;
        string[] memory batchURIs = new string[](actualPageSize);
        for (uint256 i = 0; i < actualPageSize; i++) {
            batchURIs[i] = tokenURI(cursor + i);
        }
        return batchURIs;
    }

    /**
    * @dev To get the actors involved in a particular batch, a read-only external function.
    */
    function getUpdatedBatchActors(uint256 _batchId)
        public
        view
        returns (
            BatchTypes.BatchState,
            uint256,
            uint256,
            uint256,
            uint256[] memory,
            uint256[] memory
        )
    {
        BatchTypes.BatchInfo storage batch = batchInfoForId[_batchId];
        return (
            batch.state,
            batch.farmerId,
            batch.processorId,
            batch.packagerId,
            distributorsIdsForBatchId[_batchId].values(),
            retailersIdsForBatchId[_batchId].values()
        );
    }
    
    function performBatchCreation(uint256 _batchId) internal virtual returns(bool) {
        // Is called on a successful creation
    }

    function performBatchUpdate(uint256 _batchId) internal virtual returns(bool) {
        // Is called on a successful state update
    }
}
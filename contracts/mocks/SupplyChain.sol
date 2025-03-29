// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Errors } from "./Errors.sol";
import { Actor } from "./Actor.sol";
import { BatchTypes } from "./BatchTypes.sol";
import { BatchManager } from "./BatchManager.sol";
import { AccessManager } from "./AccessManager.sol";
import { BatchValidationMiddleware as Validate } from "./BatchValidationMiddleware.sol";

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
* @title The Core DNFT based SupplyChain.
* @custom:security-contact @captainunknown7@gmail.com
*/
contract SupplyChain is BatchManager {
    using EnumerableSet for EnumerableSet.UintSet;
    AccessManager public acl;
    bytes32 immutable COMPANY_USER_ROLE;

    modifier onlyCompanyUser() {
        if (!acl.hasRole(COMPANY_USER_ROLE, msg.sender))
            revert Errors.UnAuthorized("COMPANY_USER_ROLE");
        _;
    }

    struct BatchIdsForActors {
        EnumerableSet.UintSet batchIds;
    }

    struct IdsForDistributors {
        EnumerableSet.UintSet batchIds;
    }

    struct IdsForRetailers {
        EnumerableSet.UintSet batchIds;
    }

    mapping(uint256 => BatchIdsForActors) private farmers;
    mapping(uint256 => BatchIdsForActors) private processors;
    mapping(uint256 => BatchIdsForActors) private packagers;
    mapping(uint256 => IdsForDistributors) private distributors;
    mapping(uint256 => IdsForRetailers) private retailers;

    /**
    * @dev Sets the ACL and determines the hash AUTHORIZED_CONTRACT_ROLE.
    * And handles the deployment of the `BatchManager` contract.
    */
    constructor(address aclAddress) BatchManager()
    {
        acl = AccessManager(aclAddress);
        COMPANY_USER_ROLE = acl.COMPANY_USER_ROLE();
    }

    /**
    * @dev To add a newly harvested batch. Creates a new instance of the batch & validates the metadata.
    * @param farmerId - Farmer ID of the Harvester of the batch.
    * @param hash - The hash of the harvested batch.
    */
    function addHarvestedBatch(uint256 farmerId, string calldata hash) public onlyCompanyUser {
        createBatch(farmerId, hash);
    }

    /**
    * @dev To push the harvested batch to the processed state. Requires onchain state & metadata validation.
    * @param batchId - BatchID of the batch to be processed.
    * @param processorId - The actor ID of the processor involved.
    * @param hash - Updated hash of the processed batch.
    */
    function pushBatchToProcessed(
        uint256 batchId,
        uint256 processorId,
        string calldata hash
    ) public onlyCompanyUser {
        BatchTypes.BatchInfo storage batchInfo = batchInfoForId[batchId];
        Validate.validateChronologicalOrder(batchInfo.state, BatchTypes.BatchState.Processed);
        batchInfo.state = BatchTypes.BatchState.Processed;
        batchInfo.processorId = processorId;
        updateBatch(batchId, batchInfo, processorId, hash);
    }

    /**
    * @dev To push the processed batch to the packaged state. Requires onchain state & metadata validation.
    * @param batchId - BatchID of the batch to be packaged.
    * @param packagerId - The actor ID of the packager involved.
    * @param hash - Updated hash of the packaged batch.
    */
    function pushBatchToPackaged(
        uint256 batchId,
        uint256 packagerId,
        string calldata hash
    ) public onlyCompanyUser {
        BatchTypes.BatchInfo storage batchInfo = batchInfoForId[batchId];
        Validate.validateChronologicalOrder(batchInfo.state, BatchTypes.BatchState.Packaged);
        batchInfo.state = BatchTypes.BatchState.Packaged;
        batchInfo.packagerId = packagerId;
        updateBatch(batchId, batchInfo, packagerId, hash);
    }

    /**
    * @dev To assign a packaged batch to a distributor. Requires onchain state & metadata validation.
    * @param batchId - BatchID of the batch to be distributed.
    * @param distributorId - The actor ID of the distributor involved.
    * @param hash - Updated hash of the distributed batch.
    */
    function assignBatchToDistributor(
        uint256 batchId,
        uint256 distributorId,
        string calldata hash
    ) public onlyCompanyUser {
        BatchTypes.BatchInfo storage batchInfo = batchInfoForId[batchId];
        Validate.validateChronologicalOrder(batchInfo.state, BatchTypes.BatchState.AtDistributors);
        batchInfo.state = BatchTypes.BatchState.AtDistributors;
        distributorsIdsForBatchId[batchId].add(distributorId);
        updateBatch(batchId, batchInfo, distributorId, hash);
    }

    /**
    * @dev To assign a distributed batch to a retailer. Requires onchain state & metadata validation.
    * @param batchId - BatchID of the batch to be retailed.
    * @param retailerId - The actor ID of the retailer involved.
    * @param hash - Updated hash of the retailed batch.
    */
    function assignBatchToRetailer(
        uint256 batchId,
        uint256 retailerId,
        string calldata hash
    ) public onlyCompanyUser {
        BatchTypes.BatchInfo storage batchInfo = batchInfoForId[batchId];
        Validate.validateChronologicalOrder(batchInfo.state, BatchTypes.BatchState.AtRetailers);
        batchInfo.state = BatchTypes.BatchState.AtRetailers;
        retailersIdsForBatchId[batchId].add(retailerId);
        updateBatch(batchId, batchInfo, retailerId, hash);
    }

    /**
    * @dev To retrieve all the batches of a particular farmer.
    * @param farmerId - The farmer ID to retrieve the batches for.
    * @return The IDs of the batches the farmer harvested.
    */
    function getBatchesHarvested(uint256 farmerId) public view returns (uint256[] memory) {
        return farmers[farmerId].batchIds.values();
    }

    /**
    * @dev To retrieve all the batches of a particular processor.
    * @param processorId - The processor ID to retrieve the batches for.
    * @return The IDs of the batches the processor ever processed.
    */
    function getBatchesProcessed(uint256 processorId) public view returns (uint256[] memory) {
        return processors[processorId].batchIds.values();
    }

    /**
    * @dev To retrieve all the batches of a particular packager.
    * @param packagerId - The packager ID to retrieve the batches for.
    * @return The IDs of the batches the packager ever packaged.
    */
    function getBatchesPackaged(uint256 packagerId) public view returns (uint256[] memory) {
        return packagers[packagerId].batchIds.values();
    }

    /**
    * @dev To retrieve all the batches of a particular distributor.
    * @param distributorId - The distributor ID to retrieve the batches for.
    * @return The IDs of the batches the distributor was involved in.
    */
    function getBatchesDistributed(uint256 distributorId) public view returns (uint256[] memory) {
        return distributors[distributorId].batchIds.values();
    }

    /**
    * @dev To retrieve all the batches of a particular retailer.
    * @param retailerId - The retailer ID to retrieve the batches for.
    * @return The IDs of the batches the retailer was involved in.
    */
    function getBatchesRetailed(uint256 retailerId) public view returns (uint256[] memory) {
        return retailers[retailerId].batchIds.values();
    }

    /**
    * @dev To retrieve all the distributors involved in a batch.
    * @param batchId - The batch ID to query for.
    * @return The Distributors IDs that were involved in the batch.
    */
    function getAllDistributorsForBatch(uint256 batchId)
        public view returns (uint256[] memory)
    {
        return distributorsIdsForBatchId[batchId].values();
    }

    /**
    * @dev To retrieve all the retailers involved in a batch.
    * @param batchId - The batch ID to query for.
    * @return The Retailers IDs that were involved in the batch.
    */
    function getAllRetailersForBatch(uint256 batchId)
        public view returns (uint256[] memory)
    {
        return retailersIdsForBatchId[batchId].values();
    }

    // Overrides:
    /**
    * @dev Post fulfillment function to register the batch for the corresponding farmerId on chain.
    */
    function performBatchCreation(uint256 _batchId) internal override returns(bool) {
        return farmers[batchInfoForId[_batchId].farmerId].batchIds.add(_batchId);
    }

    /**
    * @dev Post fulfillment function to assign the new actor involved for the said batch on chain.
    */
    function performBatchUpdate(uint256 _batchId) internal override returns(bool) {
        (
            BatchTypes.BatchState state,
            ,
            uint256 processorId,
            uint256 packagerId,
            uint256[] memory distributorIds,
            uint256[] memory retailerIds
        ) = getUpdatedBatchActors(_batchId);

        if (state == BatchTypes.BatchState.Processed) {
            return processors[processorId].batchIds.add(_batchId);
        } else if (state == BatchTypes.BatchState.Packaged) {
            return packagers[packagerId].batchIds.add(_batchId);
        } else if (state == BatchTypes.BatchState.AtDistributors) {
            uint256 distributorAdded = distributorIds[distributorIds.length - 1];
            return distributors[distributorAdded].batchIds.add(_batchId);
        } else if (state == BatchTypes.BatchState.AtRetailers) {
            uint256 retailerAdded = retailerIds[retailerIds.length - 1];
            return retailers[retailerAdded].batchIds.add(_batchId);
        } else return true;
    }

    /**
    * @dev To interface with ERC721 & receive the batch dNFTs.
    */
    function onERC721Received(address, address, uint256, bytes calldata) external view returns(bytes4) {
        if(msg.sender == address(this)) return this.onERC721Received.selector;
        return bytes4(0);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
* @title BatchType Definitions
* @custom:security-contact @captainunknown7@gmail.com
*/
library BatchTypes {
    uint8 public constant BATCH_STATE_COUNT = 9;
    enum BatchState {
        Harvested,
        Processed,
        Packaged,
        AtDistributors,
        AtRetailers,
        ToCustomers,
        InStorage,
        InTransit,
        InProcessing // represents all intermediate stages like packaging, processing, quality checks etc
    }

    struct BatchInfo {
        BatchState state;
        // Actor Ids for the given actors involved in the batch
        uint256 farmerId;
        uint256 processorId;
        uint256 packagerId;
    }
}
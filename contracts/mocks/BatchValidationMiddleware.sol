// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { String } from "./String.sol";
import { BatchTypes } from "./BatchTypes.sol";

/**
* @title Acts as middleware to validate batch data.
* @custom:security-contact @captainunknown7@gmail.com
*/
library BatchValidationMiddleware {
    function validateChronologicalOrder(
        BatchTypes.BatchState oldBatchState,
        BatchTypes.BatchState newBatchState
    ) internal pure returns (bool) {
        if (oldBatchState < newBatchState) return true;
        else if (oldBatchState == BatchTypes.BatchState.AtDistributors && oldBatchState == newBatchState)
            return true;
        else if (oldBatchState == BatchTypes.BatchState.AtRetailers && oldBatchState == newBatchState)
            return true;
            // In case there is no packaging stage
        else if (oldBatchState == BatchTypes.BatchState.Processed && newBatchState == BatchTypes.BatchState.AtDistributors)
            return true;
        return false;
    }
}
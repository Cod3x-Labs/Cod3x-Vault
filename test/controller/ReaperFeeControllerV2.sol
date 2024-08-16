// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import {ReaperFeeController} from "../../src/ReaperFeeController.sol";

contract ReaperFeeControllerV2 is ReaperFeeController {
    function version() external pure returns (string memory) {
        return "v2";
    }
}

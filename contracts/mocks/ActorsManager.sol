// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Actor } from "./Actor.sol";
import { String } from "./String.sol";
import { Errors } from "./Errors.sol";
import { AccessManager } from "./AccessManager.sol";

/**
* @title Actors Manager.
* @dev Aggregates the collections for all actor types & performs the necessary validation.
* @custom:security-contact @captainunknown7@gmail.com
*/
contract ActorsManager {
    AccessManager public acl;
    bytes32 immutable AUTHORIZED_CONTRACT_ROLE;

    modifier onlyAuthorizedContract() {
        if (!acl.hasRole(AUTHORIZED_CONTRACT_ROLE, msg.sender))
            revert Errors.UnAuthorized("AUTHORIZED_CONTRACT_ROLE");
        _;
    }

    uint256 private _nextActorId;
    uint8 public constant ACTOR_TYPE_COUNT = 6;
    enum ActorType {
        Farmer,
        Processor,
        Bottler,
        Distributor,
        Retailer,
        Consumer
    }
    mapping(uint8 => Actor) public actors;

    event ActorRegistered(uint8 indexed actorType, uint256 indexed actorId, address indexed account, string hash);
    event ActorUpdated(uint8 indexed actorType, uint256 indexed actorId, string newHash);

    modifier onlyValidActorType(uint8 actorType) {
        if (!(actorType < ACTOR_TYPE_COUNT)) revert Errors.InvalidActorType(actorType, ACTOR_TYPE_COUNT);
        _;
    }

    /**
    * @dev Sets the ACL and determines the hash AUTHORIZED_CONTRACT_ROLE.
    */
    constructor(address aclAddress) {
        actors[0] = new Actor(aclAddress, "Farmer", "FG");
        actors[1] = new Actor(aclAddress, "Processor", "PR");
        actors[2] = new Actor(aclAddress, "Bottler", "BT");
        actors[3] = new Actor(aclAddress, "Distributor", "DS");
        actors[4] = new Actor(aclAddress, "Retailer", "RT");
        actors[5] = new Actor(aclAddress, "Consumer", "CU");

        acl = AccessManager(aclAddress);
        AUTHORIZED_CONTRACT_ROLE = acl.AUTHORIZED_CONTRACT_ROLE();
    }

    /**
    * @dev Creates the batch & updates the on-chain state if the metadata validation succeeds.
    * @param actorType - The type of the actor to register (Expected: 0-5).
    * @param account - The account to receive the identification NFT.
    * @param hash - The hash of the metadata of the actor.
    */
    function registerActor(uint8 actorType, address account, string calldata hash)
        public
        onlyValidActorType(actorType)
        onlyAuthorizedContract
    {        
        uint256 actorId = actors[actorType].registerActor(account, ++_nextActorId, hash);
        emit ActorRegistered(actorType, actorId, account, hash);
    }

    /**
    * @dev Updates the metadata of the actor if the metadata validation succeeds.
    * @param actorType - The actor type (Expected: 0-5).
    * @param actorId - The actor ID to replace the hash of.
    * @param hash - The hash of the actor.
    */
    function updateActor(uint8 actorType, uint256 actorId, string calldata hash)
        public
        onlyValidActorType(actorType)
        onlyAuthorizedContract
    {
        actors[actorType].updateActor(actorId, hash);
        emit ActorUpdated(actorType, actorId, hash);
    }

    /**
    * @dev To retrieve the actor URI.
    * @param actorType - The type of the actor.
    * @param actorId - The ID of the actor.
    * @return The hash of the batch.
    */
    function getActorURI(uint8 actorType, uint256 actorId)
        public
        view
        onlyValidActorType(actorType)
        returns(string memory)
    {
        return actors[actorType].tokenURI(actorId);
    }
}
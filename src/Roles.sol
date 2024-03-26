// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

/*
 * Reaper Roles in increasing order of privilege.
 * {STRATEGIST} - Role conferred to authors of the strategy, allows for tweaking non-critical params.
 * {GUARDIAN} - Multisig requiring 2 signatures for invoking emergency measures.
 * {ADMIN}- Multisig requiring 3 signatures for deactivating emergency measures and changing TVL cap.
 *
 * The DEFAULT_ADMIN_ROLE (in-built access control role) will be granted to a multisig requiring 4
 * signatures. This role would have the ability to add strategies, as well as the ability to grant any other
 * roles.
 *
 * Also note that roles are cascading. So any higher privileged role should be able to perform all the functions
 * of any lower privileged role.
 */
bytes32 constant KEEPER = keccak256("KEEPER");
bytes32 constant STRATEGIST = keccak256("STRATEGIST");
bytes32 constant GUARDIAN = keccak256("GUARDIAN");
bytes32 constant ADMIN = keccak256("ADMIN");

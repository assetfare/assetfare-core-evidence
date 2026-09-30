// SPDX-License-Identifier: MIT
// Caller-signed, atomic exact-1bp USDC CCTP V2 script for Aptos -> Base/Solana.
script {
    use aptos_framework::error;
    use aptos_framework::fungible_asset::{Self, Metadata};
    use aptos_framework::object::{Self, Object};
    use aptos_framework::primary_fungible_store;
    use stablecoin_handler::handler;
    use std::vector;
    use token_messenger_minter_v2::token_messenger_minter;

    const EINVALID_AMOUNT: u64 = 1;
    const EINVALID_DESTINATION: u64 = 2;
    const EINVALID_RECIPIENT: u64 = 3;
    const EINVALID_FORWARD_HOOK: u64 = 4;
    const EINVALID_CCTP_FEE: u64 = 5;
    const ROUTE_FEE_BPS: u64 = 1;
    const BPS_DENOMINATOR: u64 = 10_000;
    const FINALITY_STANDARD: u32 = 2_000;
    const BASE_DOMAIN: u32 = 6;
    const SOLANA_DOMAIN: u32 = 5;
    const USDC: address = @aptos_usdc;
    const FEE_RECIPIENT: address = @assetfare_fee_recipient;

    fun bridge_usdc(
        caller: &signer,
        amount: u64,
        destination_domain: u32,
        mint_recipient: address,
        max_cctp_fee: u64,
        hook_data: vector<u8>,
    ) {
        let route_fee = amount * ROUTE_FEE_BPS / BPS_DENOMINATOR;
        assert!(route_fee > 0 && route_fee < amount, error::invalid_argument(EINVALID_AMOUNT));
        assert!(destination_domain == BASE_DOMAIN || destination_domain == SOLANA_DOMAIN, error::invalid_argument(EINVALID_DESTINATION));
        assert!(mint_recipient != @0x0, error::invalid_argument(EINVALID_RECIPIENT));

        let length = vector::length(&hook_data);
        if (destination_domain == BASE_DOMAIN) {
            assert!(length == 32, error::invalid_argument(EINVALID_FORWARD_HOOK));
        } else {
            assert!(length == 65, error::invalid_argument(EINVALID_FORWARD_HOOK));
        };
        // ASCII "cctp-forward" followed by zero padding to byte 24.
        assert!(*vector::borrow(&hook_data, 0) == 0x63, error::invalid_argument(EINVALID_FORWARD_HOOK));
        assert!(*vector::borrow(&hook_data, 1) == 0x63, error::invalid_argument(EINVALID_FORWARD_HOOK));
        assert!(*vector::borrow(&hook_data, 2) == 0x74, error::invalid_argument(EINVALID_FORWARD_HOOK));
        assert!(*vector::borrow(&hook_data, 3) == 0x70, error::invalid_argument(EINVALID_FORWARD_HOOK));
        assert!(*vector::borrow(&hook_data, 4) == 0x2d, error::invalid_argument(EINVALID_FORWARD_HOOK));
        assert!(*vector::borrow(&hook_data, 5) == 0x66, error::invalid_argument(EINVALID_FORWARD_HOOK));
        assert!(*vector::borrow(&hook_data, 6) == 0x6f, error::invalid_argument(EINVALID_FORWARD_HOOK));
        assert!(*vector::borrow(&hook_data, 7) == 0x72, error::invalid_argument(EINVALID_FORWARD_HOOK));
        assert!(*vector::borrow(&hook_data, 8) == 0x77, error::invalid_argument(EINVALID_FORWARD_HOOK));
        assert!(*vector::borrow(&hook_data, 9) == 0x61, error::invalid_argument(EINVALID_FORWARD_HOOK));
        assert!(*vector::borrow(&hook_data, 10) == 0x72, error::invalid_argument(EINVALID_FORWARD_HOOK));
        assert!(*vector::borrow(&hook_data, 11) == 0x64, error::invalid_argument(EINVALID_FORWARD_HOOK));
        let index = 12;
        while (index < 24) {
            assert!(*vector::borrow(&hook_data, index) == 0, error::invalid_argument(EINVALID_FORWARD_HOOK));
            index = index + 1;
        };
        if (destination_domain == BASE_DOMAIN) {
            while (index < 32) {
                assert!(*vector::borrow(&hook_data, index) == 0, error::invalid_argument(EINVALID_FORWARD_HOOK));
                index = index + 1;
            };
        } else {
            // version=0, additional-data length=33, first additional byte=1.
            while (index < 31) {
                assert!(*vector::borrow(&hook_data, index) == 0, error::invalid_argument(EINVALID_FORWARD_HOOK));
                index = index + 1;
            };
            assert!(*vector::borrow(&hook_data, 31) == 33, error::invalid_argument(EINVALID_FORWARD_HOOK));
            assert!(*vector::borrow(&hook_data, 32) == 1, error::invalid_argument(EINVALID_FORWARD_HOOK));
        };

        let burn_amount = amount - route_fee;
        assert!(max_cctp_fee < burn_amount && max_cctp_fee <= burn_amount / 100, error::invalid_argument(EINVALID_CCTP_FEE));

        let token: Object<Metadata> = object::address_to_object(USDC);
        let asset = primary_fungible_store::withdraw(caller, token, amount);
        let fee_asset = fungible_asset::extract(&mut asset, route_fee);
        primary_fungible_store::deposit(FEE_RECIPIENT, fee_asset);

        let (burn_receipt, asset) = token_messenger_minter::deposit_for_burn(
            caller,
            asset,
            destination_domain,
            mint_recipient,
            @0x0,
            max_cctp_fee,
            FINALITY_STANDARD,
            hook_data,
        );
        handler::burn(burn_receipt, asset);
    }
}

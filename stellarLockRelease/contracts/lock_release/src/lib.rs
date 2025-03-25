#![no_std]

use soroban_sdk::{
    contract, contractimpl, contracttype, token, xdr::ScErrorCode, xdr::ScErrorType, Address,
    Bytes, Env, Error, String,
};

/// LockAndReleaseContract
///
/// ### Trust Assumptions:
/// - The contract owner is trusted to set the initial admin address once.
/// - The admin has full control over releasing funds on the destination chain.
///   Admin should be considered **fully trusted**, and should ideally be secured using
///   a multisig, hardware wallet, or MPC-based scheme.
/// - The contract assumes the user provides a valid recipient address for the destination chain.
/// - The contract does not validate destination chain or recipient address formats.
/// - No decentralized verification of destination transfers is enforced — assumes off-chain bridge layer.

#[derive(Clone)]
#[contracttype]
pub enum DataKey {
    Init,
    Owner,
    AdminSet,
    Admin,
    LockData(Address), // Stores LockData per user
}

#[derive(Clone)]
#[contracttype]
pub struct LockData {
    pub user_address: Address,
    pub dest_token: String,
    pub from_token: Address,
    pub in_amount: i128,
    pub swaped_amount: i128,
    pub recipient_address: String,
    pub dest_chain: Bytes,
}

#[derive(Clone)]
#[contracttype]
pub struct AdminData {
    pub admin_address: Address,
}

#[contract]
pub struct LockAndReleaseContract;

#[contractimpl]
impl LockAndReleaseContract {
    pub fn initialize(env: Env, owner: Address) {
        // Prevent re-initialization
        if env.storage().instance().has(&DataKey::Init) {
            env.panic_with_error(Error::from_type_and_code(
                ScErrorType::Contract,
                ScErrorCode::ExistingValue,
            ));
        }

        // Authenticate the caller as the owner
        owner.require_auth();

        // Set the contract owner and mark as initialized
        env.storage().instance().set(&DataKey::Owner, &owner);
        env.storage().instance().set(&DataKey::Init, &());
    }

    pub fn set_admin(env: Env, admin: Address) {
        // Ensure this is a one-time action
        if env.storage().instance().has(&DataKey::AdminSet) {
            env.panic_with_error(Error::from_type_and_code(
                ScErrorType::Contract,
                ScErrorCode::InvalidAction,
            ));
        }

        // Only the owner can set the admin
        let owner: Address = env.storage().instance().get(&DataKey::Owner).unwrap();
        owner.require_auth();

        // Set admin and mark as set
        env.storage().instance().set(&DataKey::Admin, &AdminData {
            admin_address: admin.clone(),
        });
        env.storage().instance().set(&DataKey::AdminSet, &());

        // Emit event for transparency
        let topics = ("AdminSetEvent", admin);
        env.events().publish(topics, 1);
    }

    pub fn lock(
        env: Env,
        user_address: Address,
        from_token: Address,
        dest_token: String,
        in_amount: i128,
        dest_chain: Bytes,
        recipient_address: String,
    ) {
        // Authenticate user
        user_address.require_auth();

        // Ensure admin is configured
        if !env.storage().instance().has(&DataKey::Admin) {
            env.panic_with_error(Error::from_type_and_code(
                ScErrorType::Contract,
                ScErrorCode::MissingValue,
            ));
        }

        // Validate amount
        if in_amount < 1 {
            env.panic_with_error(Error::from_type_and_code(
                ScErrorType::Contract,
                ScErrorCode::InvalidAction,
            ));
        }

        // Calculate swaped amount (3% fee)
        let swaped_amount = in_amount - (in_amount * 3 / 100);
        if swaped_amount < 1 {
            env.panic_with_error(Error::from_type_and_code(
                ScErrorType::Contract,
                ScErrorCode::InvalidAction,
            ));
        }

        // Transfer input tokens to the contract
        token::Client::new(&env, &from_token)
            .transfer(&user_address, &env.current_contract_address(), &in_amount);

        // Fetch admin and transfer swaped amount to them
        let admin_data: AdminData = env.storage().instance().get(&DataKey::Admin).unwrap();
        let admin_address = admin_data.admin_address;

        token::Client::new(&env, &from_token)
            .transfer(&env.current_contract_address(), &admin_address, &swaped_amount);

        // Emit lock event
        let topics = (
            "LockEvent",
            user_address.clone(),
            dest_token.clone(),
            in_amount,
            swaped_amount,
            recipient_address.clone(),
            dest_chain.clone(),
            from_token.clone(),
        );
        env.events().publish(topics, 1);

        // Store lock data specific to user (prevents overwriting and DoS risk)
        env.storage().instance().set(
            &DataKey::LockData(user_address.clone()),
            &LockData {
                user_address,
                dest_token,
                from_token,
                in_amount,
                swaped_amount,
                recipient_address,
                dest_chain,
            },
        );
    }

    pub fn release(env: Env, amount: i128, user: Address, destination_token: Address) {
        // Retrieve admin and authenticate
        let admin_data: AdminData = env.storage().instance().get(&DataKey::Admin).unwrap();
        let admin = admin_data.admin_address;
        admin.require_auth();

        // Check admin's balance
        let admin_balance = token::Client::new(&env, &destination_token).balance(&admin);
        if admin_balance < amount {
            env.panic_with_error(Error::from_type_and_code(
                ScErrorType::Contract,
                ScErrorCode::InvalidAction,
            ));
        }

        // Perform token release to the user
        token::Client::new(&env, &destination_token).transfer(&admin, &user, &amount);
    }
}

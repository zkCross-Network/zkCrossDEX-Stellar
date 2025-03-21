#![no_std]

use soroban_sdk::{
    contract, contractimpl, contracttype, token, xdr::ScErrorCode, xdr::ScErrorType, Address,
    Bytes, Env, Error, String,
};

#[derive(Clone)]
#[contracttype]
pub enum DataKey {
    Init,
    Owner,
    AdminSet,
    Admin,
    LockData,
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
        // Ensure the contract has not been initialized before
        if env.storage().instance().has(&DataKey::Init) {
            env.panic_with_error(Error::from_type_and_code(
                ScErrorType::Contract,
                ScErrorCode::ExistingValue,
            ));
        }
        // Set the contract owner
        env.storage().instance().set(&DataKey::Owner, &owner);
        // Mark the contract as initialized
        env.storage().instance().set(&DataKey::Init, &());
    }

    pub fn set_admin(env: Env, admin: Address) {
        // Ensure that the function is called only once after initialization
        if env.storage().instance().has(&DataKey::AdminSet) {
            env.panic_with_error(Error::from_type_and_code(
                ScErrorType::Contract,
                ScErrorCode::InvalidAction,
            ));
        }

        // Only the owner can set the admin address
        let owner: Address = env.storage().instance().get(&DataKey::Owner).unwrap();
        owner.require_auth();

        // Store the admin address in the AdminData struct
        env.storage().instance().set(
            &DataKey::Admin,
            &AdminData {
                admin_address: admin.clone(),
            },
        );

        // Mark that the admin has been set, so it can't be changed again
        env.storage().instance().set(&DataKey::AdminSet, &());

        // Optionally emit an event indicating admin setup
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
        // Ensure user has authorized the action
        user_address.require_auth();

        // Ensure the admin address is set
        if !env.storage().instance().has(&DataKey::Admin) {
            env.panic_with_error(Error::from_type_and_code(
                ScErrorType::Contract,
                ScErrorCode::MissingValue,
            ));
        }

        // Ensure in_amount is greater than or equal to 1
        if in_amount < 1 {
            env.panic_with_error(Error::from_type_and_code(
                ScErrorType::Contract,
                ScErrorCode::InvalidAction,
            ));
        }

        // Calculate swaped_amount using the provided formula: swaped_amount = in_amount * 0.7
        let swaped_amount = in_amount - (in_amount * 3 / 100);

        // Ensure swaped_amount is at least 1
        if swaped_amount < 1 {
            env.panic_with_error(Error::from_type_and_code(
                ScErrorType::Contract,
                ScErrorCode::InvalidAction,
            ));
        }

        // Transfer in_amount from user to contract address
        token::Client::new(&env, &from_token).transfer(&user_address, &env.current_contract_address(), &in_amount);

        // Fetch admin address securely from AdminData
        let admin_data: AdminData = env.storage().instance().get(&DataKey::Admin).unwrap();
        let admin_address = admin_data.admin_address;

        // Transfer swaped_amount from contract to admin address
        token::Client::new(&env, &from_token).transfer(&env.current_contract_address(), &admin_address, &swaped_amount);

        // Emit lock event
        let topics0 = (
            "LockEvent",
            user_address.clone(),
            dest_token.clone(),
            in_amount,
            swaped_amount,
            recipient_address.clone(),
            dest_chain.clone(),
            from_token.clone(),
        );

        env.events().publish(topics0, 1);

        // Store lock data
        env.storage().instance().set(
            &DataKey::LockData,
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
        // Retrieve the admin address from storage.
        let admin_data: AdminData = env.storage().instance().get(&DataKey::Admin).unwrap();
        let admin = admin_data.admin_address;

        // Ensure that only the admin can call this function.
        admin.require_auth();

        // Verify the balance of the admin.
        let admin_balance = token::Client::new(&env, &destination_token).balance(&admin);
        if admin_balance < amount {
            env.panic_with_error(Error::from_type_and_code(
                ScErrorType::Contract,
                ScErrorCode::InvalidAction,
            ));
        }

        // Transfer tokens from the admin to the user.
        token::Client::new(&env, &destination_token).transfer(&admin, &user, &amount);
    }
}
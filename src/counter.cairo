#[starknet::interface]
pub trait ICounter<T>{
    fn get_counter(self: @T) -> u32;
    fn increase_counter(ref self: T);
}

#[starknet::interface]
pub trait IKillSwitch<T> {
    fn is_active(self: @T) -> bool;
}

#[starknet::contract]
pub mod counter_contract {
    use workshop::counter::ICounter;
    use starknet::ContractAddress;
    use super::{IKillSwitchDispatcher, IKillSwitchDispatcherTrait}; // Import from parent module
    use openzeppelin::access::ownable::{OwnableComponent};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        counter: u32,
        kill_switch: ContractAddress, // Store the KillSwitch contract address
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[constructor]
    fn constructor(ref self: ContractState, initial_value: u32, kill_switch: ContractAddress, initial_owner: ContractAddress) {
        // Initialize the counter
        self.counter.write(initial_value);
        // Initialize the kill_switch with the provided contract address
        self.kill_switch.write(kill_switch);
        // Call the initializer function of the Ownable component to set the initial owner
        self.ownable.initializer(initial_owner);
    }

    #[event]
    #[derive(Drop, starknet::Event)] //Atttribute to destroy the resources
    enum Event {
        CounterIncreased: CounterIncreased,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    struct CounterIncreased {
        value: u32,
    }

    #[abi(embed_v0)] //attribute to expose the ABI
    impl CounterImpl of ICounter<ContractState>{
        fn get_counter(self: @ContractState) -> u32{
            let value = self.counter.read();
            return value;
            //another option is to use self.counter.read()
        } 

        fn increase_counter(ref self: ContractState) {
            // Ensure that only the owner can call this function
            self.ownable.assert_only_owner();
            
            // Read the KillSwitch contract address from storage
            let kill_switch = self.kill_switch.read();

           // Create the dispatcher for the KillSwitch contract
           let kill_switch_dispatcher = IKillSwitchDispatcher { contract_address: kill_switch };

            // Call the `is_active` function on the KillSwitch contract
            let is_active = kill_switch_dispatcher.is_active();

            // Assert that the KillSwitch is not active; revert if it is active
            assert!(!is_active, "Kill Switch is active");

            // If kill switch is not active, proceed with incrementing the counter
            let value = self.get_counter();
            self.counter.write(value + 1);
            //another option isself.counter.write(self.get_counter() + 1);

            self.emit( CounterIncreased {value: self.counter.read()});
            //another option self.emit( CounterIncreased {value: self.get_counter()});
        }
    }
}
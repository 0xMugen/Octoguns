use starknet::ContractAddress;
use octoguns::types::Vec2;

#[derive(Drop, Serde)]
#[dojo::model]
pub struct CharacterModel {
    #[key]
    pub entity_id: u32,
    pub session_id: u32,
    pub player_id: ContractAddress,
    pub steps_amount: u32, // The amount of acion s this character can submit
}

#[generate_trait]
impl CharacterModelImpl of CharacterModelTrait {
    fn new(id: u32, session_id: u32, player_id: ContractAddress, steps_amount: u32) -> CharacterModel {
        CharacterModel {entity_id: id, session_id, player_id, steps_amount}
    }
}

// 10 000 x 10 000 map (high level position)
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct CharacterPosition {
    #[key]
    pub id: u32,
    pub coords: Vec2,
}

#[generate_trait]
impl CharacterPositionImpl of CharacterPositionTrait {
    fn new(id: u32, coords: Vec2) -> CharacterPosition {
        CharacterPosition {id, coords}
    }
}

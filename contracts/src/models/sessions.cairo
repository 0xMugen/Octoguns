use starknet::{ContractAddress, contract_address_const};

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct Session {
    #[key]
    pub session_id: u32,
    pub player1: ContractAddress,
    pub player2: ContractAddress,
    pub map_id: u32,
    pub state: u8, // 0: waiting for seconde player. 1 waiting for spawn, 2 in game, 3 ended.

}

#[generate_trait]
impl SessionImpl of SessionTrait {
    fn new(session_id: u32, player1: ContractAddress, map_id: u32) -> Session {
        Session {
            session_id, 
            player1, 
            player2: contract_address_const::<0x0>(), 
            map_id, 
            state:0
        }
    }
    fn join(ref self: Session, player2: ContractAddress) {
        self.player2 = player2;
        self.state = 1;
    }
    
}

#[derive(Drop, Serde)]
#[dojo::model]
pub struct SessionMeta {
    #[key]
    pub session_id: u32,
    pub turn_count: u32, // mod 2 = 1 is player 2 and mod 2 = 0 is player 1
    pub p1_character: u32,
    pub p2_character: u32 ,
    pub bullets: Array<u32>

}

#[generate_trait]
impl SessionMetaImpl of SessionMetaTrait {
    fn new(session_id: u32) -> SessionMeta {
        SessionMeta {
            session_id, 
            turn_count: 0, 
            bullets: ArrayTrait::new(), 
            p1_character: 0,
            p2_character: 0
        }
    }
    fn next_turn(ref self: SessionMeta) {
        self.turn_count += 1;
    }
    fn add_bullet(ref self: SessionMeta, bullet_id: u32) {
        self.bullets.append(bullet_id);
    }
    fn set_new_bullets(ref self: SessionMeta, bullets: Array<u32>) {
        self.bullets = bullets;
    }
}
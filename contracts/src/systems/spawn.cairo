#[dojo::interface]
trait ISpawn {
    fn spawn(ref world: IWorldDispatcher, session_id: u32);
}

#[dojo::contract]
mod spawn {
    use super::ISpawn;
    use octoguns::models::sessions::{Session, SessionMeta, SessionMetaTrait};
    use octoguns::models::characters::{CharacterModel,CharacterModelTrait,
                                      CharacterPosition,CharacterPositionTrait, 
                                      };
    use octoguns::models::quadtree::{Quadtree, QuadtreeTrait};
    use octoguns::models::map::{Map, MapTrait};
    use octoguns::types::Vec2;
    use octoguns::lib::default_spawns::{generate_character_positions};
    use starknet::{ContractAddress, get_caller_address};

    #[abi(embed_v0)]
    impl SpawnImpl of ISpawn<ContractState> {
        fn spawn(ref world: IWorldDispatcher, session_id: u32) {
            let position_1 = Vec2 { x: 50000, y: 20000};
            let position_2 = Vec2 { x: 50000, y: 80000};

            let mut session = get!(world, session_id, (Session));
            assert!(session.state == 1, "Not spawnable");
            let caller = get_caller_address();
            let mut session_meta = get!(world, session_id, (SessionMeta));
            assert!(caller == session.player1 || caller == session.player2, "Not player");

            let id1 = world.uuid();

            let default_steps = 10;
            let c1 = CharacterModelTrait::new(id1, session_id, session.player1, default_steps);
            let p1 = CharacterPositionTrait::new(id1, position_1);
            session_meta.p1_character = id1;
                    

            let id2 = world.uuid();
            let c2 = CharacterModelTrait::new(id2, session_id, session.player2, default_steps);
            let p2 = CharacterPositionTrait::new(id2, position_2);
            session_meta.p2_character = id2;                

            let mut positions = array![p1, p2];

            let mut map = get!(world, session.map_id, (Map));
            let quadtree = QuadtreeTrait::new(session.session_id, positions, ref map);

            session.state = 2;
            set!(world, (session, session_meta, c1, p1, c2, p2, quadtree));
        }
    }
}
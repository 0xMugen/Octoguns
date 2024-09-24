use octoguns::types::{TurnMove};
use octoguns::models::bullet::{Bullet, BulletTrait};

#[dojo::interface]
trait IActions {
    fn move(ref world: IWorldDispatcher, session_id: u32, moves: TurnMove);
}

#[dojo::contract]
mod actions {
    use super::IActions;
    use octoguns::types::{Vec2, IVec2, Shot, TurnMove};
    use octoguns::models::sessions::{Session, SessionMeta, SessionMetaTrait};
    use octoguns::models::characters::{CharacterModel, CharacterPosition, CharacterPositionTrait};
    use octoguns::models::bullet::{Bullet, BulletTrait};
    use octoguns::models::map::{Map, MapTrait};
    use octoguns::models::turndata::{TurnData};
    use octoguns::lib::helpers::{get_all_bullets, filter_out_dead_characters, check_is_valid_move};
    use octoguns::lib::simulate::{simulate_bullets};
    use starknet::{ContractAddress, get_caller_address};
    use core::cmp::{max, min};
    use octoguns::models::quadtree::{Quadtree, QuadtreeTrait};
    use octoguns::models::quadtree::{Collider, ColliderType};


    #[abi(embed_v0)]
    impl ActionsImpl of IActions<ContractState> {
        fn move(ref world: IWorldDispatcher, session_id: u32, mut moves: TurnMove) {
            assert!(moves.sub_moves.len() <= 100, "Invalid number of moves");
            assert!(moves.shots.len() <= 3, "Invalid number of shots");
            let player = get_caller_address();
            let mut session = get!(world, session_id, (Session));
            assert!(session.state != 1, "Game doesn't exist");
            assert!(session.state != 3, "Game over");
            assert!(session.state == 2, "Game not active");

            let map = get!(world, session_id, (Map));

            let mut session_meta = get!(world, session_id, (SessionMeta));

            let mut updated_bullet_ids = array![];

            let mut player_character_id = 0;
            let mut opp_character_id = 0;
            let mut opp_player = 0;

            match session_meta.turn_count % 2 {
                0 => {
                    assert!(player == session.player1, "not turn player, 1s turn");
                    player_character_id = session_meta.p1_character;
                    opp_character_id = session_meta.p2_character;
                    opp_player = 1;
                },
                1 => {
                    assert!(player == session.player2, "not turn player, 2s turn");
                    player_character_id = session_meta.p2_character;
                    opp_character_id = session_meta.p1_character;
                    opp_player = 2;
                },
                _ => {
                    panic!("???");
                }
            }

            let mut player_position = get!(world, player_character_id, (CharacterPosition));
            let mut opp_position = get!(world, opp_character_id, (CharacterPosition));
            let mut positions = array![player_position, opp_position];
            let mut player_quadtree = get!(world, (session_id, player), (Quadtree));
            let mut opp_quadtree = get!(world, (session_id, opp_player), (Quadtree));

            let mut bullets = get_all_bullets(world, session_id);
            
            //start out of bounds so never reached in loop if no shots
            let mut next_shot = 101;
            if moves.shots.len() > 0 {
                next_shot = (*moves.shots.at(0)).step;
            }

            let mut sub_move_index = 0;

            while sub_move_index < 100 {

                if sub_move_index == next_shot.into() {
                    let step = 100 * session_meta.turn_count + sub_move_index;

                    let shot = moves.shots.pop_front();
                    match shot {
                        Option::Some(s) => {
                            let bullet = BulletTrait::new(
                                                world.uuid(), 
                                                Vec2 {x: player_position.coords.x, y: player_position.coords.y}, 
                                                s.angle, 
                                                player_character_id,
                                                step.try_into().unwrap()
                            );
                            bullets.append(bullet);
                            println!("new bullet at index {}", sub_move_index);
                            set!(world, (bullet));
                            if moves.shots.len() > 0 {
                                next_shot = *moves.shots.at(0).step;
                            }
                        },
                        Option::None => {
                            //shouldn't reach
                        }

                    }
                }

                //advance bullets + check collisions
                let (new_bullets, dead_characters) = simulate_bullets(ref bullets, world, ref opp_quadtree, session_meta.turn_count * 100 + sub_move_index);
                updated_bullet_ids = new_bullets;

                let (new_positions, mut filtered_character_ids) = filter_out_dead_characters(ref positions, dead_characters);
                positions = new_positions;

                //get next sub_move
                if filtered_character_ids.len() < 2 {
                    match filtered_character_ids.len() {
                        0 => {
                            //draw
                            break;
                        },
                        1 => {
                            let winner = filtered_character_ids.pop_front().unwrap();
                            if session_meta.p1_character == winner {
                                //p1 wins
                                session.state = 3;
                                session_meta.p2_character = 0;
                            }
                            if session_meta.p2_character == winner {
                                //p2 wins
                                session.state = 3;
                                session_meta.p1_character = 0;
                            }
                            break;
                        },
                        _ => {
                        }
                    }
                }

                

                match moves.sub_moves.pop_front() {
                    Option::Some(mut vec) => {
                        //check move valid 
                        if !check_is_valid_move(vec){
                            vec = IVec2 {x: 0, y: 0, xdir: true, ydir: true};
                        }
                        //apply move
                        if vec.xdir{
                            player_position.coords.x = min(100_000, player_position.coords.x + vec.x.try_into().unwrap()); 
                        }
                        else {
                            vec.x = min( vec.x, player_position.coords.x.into() );
                            player_position.coords.x -= vec.x.try_into().unwrap();
                        }
                        if vec.ydir{
                            player_position.coords.y = min(100_000, player_position.coords.y + vec.y.try_into().unwrap()); 

                        }
                        else {
                            vec.y = min( vec.y, player_position.coords.y.into() );
                            player_position.coords.y -= vec.y.try_into().unwrap();
                        }


                    },
                    Option::None => {
                    }

                }
                positions = array![player_position, opp_position];

                sub_move_index+=1;

                //END MOVE LOOP
            };

            //set new positions
            loop { 
                let next_position = positions.pop_front();
                match next_position {
                    Option::Some(pos) => {
                        println!("setting new positions: x: {} y: {}" , pos.coords.x, pos.coords.y);
                        set!(world, (pos));
                    },
                    Option::None => {
                        break;
                    }
                }
            };

            println!("positions set");

            player_quadtree.remove(player_position.coords, player_character_id);
            player_quadtree.insert(Collider {
                id: player_character_id,
                collider_type: ColliderType::Character(player_character_id),
                position: player_position.coords,
                dimensions: Vec2 {x: 1000, y: 1000}
            });

            session_meta.turn_count += 1;
            session_meta.bullets = updated_bullet_ids;
            

            set!(world, (session, session_meta, player_quadtree));


        }
    }
}


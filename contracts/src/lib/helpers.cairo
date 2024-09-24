use octoguns::types::{TurnMove};
use octoguns::models::characters::{CharacterPosition, CharacterPositionTrait, CharacterModel};
use octoguns::models::bullet::{Bullet};
use octoguns::models::sessions::{SessionMeta};
use octoguns::types::IVec2;
use starknet::{ContractAddress, get_caller_address};
use dojo::world::IWorldDispatcher;
use octoguns::consts::MOVE_SPEED;

fn get_all_bullets(world: IWorldDispatcher, session_id: u32) -> Array<Bullet> {
    let mut all_live_bullets: Array<Bullet> = ArrayTrait::new();
    let session_meta = get!(world, session_id, (SessionMeta));
    let bullets = session_meta.bullets; //  type: array<u32>

    let mut i = 0;
    if bullets.len() == 0 {
        return all_live_bullets;
    }

    while i < bullets.len() {
        let bullet_id = *bullets.at(i);
        let bullet = get!(world, bullet_id, (Bullet));

        all_live_bullets.append(bullet);
        i += 1;
    };

    return all_live_bullets;
}

#[inline]
fn filter_out_dead_characters(
    ref all_character_positions: Array<CharacterPosition>, dead_characters: Array<u32>
) -> (Array<CharacterPosition>, Array<u32>) {
    let mut filtered_positions: Array<CharacterPosition> = ArrayTrait::new();
    let mut filtered_ids: Array<u32> = ArrayTrait::new();

    let mut all_ids = ArrayTrait::new();
    let mut i = 0;
    while i < all_character_positions.len() {
        all_ids.append((*all_character_positions.at(i)).id);
        i += 1;
    };

    if dead_characters.len() == 0 {
        return (all_character_positions.clone(), all_ids);
    }

    loop {
        let character = all_character_positions.pop_front();
        match character {
            Option::Some(character) => {
                let mut is_dead = false;
                let mut j = 0;
                while j < dead_characters.len() {
                    if character.id == *dead_characters.at(j) {
                        println!("character {} is dead", character.id);
                        is_dead = true;
                        break;
                    }
                    j += 1;
                };
                if !is_dead {
                    filtered_positions.append(character);
                    filtered_ids.append(character.id);
                }
            },
            Option::None => { break; }
        }
    };
    return (filtered_positions, filtered_ids);
}


fn check_is_valid_move(v:IVec2) -> bool {
    if (v.x*v.x) + (v.y*v.y) <= MOVE_SPEED*MOVE_SPEED {
        return true;
    }
    else {
        println!("invalid move");
        return false;
    }
}


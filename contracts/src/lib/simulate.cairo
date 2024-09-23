use octoguns::models::bullet::{Bullet, BulletTrait};
use octoguns::types::{Vec2};
use octoguns::models::characters::{CharacterPosition, CharacterPositionTrait};
use alexandria_math::trigonometry::{fast_cos, fast_sin};
use octoguns::consts::ONE_E_8;
use octoguns::models::map::{Map, MapTrait};
use octoguns::models::quadtree::{Quadtree, QuadtreeTrait};
use dojo::world::IWorldDispatcher;

// Tuple to hold bullet_ids and character_ids to drop
pub type SimulationResult = (Array<u32>, Array<u32>);

#[inline]
pub fn simulate_bullets(ref bullets: Array<Bullet>, world: IWorldDispatcher, ref quadtree: Quadtree, step: u32) -> SimulationResult {
    let mut updated_bullets = ArrayTrait::new();
    let mut dead_characters_ids = ArrayTrait::new();

    let mut cloned_bullets = bullets.clone();
    
    loop {
        match cloned_bullets.pop_front() {
            Option::Some(mut bullet) => {
                let maybe_position = bullet.get_position(step);
                match maybe_position {
                    Option::Some(v) => {
                        let maybe_collision = quadtree.check_collisions(v, world);
                        match maybe_collision {
                            Option::Some(id) => {
                                dead_characters_ids.append(id);
                            },
                            Option::None => {
                                updated_bullets.append(bullet.bullet_id);
                            }
                        }
                    },
                    Option::None => {
                        continue;
                    }
                }
            },
            Option::None => {break;},
        }
        
    };
    println!("bullets: {}", bullets.len());

    (updated_bullets, dead_characters_ids)
}

#[cfg(test)]
mod simulate_tests {

    use octoguns::models::characters::{CharacterPosition, CharacterPositionTrait};
    use octoguns::models::bullet::{Bullet, BulletTrait};
    use octoguns::models::map::{Map, MapTrait};
    use octoguns::types::{Vec2};
    use octoguns::lib::default_spawns::{generate_character_positions};
    use octoguns::consts::ONE_E_8;
    use super::{simulate_bullets, SimulationResult};

    use octoguns::tests::helpers::{get_test_character_array};

    #[test]
    fn test_4_bullets_sim()  {
        let address = starknet::contract_address_const::<0x0>();

        let map = MapTrait::new_empty(1);

        let bullet_1 = BulletTrait::new(1, Vec2 { x:300, y:0}, 180 * ONE_E_8, 1, 0);
        let bullet_2 = BulletTrait::new(1, Vec2 { x:300, y:555}, 100 * ONE_E_8, 2, 0);
        let bullet_3 = BulletTrait::new(1, Vec2 { x:6, y:1}, 4 * ONE_E_8, 3, 0);
        let bullet_4 = BulletTrait::new(1, Vec2 { x:3, y:0}, 90 * ONE_E_8, 4, 0);

        let mut characters = get_test_character_array();
        
        let mut bullets = array![bullet_1, bullet_2, bullet_3, bullet_4];
        let res = simulate_bullets(ref bullets, ref characters, @map, 1);
    }

    #[test]
    fn test_no_collisions() {
        let address = starknet::contract_address_const::<0x0>();

        let map = MapTrait::new_empty(1);

        let bullet = BulletTrait::new(1, Vec2 { x: 0, y: 0 }, 0, 63, 0);
        let mut bullets = array![bullet];
        let mut characters = array![
            CharacterPositionTrait::new(1, Vec2 { x: 0, y: 75000 }),
            CharacterPositionTrait::new(2, Vec2 { x: 45800, y: 23400 })
        ];

        let (updated_bullets, dead_characters_ids) = simulate_bullets(ref bullets, ref characters, @map, 1);

        assert!(updated_bullets.len() == 1, "Bullet should not be removed");
        assert!(dead_characters_ids.is_empty(), "No characters should be hit");
    }

    #[test]
    fn test_multiple_collisions() {
        let address = starknet::contract_address_const::<0x0>();

        let map = MapTrait::new_empty(1);
        let mut bullets = array![];
        let mut characters = array![

        ];

        let (updated_bullets, dead_characters_ids) = simulate_bullets(ref bullets, ref characters, @map, 1);

    }

    #[test]
    fn test_bullet_out_of_bounds() {
        let address = starknet::contract_address_const::<0x0>();

        let bullet = BulletTrait::new(1, Vec2 { x: 99999, y: 9950 }, 0, 1, 0);
        let map = MapTrait::new_empty(1);
        let mut bullets = array![bullet];
        let mut characters = array![CharacterPositionTrait::new(1, Vec2 { x: 0, y: 0 })];

        let (updated_bullets, dead_characters_ids) = simulate_bullets(ref bullets, ref characters, @map, 1);

        assert!(updated_bullets.is_empty(), "Bullet should be removed when out of bounds");
        assert!(dead_characters_ids.is_empty(), "No characters should be hit");
    }
}
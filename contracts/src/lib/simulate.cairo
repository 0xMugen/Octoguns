use octoguns::models::bullet::{Bullet, BulletTrait};
use octoguns::types::{Vec2};
use octoguns::models::characters::{CharacterPosition, CharacterPositionTrait};
use alexandria_math::trigonometry::{fast_cos, fast_sin};
use octoguns::consts::ONE_E_8;
use octoguns::models::map::{Map, MapTrait};
use octoguns::models::quadtree::{Quadtree, QuadtreeTrait, ColliderType, Collider};
use dojo::world::IWorldDispatcher;

// Tuple to hold bullet_ids and character_ids to drop
pub type SimulationResult = (Array<u32>, Array<u32>);

#[inline]
pub fn simulate_bullets(ref bullets: Array<Bullet>, ref quadtree: Quadtree, step: u32) -> SimulationResult {
    let mut updated_bullets = ArrayTrait::new();
    let mut dead_characters_ids = ArrayTrait::new();

    let mut cloned_bullets = bullets.clone();
    
    loop {
        match cloned_bullets.pop_front() {
            Option::Some(mut bullet) => {
                let maybe_position = bullet.get_position(step);
                match maybe_position {
                    Option::Some(v) => {
                        let maybe_collision = quadtree.check_collisions(v);
                        match maybe_collision {
                            Option::Some(collider) => {
                                match collider.collider_type {
                                    ColliderType::Character(id) => {
                                        dead_characters_ids.append(id);
                                    },
                                    ColliderType::Wall => {
                                        // drop bullet
                                    },
                                    _ => {
                                        // do nothing
                                    }
                                }
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

}
use octoguns::models::characters::{CharacterPosition, CharacterPositionTrait}; 
use octoguns::lib::trig::{fast_cos_unsigned, fast_sin_unsigned};
use octoguns::consts::ONE_E_8;
use starknet::ContractAddress;
use octoguns::consts::{MOVE_SPEED, BULLET_SPEED};
use octoguns::models::map::{Map, MapTrait};
use octoguns::types::{IVec2, Vec2};

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct Bullet {
    #[key]
    pub bullet_id: u32,
    pub shot_step: u16,
    pub shot_by: u32,
    pub shot_at: Vec2,
    pub velocity: IVec2, // store the step velocity
}

#[generate_trait]
impl BulletImpl of BulletTrait {

    fn new(id: u32, coords: Vec2, angle: u64, shot_by: u32, shot_step: u16) -> Bullet {
        //speed is how much it travels per sub step
        //distance travelled per turn is speed * 100
        let (cos, xdir) = fast_cos_unsigned(angle);
        let (sin, ydir) = fast_sin_unsigned(angle);
        let velocity = IVec2 { x: cos * BULLET_SPEED / ONE_E_8, y: sin * BULLET_SPEED / ONE_E_8, xdir, ydir };
        Bullet { bullet_id: id, shot_at: coords, shot_by, shot_step, velocity}
    }

    fn get_position(ref self: Bullet, step: u32) -> Option<Vec2> {
        let mut new_coords = self.shot_at;
        let step_felt: felt252 = step.into();
        let vx: felt252 = self.velocity.x.into();
        let vy: felt252 = self.velocity.y.into();

        let mut x_shift: u64 = (vx * step_felt).try_into().unwrap();
        let mut y_shift: u64 = (vy * step_felt).try_into().unwrap();

        if self.velocity.xdir {
            new_coords.x += x_shift;
            if new_coords.x > 100_000 {
                return Option::None(());
            }
        }
        else {
            if x_shift > self.shot_at.x {
                return Option::None(());
            }
            new_coords.x -= x_shift;
        }
        if self.velocity.ydir {
            new_coords.y += y_shift;
            if new_coords.y > 100_000 {
                return Option::None(());
            }
        }
        else {
            if y_shift > self.shot_at.y {
                return Option::None(());
            }
            new_coords.y -= y_shift;
        }
        Option::Some(new_coords)
        
    }

    fn simulate(ref self: Bullet, characters: @Array<CharacterPosition>, map: @Map, step: u32) -> (Option<u32>, bool) {
        let maybe_position = self.get_position(step);
        let mut position: Vec2 = Vec2 { x: 0, y: 0 };

        match maybe_position {
            Option::None => {
                return (Option::None(()), true);
            },
            Option::Some(p) => {
                position = p;
            }
        }

        let (hit_character, hit_object) = self.compute_hits(position, characters, map);

        match hit_character {
            Option::Some(character_id) => {
                return (Option::Some(character_id), true);
            },
            Option::None => {
                return (Option::None(()), hit_object);
            }
        }

    }

    fn compute_hits(ref self: Bullet, position: Vec2, characters: @Array<CharacterPosition>, map: @Map) -> (Option<u32>, bool) {
        let mut character_index: u32 = 0;
        let mut character_id = 0;
        let OFFSET: u64 = 1000;
        let mut dropped: bool = false;
        
        loop {
            if character_index >= characters.len() {
                break;
            }

            let character = *characters.at(character_index);

            //plus 1000 offset to to avoid underflow
            let lower_bound_x = character.coords.x + OFFSET - 500;
            let upper_bound_x = character.coords.x + OFFSET + 500;
            let lower_bound_y = character.coords.y + OFFSET - 500;
            let upper_bound_y = character.coords.y + OFFSET + 500;

            //plus 1000 offset to to match bounds offset            
            if (position.x + OFFSET > lower_bound_x && position.x + OFFSET < upper_bound_x &&
                position.y + OFFSET > lower_bound_y && position.y + OFFSET < upper_bound_y) {
                    character_id = character.id;
                    dropped = true;
                    break;        
            }

            character_index += 1;
        };

        let x_index = position.x / 4000;
        let y_index = position.y / 4000;
        let index = (x_index + y_index * 25).try_into().unwrap();
        let mut object_index: u32 = 0;
        while object_index.into() < map.map_objects.len() {
            let object = *map.map_objects.at(object_index);
            if object == index {
                dropped = true;
                break;
            }
            object_index += 1;
        };

        //ignore collision with the player that shot the bullet
        //if hit wall then return no id but true for hit_object
        if character_id == 0 || character_id == self.shot_by {
            return (Option::None(()), dropped);
        }

        (Option::Some(character_id), dropped)

}
}


#[cfg(test)]
mod simulate_tests {

    use octoguns::models::characters::{CharacterPosition, CharacterPositionTrait};
    use super::{Bullet, BulletTrait};
    use octoguns::types::{Vec2};
    use octoguns::tests::helpers::{get_test_character_array};
    use octoguns::consts::{BULLET_SPEED, ONE_E_8};
    use octoguns::models::map::{Map, MapTrait};
    use octoguns::types::MapObjects;

    #[test]
    fn test_new_bullet()  {
        let address = starknet::contract_address_const::<0x0>();

        let mut bullet = BulletTrait::new(
            1, 
            Vec2 {x: 0, y: 0}, 
            0, 
            1,
            0
        );
    }


    #[test]
   fn test_bullet_position_y_only()  {
        let address = starknet::contract_address_const::<0x0>();
        let map = MapTrait::new_empty(1);

        let mut bullet = BulletTrait::new(
            1, 
            Vec2 {x: 0, y: 0}, 
            90*ONE_E_8, 
            1,
            0
        );
        let position = bullet.get_position(1).unwrap();
        assert!(position.x == 0, "x should not have changed");
        assert!(position.y.into() == BULLET_SPEED, "y should have changed by speed");
    }

    #[test]
    fn test_bullet_position_x_only()  {
        let address = starknet::contract_address_const::<0x0>();
        let map = MapTrait::new_empty(1);

        let mut bullet = BulletTrait::new(
            1, 
            Vec2 {x: 0, y: 0}, 
            0, 
            1,
            0
        );
        let position = bullet.get_position(1).unwrap();
       
        assert!(position.x.into() == BULLET_SPEED, "x should have changed by speed");
        assert!(position.y == 0, "y should not have changed");

     }


     #[test]
     fn test_collision_with_character() {
        let address = starknet::contract_address_const::<0x0>();
        let map = MapTrait::new_empty(1);
        let mut bullet = BulletTrait::new(
            1, 
            Vec2 {x: 0, y: 0}, 
            0, 
            1,
            0
        );
        let characters = array![CharacterPositionTrait::new(69, Vec2 {x: 14, y: 0})];
        let (hit_character, dropped) = bullet.simulate(@characters, @map, 1);
        match hit_character {
            Option::None => {
                panic!("should return id of hit piece");
            },
            Option::Some(id) => {
                assert!(id == 69, "not returning id of hit piece");
            }
        }
        assert!(dropped, "should return true for hit object");
     }

     #[test]
     fn test_drop_bullet() {
        let address = starknet::contract_address_const::<0x0>();
        let map = MapTrait::new_empty(1);
        let characters = ArrayTrait::new();

        let mut bullet = BulletTrait::new(
            1, 
            Vec2 {x: 0, y: 0}, 
            180 * ONE_E_8, 
            1,
            0
        );
        let (hit_character, dropped) = bullet.simulate(@characters, @map, 1);
        match hit_character {
            Option::Some(character_id) => {
                panic!("bullet should not hit character");
            },
            Option::None => {
                if !dropped {
                    panic!("should return true");
                }
            }
        }
     }

     #[test]
     fn test_collision_with_object() {
        let address = starknet::contract_address_const::<0x0>();
        let map = MapTrait::new(1, MapObjects { objects: array![7]});

        let characters = ArrayTrait::new();
        let mut bullet = BulletTrait::new(
            1, 
            Vec2 { x:30_000, y:0}, 
            0, 
            1,
            0
        );
        let (hit_character, dropped) = bullet.simulate(@characters, @map, 1);
        match hit_character {
            Option::None => {
                if !dropped {
                    panic!("should return true for hit object");
                }
            },
            Option::Some(character_id) => {
                panic!("bullet should hit wall not character");
            }
        }
     }

     #[test]
     fn test_collision_with_object_2() {
        let address = starknet::contract_address_const::<0x0>();
        let map = MapTrait::new(1, MapObjects { objects: array![7]});

        let characters = ArrayTrait::new();
        let mut bullet = BulletTrait::new(
            1, 
            Vec2 { x:27_850, y:0}, 
            0, 
            1,
            0
        );
        let (hit_character, dropped) = bullet.simulate(@characters, @map, 1);
        match hit_character {
            Option::None => {
                if !dropped {
                    panic!("should return true for hit object");
                }
            },
            Option::Some(character_id) => {
                panic!("bullet should hit wall not character");
            }
        }
     }
}
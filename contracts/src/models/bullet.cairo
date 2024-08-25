use octoguns::types::{Vec2, CharacterPosition, CharacterPositionTrait}; 
use alexandria_math::trigonometry::{fast_cos, fast_sin};
use octoguns::consts::TEN_E_8;

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct Bullet {
    #[key]
    pub bullet_id: u32,
    pub coords: Vec2,
    pub speed: i64, // pixels per step
    pub direction: i64, // in degrees
}


#[generate_trait]
impl BulletImpl of BulletTrait {

    fn new(id: u32, coords: Vec2, speed: i64, direction: i64) -> Bullet {
        Bullet { bullet_id: id, coords, speed, direction}
    }


    fn simulate(ref self: Bullet, characters: @Array<CharacterPosition>) -> (Option<Bullet>, u32) {
        let position = self.coords;
        let position_x = position.x;
        let position_y = position.y;
        let speed = self.speed;
        let direction = self.direction;

        let character_id = self.compute_hits(characters);

        if character_id != 0 {
            return (Option::None(()), character_id);
        }

        let x_shift = (fast_sin(direction) * speed) / TEN_E_8;
        let y_shift = (fast_cos(direction) * speed) / TEN_E_8;

        let new = Vec2 { x: position_x + x_shift, y: position_y + y_shift};

        if new.x < 0 || new.x > 10_000 || new.y < 0 || new.y > 10_000 {
            return (Option::None(()), character_id);
        }

        self.coords = new;

        (Option::Some(self), character_id)
    }

    fn compute_hits(ref self: Bullet, characters: @Array<CharacterPosition>) -> u32 {
        let mut character_index: u32 = 0;
        let mut character_id = 0;

        loop {
            if character_index >= characters.len() {
                break;
            }

            let character = *characters.at(character_index);

            let lower_bound_x = character.coords.x - 5;
            let upper_bound_x = character.coords.x + 5;
            let lower_bound_y = character.coords.y - 5;
            let upper_bound_y = character.coords.y + 5;

            if self.coords.x >= lower_bound_x && self.coords.x <= upper_bound_x &&
            self.coords.y >= lower_bound_y && self.coords.y <= upper_bound_y {
                character_id = character.id;
                break;        
            }

            character_index += 1;
        };

        character_id
    }


}


#[cfg(test)]
mod simulate_tests {

    use octoguns::types::{CharacterPosition, CharacterPositionTrait};
    use super::{Bullet, BulletTrait};
    use octoguns::types::{Vec2};
    use octoguns::tests::helpers::{get_test_character_array};

    #[test]
   fn test_bullet_sim_y_only()  {
        let mut bullet = BulletTrait::new(1, Vec2 { x:3, y:0}, 1, 0);
        let characters = get_test_character_array();
        let (res, id) = bullet.simulate(@characters);
        match res {
            Option::None => {
                panic!("Should not be none");
            },
            Option::Some(bullet) => {
                assert!(bullet.coords.y == 1, "y should have changed");
                assert!(bullet.coords.x == 3, "x should not have changed")
            }
        }
    }

    #[test]
    fn test_bullet_sim_x_only()  {
         let mut bullet = BulletTrait::new(1, Vec2 { x:3, y:0}, 1, 90 * 100_000_000);
         let characters = get_test_character_array();
         let (res, id) = bullet.simulate(@characters);
         match res {
             Option::None => {
                 panic!("Should not be none");
             },
             Option::Some(bullet) => {
                println!("x: {}, y: {}", bullet.coords.x, bullet.coords.y);
                 assert!(bullet.coords.x == 4, "x should have changed");
                 assert!(bullet.coords.y == 0, "y should not have changed");
             }
         }
     }


     #[test]
     fn test_collision() {
        let mut bullet = BulletTrait::new(1, Vec2 { x:3, y:0}, 1, 0);
        let characters = array![CharacterPositionTrait::new(69,4,0,100,0)];
        let (res, id) = bullet.simulate(@characters);
        match res {
            Option::None => {
                assert!(id == 69, "not returning id of hit piece");
            },
            Option::Some(bullet) => {
                panic!("bullet should have collided");
            }
        }
     }
     #[test]
     #[should_panic]
     fn test_collision_fail() {
        let mut bullet = BulletTrait::new(1, Vec2 { x:7, y:1}, 1, 0);
        let characters = array![CharacterPositionTrait::new(69,4,0,100,0)];
        let (res, id) = bullet.simulate( @characters);
        match res {
            Option::None => {
                assert!(id == 69, "not returning id of hit piece");
            },
            Option::Some(bullet) => {
                panic!("bullet should have collided");
            }
        }
     }
}
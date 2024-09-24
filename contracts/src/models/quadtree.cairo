use octoguns::consts::QUADTREE_CAPACITY;
use octoguns::types::Vec2;
use alexandria_math::{BitShift, U64BitShift};
use octoguns::models::characters::CharacterPosition;
use octoguns::models::bullet::Bullet;
use octoguns::models::map::{Map, MapTrait};
use dojo::world::IWorldDispatcher;
use starknet::ContractAddress;
#[derive(Drop, Serde)]
#[dojo::model]
struct Quadtree {
    #[key]
    session_id: u32,
    morton_codes: Array<u64>,
    colliders: Array<Collider>
}

#[derive(Copy, Drop, Serde, Introspect)]
struct Collider {
    id: u32,
    collider_type: ColliderType,
    position: Vec2,
    dimensions: Vec2
}

#[derive(Copy, Drop, Serde, Introspect)]
enum ColliderType {
    None,
    Wall,
    Character: u32,
}

#[generate_trait]
impl QuadtreeImpl of QuadtreeTrait {

    fn new(session_id: u32, characters: Array<CharacterPosition>, ref map: Map) -> Quadtree {
        let mut res = Quadtree {session_id, morton_codes: ArrayTrait::new(), colliders: ArrayTrait::new()};
        let mut i = 0;
        while i < characters.len() {
            let collider = Collider {
                collider_type: ColliderType::Character(*characters[i].id),
                position: *characters[i].coords,
                dimensions: Vec2 {x: 1000, y: 1000},
                id: *characters[i].id
            };
            res.insert(collider);
            i +=1;
        };
        i =0;
        while i < map.objects.len() {
            let collider = Collider {
                collider_type: ColliderType::Wall,
                position: map.get_object_coords(i),
                dimensions: Vec2 {x: 4000, y: 4000},
                id: 0
            };
            res.insert(collider);
            i +=1;
        };
        res
    }

    fn find_insert_index(ref self: Quadtree, morton_code: u64) -> u32 {
        let mut left = 0;
        let mut right = self.morton_codes.len();
        while left < right {
            let mid = (left + right) / 2;
            if *self.morton_codes[mid] < morton_code {
                left = mid + 1;
            } else {
                right = mid;
            }
        };
        left
    }

    // Updated insert method using binary search
    fn insert(ref self: Quadtree, object: Collider) {
        let morton_code = interleave_bits(object.position);
        let index = self.find_insert_index(morton_code);
        let mut new_morton_codes = ArrayTrait::new();
        let mut new_colliders = ArrayTrait::new();

        let mut i = 0;
        while i < index {
            new_morton_codes.append(*self.morton_codes[i]);
            new_colliders.append(*self.colliders[i]);
            i = i + 1;
        };

        new_morton_codes.append(morton_code);
        new_colliders.append(object);

        while i < self.morton_codes.len() {
            new_morton_codes.append(*self.morton_codes[i]);
            new_colliders.append(*self.colliders[i]);
            i = i + 1;
        };

        self.morton_codes = new_morton_codes;
        self.colliders = new_colliders;
    }

    fn remove(ref self: Quadtree, position: Vec2,id: u32) {
        let morton_code = interleave_bits(position);
        let index = self.find_insert_index(morton_code);
        let mut new_morton_codes = ArrayTrait::new();
        let mut new_colliders = ArrayTrait::new();
        let mut i = 0;
        let len = self.morton_codes.len();
        let mut removed = false;
        while i < len {
            if i == index && !removed {
                match self.colliders[i].collider_type {
                    ColliderType::Character(character_id) => {
                        println!("removing id: {}", character_id);
                        if id == *character_id {
                            removed = true;
                        }
                    },
                    _ => {}
                }
                // Skip adding this object
            } else {
                new_morton_codes.append(*self.morton_codes[i]);
                new_colliders.append(*self.colliders[i]);
            }
            i = i + 1;
        };
        self.morton_codes = new_morton_codes;
        self.colliders = new_colliders;
    }

    fn range_query(ref self: Quadtree, query_bounds: (u64, u64, u64, u64)) -> Array<Collider> {
        let (min_x, min_y, max_x, max_y) = query_bounds;
        let min_code = interleave_bits(Vec2 {x: min_x, y: min_y});
        let max_code = interleave_bits(Vec2 {x: max_x, y: max_y});
        let mut result = ArrayTrait::new();

        // Find the start index using binary search
        let start = self.find_insert_index(min_code);

        let mut i = start;
        while i < self.morton_codes.len() {
            let current_code = *self.morton_codes[i];
            if current_code > max_code {
                break;
            }

            // Check if the current collider overlaps with the query bounds
            let collider = *self.colliders[i];
            result.append(collider);

            i += 1;
        };

        result
    }

    #[inline]
    fn check_collisions(ref self: Quadtree, coords: Vec2) -> Option<Collider> {
        let mut res = Option::None(());

        // Define a small range around the projectile's point
        // Since projectiles are points, the range is just the point itself
        let mut min_x = 0;
        let mut min_y = 0;
        if coords.x > 2000 {
            min_x = coords.x - 2000;
        }
        if coords.y > 2000 {
            min_y = coords.y - 2000;
        }
        let query_bounds = (
            min_x,
            min_y,
            coords.x + 2000,
            coords.y + 2000,
        );
        // Perform a range query to find potential colliders
        let potential_colliders = self.range_query(query_bounds);

        let mut j = 0;
        while j < potential_colliders.len() {
            println!("number of potential colliders: {}", potential_colliders.len());
            println!("potential collider id: {}", *potential_colliders[j].id);
            let object = *potential_colliders[j];
            // Check if the projectile is inside the object's rectangle
            if is_point_inside_collider(coords.x, coords.y, object) {
                res = Option::Some(object);
            }
            j += 1;
        };

        res
    }
}

fn interleave_bits(v: Vec2) -> u64 {
    let mut x = v.x;
    let mut y = v.y;
    U64BitShift::shl(spread_bits(ref x), 1) | spread_bits(ref y)
}

fn spread_bits(ref n: u64) -> u64 {
    n = n & 0xFFFFFFFF; // Use 32 bits instead of 16
    let mut x = n;
    x = (x | U64BitShift::shl(x, 16)) & 0x0000FFFF0000FFFF;
    x = (x | U64BitShift::shl(x, 8))  & 0x00FF00FF00FF00FF;
    x = (x | U64BitShift::shl(x, 4))  & 0x0F0F0F0F0F0F0F0F;
    x = (x | U64BitShift::shl(x, 2))  & 0x3333333333333333;
    x = (x | U64BitShift::shl(x, 1))  & 0x5555555555555555;
    x
}

fn overlaps(collider: Collider, query_bounds: (u64, u64, u64, u64)) -> bool {
    let (min_x, min_y, max_x, max_y) = query_bounds;
    let collider_min_x = collider.position.x - collider.dimensions.x / 2;
    let collider_max_x = collider.position.x + collider.dimensions.x / 2;
    let collider_min_y = collider.position.y - collider.dimensions.y / 2;
    let collider_max_y = collider.position.y + collider.dimensions.y / 2;

    !(collider_max_x < min_x || collider_min_x > max_x || 
      collider_max_y < min_y || collider_min_y > max_y)
}

fn is_point_inside_collider(x: u64, y: u64, collider: Collider) -> bool {
    let offset = 1000;
    println!("x: {}, y: {}, collider.position.x: {}, collider.position.y: {}, collider.dimensions.x: {}, collider.dimensions.y: {}", x, y, collider.position.x, collider.position.y, collider.dimensions.x, collider.dimensions.y);
    x + offset >= collider.position.x + offset - collider.dimensions.x/2
        && x <= collider.position.x + collider.dimensions.x/2
        && y + offset >= collider.position.y + offset - collider.dimensions.y/2
        && y <= collider.position.y + collider.dimensions.y/2
}


#[cfg(test)]
mod quadtree_tests {

    use octoguns::types::Vec2;
    use super::interleave_bits;
    use super::{Quadtree, QuadtreeTrait,Collider, ColliderType};
    use octoguns::models::map::MapTrait;
    use octoguns::models::characters::CharacterPosition;
    use octoguns::types::MapObjects;

    #[test]
    fn interleave_test() {
        let res = interleave_bits(Vec2 {x: 50_000, y: 50_000});
    }

    fn test_quadtree_insert() {
        let address = starknet::contract_address_const::<0x0>();
        let characters = array![CharacterPosition {id: 1, coords: Vec2 {x: 50_000, y: 50_000}}];
        let mut map = MapTrait::new(1, MapObjects { objects: array![] });
        let mut quadtree = QuadtreeTrait::new(1, address, characters, ref map);
        let collider1 = Collider {id: 1, collider_type: ColliderType::Character(1), position: Vec2 {x: 50_000, y: 50_000}, dimensions: Vec2 {x: 1000, y: 1000}};
        let collider2 = Collider {id: 1, collider_type: ColliderType::Character(1), position: Vec2 {x: 50_000, y: 50_000}, dimensions: Vec2 {x: 1000, y: 1000}};
        quadtree.insert(collider1);
        quadtree.insert(collider2);
        assert_eq!(quadtree.morton_codes.len(), 2);
        assert_eq!(quadtree.colliders.len(), 2);
    }

    fn test_quadtree_init() {
        let address = starknet::contract_address_const::<0x0>();
        let characters = array![CharacterPosition {id: 1, coords: Vec2 {x: 50_000, y: 50_000}}];
        let row = 12*25;
        let objects: Array<u16> = array![row + 1, row+2, row+3, row+5, row+6, row+7, row+9, row+10, row+ 11, row + 13, row+14, row+15, row+17, row+18, row+19, row+21, row+22, row+ 23];
        let mut map = MapTrait::new(1, MapObjects { objects });
        let mut quadtree = QuadtreeTrait::new(1, address, characters, ref map);
        assert_eq!(quadtree.morton_codes.len(), 2);
        assert_eq!(quadtree.colliders.len(), 2);
    }



    #[test]
    fn collision_test() {
        let address = starknet::contract_address_const::<0x0>();
        let characters = array![CharacterPosition {id: 1, coords: Vec2 {x: 50_000, y: 50_000}}];
        let row = 12*25;
        let objects: Array<u16> = array![row + 1, row+2, row+3, row+5, row+6, row+7, row+9, row+10, row+ 11, row + 13, row+14, row+15, row+17, row+18, row+19, row+21, row+22, row+ 23];
        let mut map = MapTrait::new(1, MapObjects { objects });
        let mut quadtree = QuadtreeTrait::new(1, address, characters, ref map);
        let result = quadtree.check_collisions(Vec2 {x: 49_500, y: 49_600});
        assert_eq!(result.unwrap().id, 1);
    }




}


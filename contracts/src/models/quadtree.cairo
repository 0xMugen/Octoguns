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
    #[key]
    player: ContractAddress,
    morton_codes: Array<u64>,
    colliders: Array<Collider>
}

#[derive(Copy, Drop, Serde, Introspect)]
struct Collider {
    collider_type: ColliderType,
    postition: Vec2,
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

    fn new(session_id: u32, player: ContractAddress, characters: Array<CharacterPosition>, ref map: Map) -> Quadtree {
        let mut res = Quadtree {session_id, player, morton_codes: ArrayTrait::new(), colliders: ArrayTrait::new()};
        let mut i = 0;
        while i < characters.len() {
            let collider = Collider {
                collider_type: ColliderType::Character(*characters[i].id),
                postition: *characters[i].coords,
                dimensions: Vec2 {x: 1000, y: 1000}
            };
            res.insert(collider);
            i +=1;
        };
        while i < map.objects.len() {
            let collider = Collider {
                collider_type: ColliderType::Wall,
                postition: map.get_object_coords(i),
                dimensions: Vec2 {x: 4000, y: 4000}
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
        let morton_code = interleave_bits(object.postition);
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

    fn range_query(ref self: Quadtree, query_bounds: (u64, u64, u64, u64)) -> Array<Collider> {
        let (min_x, min_y, max_x, max_y) = query_bounds;
        let min_code = interleave_bits( Vec2 {x: min_x, y: min_y});
        let max_code = interleave_bits( Vec2 {x: max_x, y: max_y});
        let mut result = ArrayTrait::new();

        // Find the start index using binary search
        let start = self.find_insert_index(min_code);
        // Find the end index using binary search
        let end = self.find_insert_index(max_code + 1); // +1 to include max_code

        let mut i = start;
        while i < end && i < self.morton_codes.len() {
            if *self.morton_codes[i] > max_code {
                break;
            }
            result.append(*self.colliders[i]);
            i += 1;
        };

        result
    }

    #[inline]
    fn check_collisions(ref self: Quadtree, coords: Vec2, world: IWorldDispatcher) -> Option<Collider> {
        let mut res = Option::None(());

        // Define a small range around the projectile's point
        // Since projectiles are points, the range is just the point itself
        let query_bounds = (
            coords.x,
            coords.y,
            coords.x,
            coords.y,
        );
        // Perform a range query to find potential colliders
        let potential_colliders = self.range_query(query_bounds);

        let mut j = 0;
        while j < potential_colliders.len() {
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
    n = n & 0xFFFF;
    let mut x = n;
    x = (x | U64BitShift::shl(x, 8)) & 0x00FF00FF;
    x = (x | U64BitShift::shl(x, 4)) & 0x0F0F0F0F;
    x = (x | U64BitShift::shl(x, 2)) & 0x33333333;
    x = (x | U64BitShift::shl(x, 1)) & 0x55555555;
    x
}

fn is_point_inside_collider(x: u64, y: u64, collider: Collider) -> bool {
    let offset = 1000;
    x + offset >= collider.postition.x + offset - 500
        && x <= collider.postition.x + 500
        && y + offset >= collider.postition.y + offset - 500
        && y <= collider.postition.y + 500
}


#[cfg(test)]
mod quadtree_tests {

    use octoguns::types::Vec2;
    use super::interleave_bits;

    #[test]
    fn interleave_test() {
        let res = interleave_bits(Vec2 {x: 50_000, y: 50_000});
    }

}


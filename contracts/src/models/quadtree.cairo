use octoguns::consts::QUADTREE_CAPACITY;
use octoguns::types::Vec2;
use alexandria_math::{BitShift, U64BitShift};
use octoguns::models::characters::CharacterPosition;
use octoguns::models::bullet::Bullet;
use dojo::world::IWorldDispatcher;

#[derive(Drop, Serde)]
#[dojo::model]
struct Quadtree {
    #[key]
    session_id: u32,
    morton_codes: Array<u64>,
    characters: Array<u32>
}

#[generate_trait]
impl QuadtreeImpl of QuadtreeTrait {

    fn new(session_id: u32, characters: Array<CharacterPosition>) -> Quadtree {
        let mut res = Quadtree {session_id, morton_codes: ArrayTrait::new(), characters: ArrayTrait::new()};
        let mut i = 0;
        while i < characters.len() {
            res.insert(*characters[i]);
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
    fn insert(ref self: Quadtree, character: CharacterPosition) {
        let morton_code = interleave_bits(character.coords);
        let index = self.find_insert_index(morton_code);
        let mut new_morton_codes = ArrayTrait::new();
        let mut new_characters = ArrayTrait::new();

        let mut i = 0;
        while i < index {
            new_morton_codes.append(*self.morton_codes[i]);
            new_characters.append(*self.characters[i]);
            i = i + 1;
        };

        new_morton_codes.append(morton_code);
        new_characters.append(character.id);

        while i < self.morton_codes.len() {
            new_morton_codes.append(*self.morton_codes[i]);
            new_characters.append(*self.characters[i]);
            i = i + 1;
        };

        self.morton_codes = new_morton_codes;
        self.characters = new_characters;
    }

    // Updated remove method using binary search
    fn remove(ref self: Quadtree, character: CharacterPosition) {
        let morton_code = interleave_bits(character.coords);
        let index = self.find_insert_index(morton_code);
        let mut new_morton_codes = ArrayTrait::new();
        let mut new_characters = ArrayTrait::new();
        let mut i = 0;
        let len = self.morton_codes.len();
        let mut removed = false;

        while i < len {
            if i == index && *self.morton_codes[i] == morton_code && !removed && *self.characters[i] == character.id {
                removed = true;
                // Skip adding this object
            } else {
                new_morton_codes.append(*self.morton_codes[i]);
                new_characters.append(*self.characters[i]);
            }
            i = i + 1;
        };

        self.morton_codes = new_morton_codes;
        self.characters = new_characters;
    }

    fn range_query(ref self: Quadtree, query_bounds: (u64, u64, u64, u64)) -> Array<u32> {
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
            result.append(*self.characters[i]);
            i += 1;
        };

        result
    }

    #[inline]
    fn check_collisions(ref self: Quadtree, coords: Vec2, world: IWorldDispatcher) -> Option<u32> {
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
            let object = get!(world, *potential_colliders[j], CharacterPosition);
            // Check if the projectile is inside the object's rectangle
            if is_point_inside_character(coords.x, coords.y, object) {
                res = Option::Some(object.id);
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

fn is_point_inside_character(x: u64, y: u64, character: CharacterPosition) -> bool {
    let offset = 1000;
    x + offset >= character.coords.x + offset - 500
        && x <= character.coords.x + 500
        && y + offset >= character.coords.y + offset - 500
        && y <= character.coords.y + 500
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


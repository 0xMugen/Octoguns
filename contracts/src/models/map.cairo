#[derive(Clone, Drop, Serde)]
#[dojo::model]
pub struct Map {
    #[key]
    pub map_id: u32,
    pub map_objects_id: Array<u32>,
}

// Map is composed of a 100 x 100 Blocks used to place characters and objects
// Each square has a 1000 x 1000 grid hosted in each block for fine precion.
#[derive(Drop, Serde)]
#[dojo::model]
pub struct MapObjects {
    #[key]
    pub map_object_id: u32,
    pub dimensions: Vec2,
    pub coords: Vec2, 
}


#[derive(Copy, Drop, Serde, Introspect)]
struct Vec2 {
    x: i64,
    y: i64,
} 

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

}
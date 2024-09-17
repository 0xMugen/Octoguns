import { writable } from 'svelte/store'

export interface Coords {
    x: number
    y: number
  }
  
  export interface BulletCoords {
    coords: Coords
    id: number
    angle: number
    shot_by: number
  }
  
  
  //store for bullets that are shot in current move but not yet onchain, so they don't have an id
  export const bulletRender = writable<BulletCoords[]>([])
  
  export const bulletStart = writable<BulletCoords[]>([])
  export type CoordsStore = Record<number, Coords>
  

export const playerStartCoords = writable<CoordsStore>({})
export const playerCharacterCoords = writable<CoordsStore>({})
export const enemyCharacterCoords = writable<CoordsStore>({})
  
  function normalizeCoords(coords: Coords): Coords {
    return {
      x: coords.x / 1000 - 50,
      y: coords.y / 1000 - 50,
    }
  }
  
  export function setPlayerCharacterCoords(
    key: number,
    coords: { x: number; y: number }
  ): void {
    if (coords.x > 100) {
      coords = normalizeCoords(coords)
    }
    playerCharacterCoords.update((store) => {
      return {
        ...store,
        [key]: coords,
      }
    })
  }
  
  export function setEnemyCharacterCoords(
    key: number,
    coords: { x: number; y: number }
  ): void {
    if (coords.x > 100) {
      coords = normalizeCoords(coords)
    }
    enemyCharacterCoords.update((store) => {
      return {
        ...store,
        [key]: coords,
      }
    })
  }
  
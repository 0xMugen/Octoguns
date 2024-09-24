import { frameCounter, recordedMove } from '$stores/gameStores'
import { get } from 'svelte/store'
import type { TurnData } from '$stores/gameStores'
import { PerspectiveCamera } from 'three'
import * as THREE from 'three'
import { type BulletCoords, bulletRender, bulletStart} from '$stores/coordsStores'
import { isTurnPlayer } from '$stores/gameStores'
import { truncate, getYawAngle, inverseMapAngle } from '$lib/helper'

function applyBulletToStore(newBullet: BulletCoords) {
  bulletRender.update((bullets) => {
    bullets.push(newBullet)
    return bullets
  })
}

export function shoot(camera: PerspectiveCamera) {
  let move_index = Math.floor(get(frameCounter) / 3)

  let direction = getYawAngle(camera);
  if (direction < 0) {
    direction = 360 + direction
  }

  direction = Math.round(truncate(direction, 8) * 10**8);

  console.log(`Bullet shot at move index ${move_index} with angle ${direction} degrees`)

  recordedMove.update((rm) => {
    rm.shots.push({ angle: direction, step: move_index })
    console.log(rm.shots)
    return rm
  })

  let vx = Math.cos(THREE.MathUtils.degToRad(direction / 10**8))
  let vy = Math.sin(THREE.MathUtils.degToRad(direction / 10**8))

  const cameraPosition = camera.position
  const newBullet = {
    coords: {
      x: cameraPosition.x,
      y: cameraPosition.z,
    },
    shot_at: {
      x: cameraPosition.x,
      y: cameraPosition.z,
    },
    velocity: {x: vx, y: vy},
    shot_by: get(isTurnPlayer) ? 1 : 2,
    id: 0
  }

  applyBulletToStore(newBullet)
}

export function replayShot(move: TurnData, camera: PerspectiveCamera) {
  let move_index = Math.floor((get(frameCounter) + 1) / 3)

  let shot = move.shots.find((shot) => shot.step === move_index)
  if (shot) {
    let angle = shot.angle

    console.log(
      `Bullet shot at move index ${move_index} with angle ${angle}`
    )


    let vx = Math.cos(THREE.MathUtils.degToRad(angle / 10**8))
    let vy = Math.sin(THREE.MathUtils.degToRad(angle / 10**8))


    frameCounter.update((fc) => fc + 1)

    const cameraPosition = camera.position
    const newBullet = {
      coords: {
        x: cameraPosition.x,
        y: cameraPosition.z,
      },
      shot_at: {
        x: cameraPosition.x,
        y: cameraPosition.z,
      },
      velocity: {x: vx, y: vy},
      id: 0,
      //TODO: Fix this
      shot_by: get(isTurnPlayer) ? 1 : 2
    }

    applyBulletToStore(newBullet)
  }
}

export function resetBullets() {
  bulletRender.set(get(bulletStart))
}

export function simulate() {
  //update temp / new bullets
  bulletRender.update((bullets) => {
    let newBullets: BulletCoords[] = []
    bullets.map((bullet) => {
      console.log(bullet)
      const newX = bullet.coords.x + bullet.velocity.x/3
      const newY = bullet.coords.y + bullet.velocity.y/3
      console.log(newX, newY)
      newBullets.push( {
        ...bullet,
        coords: {
          x: newX,
          y: newY,
        },
      })
    })
    return newBullets
  })

}

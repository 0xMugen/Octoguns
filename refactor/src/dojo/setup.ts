import type { DojoConfig } from '@dojoengine/core'
import { DojoProvider } from '@dojoengine/core'
import * as torii from '@dojoengine/torii-client'
import { createClientComponents } from './createClientComponents'
import { defineContractComponents } from './models.gen'
import { world } from './world'
import { setupWorld } from './contracts.gen'
import { Account } from 'starknet'
import type { ArraySignatureType } from 'starknet'
import { BurnerManager } from '@dojoengine/create-burner'
import { getSyncEntities, getSyncEvents } from '@dojoengine/state'

export type SetupResult = Awaited<ReturnType<typeof setup>>

export async function setup({ ...config }: DojoConfig) {
  // torii client
  const toriiClient = await torii.createClient({
    rpcUrl: config.rpcUrl,
    toriiUrl: config.toriiUrl,
    relayUrl: '',
    worldAddress:
      '0x6d0cc89f47c2fb0a8ee113b47d4f04de5092f68f6ef8cb4d79d77446a4d931f' || '',
  })

  // create contract components
  const contractComponents = defineContractComponents(world)

  // create client components
  const clientComponents = createClientComponents({ contractComponents })

  // create dojo provider
  const dojoProvider = new DojoProvider(config.manifest, config.rpcUrl)
  let entities = await toriiClient.getAllEntities(100, 0)
  console.log(entities)

  const sync = await getSyncEntities(toriiClient, contractComponents as any, [])

  // setup world
  const client = await setupWorld(dojoProvider)

  // create burner manager
  const burnerManager = new BurnerManager({
    masterAccount: new Account(
      {
        nodeUrl: config.rpcUrl,
      },
      "0x7ddb9e98f8a9b58ffb3d2b90ab45b018f9aa2a3c98c5d92fee54ab616ac09bf",
      "0x5356ed10bd95660fc42bab2880b4e29937acbc960ec4094157adb76c4a6a1b6"
    ),
    accountClassHash: config.accountClassHash,
    rpcProvider: dojoProvider.provider,
    feeTokenAddress: config.feeTokenAddress,
  })

  try {
    await burnerManager.init()
    if (burnerManager.list().length === 0) {
      await burnerManager.create()
    }
  } catch (e) {
    console.error(e)
  }

  return {
    client,
    clientComponents,
    contractComponents,
    publish: (typedData: string, signature: ArraySignatureType) => {
      toriiClient.publishMessage(typedData, signature)
    },
    config,
    dojoProvider,
    burnerManager,
    toriiClient,

    torii,
    sync,
  }
}

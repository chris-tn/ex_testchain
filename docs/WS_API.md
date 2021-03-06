## WS API
ExTestchain will use special port `4000` for internal communication.
This port is exposed by default and you don't need to add `--expose 4000` to `docker run` command.

WS API is based on [Phoenix Channels](https://hexdocs.pm/phoenix/channels.html#content)

And main idea is to spawn new channel for every chain.

For example: If you start new chain with id `15733048862987664459` system will pose all notifications and receive commands for this chain in `chain:15733048862987664459` channel.

So you have to join new channel after starting chain.

```javascript
const options = {
    type: chain, // For now "geth" or "ganache". (If omited - "ganache" will be used)
    id: null, // Might be string but normally better to omit
    http_port: 8545, // port for chain. should be changed on any new chain
    ws_port: 8546, // ws port (only for geth) for ganache will be ignored
    accounts: 2, // Number of account to be created on chain start
    block_mine_time: 0, // how often new block should be mined (0 - instamine)
    clean_on_stop: true, // Will delete chain db folder after chain stop
}
api.push("start", options)
    .receive("ok", ({id: id}) => {
    console.log('Created new chain', id)
    start_channel(id)
        .on('started', (data) => console.log('Chain started', data))
    })
    .receive('error', console.error)
    .receive('timeout', () => console.log('Network issues'))
```

### Examples

Some examples you might be find in [index.html](../apps/web_api/priv/static/index.html)

## API description

All description is based on [Phoenix.Message](https://hexdocs.pm/phoenix/channels.html#messages) scructure 

### Starting new chain

```js
{
    topic: 'api',
    event: 'start',
    payload: {
        type: "geth", // For now "geth" or "ganache". (If omited - "ganache" will be used)
        id: null, // Might be string but normally better to omit
        http_port: 8545, // port for chain. should be changed on any new chain
        ws_port: 8546, // ws port (only for geth) for ganache will be ignored
        accounts: 2, // Number of account to be created on chain start
        block_mine_time: 0, // how often new block should be mined (0 - instamine)
        clean_on_stop: true, // Will delete chain db folder after chain stop
        db_path: "/opt/my-awesome-chain" // For existing chain data. be sure you mounted volume to docker
    }
}
```

As response you will get chain id that initializing. 
Example: `{id: "15733048862987664459"}`

**Note** 
Returned ID does not mean that chain started successfully.
You have to wait for event from chain channel. See [Events](#events)

### Stoping chain

```js
{
    topic: `chain:${chain_id}`,
    event: 'stop',
    payload: {}
}
```

Success response will mean chain stopped.
Example:
```js
chain_channel
    .push('stop')
    .receive('ok', () => console.log('Chain stooped'))
    .receive('error', console.error)
```

### Making snapshot

```js
{
    topic: `chain:${chain_id}`,
    event: 'take_snapshot',
    payload: {}
}
```

And will get response with snapshot ID 
Example: `{snapshot: 'some/snapshot/id'}`

Example of action:
```js
chain_channel
    .push('take_snapshot')
    .receive('ok', ({ snapshot }) => console.log('Snapshot made for chain %s snapshot: %s', id, snapshot))
    .receive('error', console.error)
```

### Reverting snapshot

```js
{
    topic: `chain:${chain_id}`,
    event: 'revert_snapshot',
    payload: {
        snapshot: 'some/snapshot/id'
    }
}
```

And empty response will mean everything - good.

Example of action:
```js
chain_channel
    .push('revert_snapshot', { snapshot: snapshot_id_we_got_from_take_snapshot })
    .receive('ok', () => console.log('Snapshot restored for chain %s', id))
    .receive('error', console.error)
```

## Events
Because some operations might take some time or for example errors might appear randomly
ex_testchain provides you with set of events for handling such situations.

Event are firing only for chains. So you have to listen chain channel `chain:{id_here}`.

Using `phoenix.js` you could add listener for special event. 
Example: 
```js
const channel = socket.channel(`chain:${chain_id}`)
channel
    .join()
    .receive("ok", () => console.log(`Joined to chain:${chain_id} channel`))
    .receive("error", ({reason}) => console.log("failed join", reason) )
    .receive("timeout", () => console.log("Networking issue. Still waiting..."))

// registering event listeners
channel.on('started', (data) => console.log('Chain started', data))
channel.on('error', (err) => console.error('Chain received error', err))
channel.on('stopped', (data) => console.log('Chain stopped', data))
```

List of available events:
 - `started`
 - `stopped`
 - `error` 
 - `snapshot_taken` 
 - `snapshot_reverted`
 
### Error
Error event might be fired at any time.
Event: `error`
Event will be fired to `api` and `chain:${id}` channels

Payload example:
```js
{
    "message": "some error"
}
```

### Chain started
Event: `started`
Event will be fired to `api` channel and `chain:${id}` as well.

Payload Example: 
```js
{
    "accounts": [
        "0x583a5656a78d3136d213505a704becba3e2bf548","0x316cc3522de00d9e276adc457d53e31eaa25c921"
    ],
    "coinbase": "0x583a5656a78d3136d213505a704becba3e2bf548",
    "id": "15685858230525373105",
    "rpc_url": "http://localhost:8545",
    "ws_url": "ws://localhost:8546"
}
```

### Snapshot taked
Event: `snapshot_taken`
Event will be fired to `chain:${id}` channel.
`path_to` in Payload is a snapshot id that you will use for restoring snapshot

Payload example: 
```js
{
    "path_to": "/tmp/snapshots/15685858230525373105/17638247996621996374"
}
```

### Snapshot reverted
Event: `snapshot_reverted`
Event will be fired to `chain:${id}` channel

Payload example:
```js
{
    "path_from": "/tmp/snapshots/15685858230525373105/17638247996621996374"
}
```

### Stopped
Event `stopped`
Event will be fired to `chain:${id}` channel
Payload will be empty
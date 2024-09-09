<div align="center">
    <img src="./docs/img/btczee.png" alt="btczee-logo" height="260"/>
    <h2>Bitcoin protocol implementation in Zig.</h2>

<a href="https://github.com/zig-bitcoin/btczee/actions/workflows/check.yml"><img alt="GitHub Workflow Status" src="https://img.shields.io/github/actions/workflow/status/zig-bitcoin/btczee/check.yml?style=for-the-badge" height=30></a>
<a href="https://ziglang.org/"> <img alt="Zig" src="https://img.shields.io/badge/zig-%23000000.svg?style=for-the-badge&logo=zig&logoColor=white" height=30></a>
<a href="https://bitcoin.org/"> <img alt="Bitcoin" src="https://img.shields.io/badge/Bitcoin-000?style=for-the-badge&logo=bitcoin&logoColor=white" height=30></a>
<a href="https://lightning.network/"><img src="https://img.shields.io/badge/Ligthning Network-000.svg?&style=for-the-badge&logo=data:image/svg%2bxml;base64%2CPD94bWwgdmVyc2lvbj0iMS4wIiBzdGFuZGFsb25lPSJubyI%2FPg0KPCEtLSBHZW5lcmF0b3I6IEFkb2JlIEZpcmV3b3JrcyAxMCwgRXhwb3J0IFNWRyBFeHRlbnNpb24gYnkgQWFyb24gQmVhbGwgKGh0dHA6Ly9maXJld29ya3MuYWJlYWxsLmNvbSkgLiBWZXJzaW9uOiAwLjYuMSAgLS0%2BDQo8IURPQ1RZUEUgc3ZnIFBVQkxJQyAiLS8vVzNDLy9EVEQgU1ZHIDEuMS8vRU4iICJodHRwOi8vd3d3LnczLm9yZy9HcmFwaGljcy9TVkcvMS4xL0RURC9zdmcxMS5kdGQiPg0KPHN2ZyBpZD0iYml0Y29pbl9saWdodG5pbmdfaWNvbi5mdy1QYWdlJTIwMSIgdmlld0JveD0iMCAwIDI4MCAyODAiIHN0eWxlPSJiYWNrZ3JvdW5kLWNvbG9yOiNmZmZmZmYwMCIgdmVyc2lvbj0iMS4xIg0KCXhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgeG1sbnM6eGxpbms9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkveGxpbmsiIHhtbDpzcGFjZT0icHJlc2VydmUiDQoJeD0iMHB4IiB5PSIwcHgiIHdpZHRoPSIyODBweCIgaGVpZ2h0PSIyODBweCINCj4NCgk8cGF0aCBpZD0iRWxsaXBzZSIgZD0iTSA3IDE0MC41IEMgNyA2Ni43NjkgNjYuNzY5IDcgMTQwLjUgNyBDIDIxNC4yMzEgNyAyNzQgNjYuNzY5IDI3NCAxNDAuNSBDIDI3NCAyMTQuMjMxIDIxNC4yMzEgMjc0IDE0MC41IDI3NCBDIDY2Ljc2OSAyNzQgNyAyMTQuMjMxIDcgMTQwLjUgWiIgZmlsbD0iI2Y3OTMxYSIvPg0KCTxwYXRoIGQ9Ik0gMTYxLjE5NDMgNTEuNSBDIDE1My4yMzQ5IDcyLjE2MDcgMTQ1LjI3NTYgOTQuNDEwNyAxMzUuNzI0NCAxMTYuNjYwNyBDIDEzNS43MjQ0IDExNi42NjA3IDEzNS43MjQ0IDExOS44MzkzIDEzOC45MDgxIDExOS44MzkzIEwgMjA0LjE3NDcgMTE5LjgzOTMgQyAyMDQuMTc0NyAxMTkuODM5MyAyMDQuMTc0NyAxMjEuNDI4NiAyMDUuNzY2NyAxMjMuMDE3OSBMIDExMC4yNTQ1IDIyOS41IEMgMTA4LjY2MjYgMjI3LjkxMDcgMTA4LjY2MjYgMjI2LjMyMTQgMTA4LjY2MjYgMjI0LjczMjEgTCAxNDIuMDkxOSAxNTMuMjE0MyBMIDE0Mi4wOTE5IDE0Ni44NTcxIEwgNzUuMjMzMyAxNDYuODU3MSBMIDc1LjIzMzMgMTQwLjUgTCAxNTYuNDE4NyA1MS41IEwgMTYxLjE5NDMgNTEuNSBaIiBmaWxsPSIjZmZmZmZmIi8%2BDQo8L3N2Zz4%3D" alt="Bitcoin Lightning" height="30"></a>

</div>

# About

`btczee` is a Bitcoin protocol implementation in Zig. It aims to provide a clean and simple implementation of the Bitcoin protocol. The goal is to have a fully functional Bitcoin node that can be used to interact with the Bitcoin network.

## Architecture

You can find the architecture of the project and description of components in the [docs/architecture.md](./docs/architecture.md) file.

```mermaid
graph TD
    Node[Node] --> Network
    Node --> Mempool
    Node --> Wallet
    Node --> Storage
    Node --> Miner

    Network --> Mempool
    Network --> Storage

    Mempool --> Wallet
    Mempool --> Storage

    Wallet --> Storage

    Miner --> Mempool
    Miner --> Storage

    subgraph "Core Components"
        Node
        Network
        Mempool
        Wallet
        Storage
        Miner
    end

    subgraph "Supporting Components"
        Types
        Primitives
        Config
    end

    Node -.-> Types
    Node -.-> Primitives
    Node -.-> Config

    classDef core fill:#f9f,stroke:#333,stroke-width:2px;
    classDef support fill:#bbf,stroke:#333,stroke-width:1px;
    class Node,Network,Mempool,Wallet,Storage,Miner core;
    class Types,Primitives,Config support;
```

## Run

```sh
Usage: btczee [command] [args]

Commands:
  node     <subcommand>
  wallet   <subcommand>
```

### Node

```sh
Usage: btczee node <subcommand>

Subcommands:
  help   Display help for node
```

Example:

```sh
zig build run -- node

# OR (after a build)
./zig-out/bin/btczee node
```

### Wallet

```sh
Usage: btczee wallet <subcommand>

Subcommands:
  create    Create a new wallet
  load      Load an existing wallet
  help      Display help for wallet
```

Example:

```sh
zig build run -- wallet create

# OR (after a build)
./zig-out/bin/btczee wallet create
```

## Test

```sh
zig build test --summary all
```

## Build

```sh
zig build -Doptimize=ReleaseFast
```

## Benchmark

```sh
zig build bench
```

## Documentation

You can generate the documentation by running the following command:

```sh
zig build docs
```

## Roadmap

You can find the roadmap of the project in the [docs/roadmap.md](./docs/roadmap.md) file.

## License

`btczee` is licensed under the MIT license. See the [LICENSE](./LICENSE) file for more details.

## References

- [Bitcoin Core](https://github.com/bitcoin/bitcoin)
- [Learn me a bitcoin](https://learnmeabitcoin.com/)
- [Mastering Bitcoin](https://github.com/bitcoinbook/bitcoinbook)
- [Onboarding to Bitcoin Core](https://github.com/chaincodelabs/onboarding-to-bitcoin-core)
- [Zig](https://github.com/ziglang/zig)
- [Zig Standard Library](https://github.com/ziglang/zig/tree/master/lib/std)
- [Ziglings](https://codeberg.org/ziglings/exercises/)

## Contributors ✨

Thanks goes to these wonderful people ([emoji key](https://allcontributors.org/docs/en/emoji-key)):

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tbody>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/AbdelStark"><img src="https://avatars.githubusercontent.com/u/45264458?v=4?s=100" width="100px;" alt="A₿del ∞/21M 🐺 - 🐱"/><br /><sub><b>A₿del ∞/21M 🐺 - 🐱</b></sub></a><br /><a href="https://github.com/zig-bitcoin/btczee/commits?author=AbdelStark" title="Code">💻</a> <a href="#ideas-AbdelStark" title="Ideas, Planning, & Feedback">🤔</a> <a href="#mentoring-AbdelStark" title="Mentoring">🧑‍🏫</a> <a href="#projectManagement-AbdelStark" title="Project Management">📆</a> <a href="#research-AbdelStark" title="Research">🔬</a> <a href="https://github.com/zig-bitcoin/btczee/pulls?q=is%3Apr+reviewed-by%3AAbdelStark" title="Reviewed Pull Requests">👀</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/lana-shanghai"><img src="https://avatars.githubusercontent.com/u/31368580?v=4?s=100" width="100px;" alt="lanaivina"/><br /><sub><b>lanaivina</b></sub></a><br /><a href="https://github.com/zig-bitcoin/btczee/commits?author=lana-shanghai" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/tdelabro"><img src="https://avatars.githubusercontent.com/u/34384633?v=4?s=100" width="100px;" alt="Timothée Delabrouille"/><br /><sub><b>Timothée Delabrouille</b></sub></a><br /><a href="https://github.com/zig-bitcoin/btczee/commits?author=tdelabro" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://okhaimie.com/"><img src="https://avatars.githubusercontent.com/u/57156589?v=4?s=100" width="100px;" alt="okhai"/><br /><sub><b>okhai</b></sub></a><br /><a href="https://github.com/zig-bitcoin/btczee/commits?author=okhaimie-dev" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/supreme2580"><img src="https://avatars.githubusercontent.com/u/100731397?v=4?s=100" width="100px;" alt="Supreme Labs"/><br /><sub><b>Supreme Labs</b></sub></a><br /><a href="https://github.com/zig-bitcoin/btczee/commits?author=supreme2580" title="Code">💻</a></td>
    </tr>
  </tbody>
  <tfoot>
    <tr>
      <td align="center" size="13px" colspan="7">
        <img src="https://raw.githubusercontent.com/all-contributors/all-contributors-cli/1b8533af435da9854653492b1327a23a4dbd0a10/assets/logo-small.svg">
          <a href="https://all-contributors.js.org/docs/en/bot/usage">Add your contributions</a>
        </img>
      </td>
    </tr>
  </tfoot>
</table>

<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->

This project follows the [all-contributors](https://github.com/all-contributors/all-contributors) specification. Contributions of any kind welcome!

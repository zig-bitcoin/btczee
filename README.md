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

You can find the architecture of the project in the [docs/architecture.md](./docs/architecture.md) file.

## Run

```sh
zig build run
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

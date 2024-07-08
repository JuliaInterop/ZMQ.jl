# ZMQ.jl

*A Julia interface to ZeroMQ*

| **Documentation**                                                         | **Coverage**                    |
|:-------------------------------------------------------------------------:|:-------------------------------:|
| [![][docs-stable-img]][docs-stable-url] [![][docs-dev-img]][docs-dev-url] | [![][codecov-img]][codecov-url] |

**ZMQ.jl** is a [Julia](http://julialang.org) interface to [ZeroMQ, The Intelligent Transport Layer](http://zeromq.org).

## Installation

The package can be installed with the Julia package manager.
From the Julia REPL, type `]` to enter the Pkg REPL mode and run:

```
pkg> add ZMQ
```

Or, equivalently, via the `Pkg` API:

```julia
julia> import Pkg; Pkg.add("ZMQ")
```

## Documentation

- [**STABLE**][docs-stable-url] &mdash; **documentation of the most recently tagged version.**
- [**DEVEL**][docs-dev-url] &mdash; *documentation of the in-development version.*

## Questions and Contributions

Usage questions can be posted on the [Julia Discourse forum][discourse-tag-url]
under the `zmq` tag, in the `#helpdesk` channel of the [Julia
Slack](https://julialang.org/community/), or the `#helpdesk`/`#helpdesk
(published)` stream of the [Julia Zulip](https://julialang.zulipchat.com/).

Contributions are very welcome, as are feature requests and suggestions. Please
open an [issue][issues-url] if you encounter any problems.

[discourse-tag-url]: https://discourse.julialang.org/tags/zmq

[docs-dev-img]: https://img.shields.io/badge/docs-dev-blue.svg
[docs-dev-url]: https://juliainterop.github.io/ZMQ.jl/latest

[docs-stable-img]: https://img.shields.io/badge/docs-stable-blue.svg
[docs-stable-url]: https://juliainterop.github.io/ZMQ.jl/stable

[codecov-img]: https://codecov.io/gh/JuliaInterop/ZMQ.jl/graph/badge.svg?token=NMxuhZepAU
[codecov-url]: https://codecov.io/gh/JuliaInterop/ZMQ.jl

[issues-url]: https://github.com/JuliaInterop/ZMQ.jl/issues

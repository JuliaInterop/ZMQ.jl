# ZMQ.jl

*A Julia interface to ZeroMQ*

| **Documentation**                                                         | **Build Status**                                                |
|:-------------------------------------------------------------------------:|:---------------------------------------------------------------:|
| [![][docs-stable-img]][docs-stable-url] [![][docs-dev-img]][docs-dev-url] | [![][travis-img]][travis-url] [![][appveyor-img]][appveyor-url] |

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

(This installs its own copy of the ZMQ libraries from the [ZMQBuilder](https://github.com/JuliaInterop/ZMQBuilder) repository.)

## Documentation

- [**STABLE**][docs-stable-url] &mdash; **documentation of the most recently tagged version.**
- [**DEVEL**][docs-dev-url] &mdash; *documentation of the in-development version.*

## Troubleshooting

If you are using Windows and get an error `Provider PackageManager failed to satisfy dependency zmq`, you may need to restart Julia and run `Pkg.build("ZMQ")` again. See [issue #69](https://github.com/JuliaLang/ZMQ.jl/issues/69) for more details.

## Questions and Contributions

Usage questions can be posted on the [Julia Discourse forum][discourse-tag-url] under the `zmq` tag, in the #zmq channel of the [Julia Slack](https://julialang.org/community/) and/or in the [JuliaDocs Gitter chat room][gitter-url].

Contributions are very welcome, as are feature requests and suggestions. Please open an [issue][issues-url] if you encounter any problems. The [contributing page][contrib-url] has a few guidelines that should be followed when opening pull requests and contributing code.

[contrib-url]: https://juliadocs.github.io/Documenter.jl/latest/man/contributing/
[discourse-tag-url]: https://discourse.julialang.org/tags/documenter
[gitter-url]: https://gitter.im/juliadocs/users

[docs-dev-img]: https://img.shields.io/badge/docs-dev-blue.svg
[docs-dev-url]: https://juliainterop.github.io/ZMQ.jl/latest

[docs-stable-img]: https://img.shields.io/badge/docs-stable-blue.svg
[docs-stable-url]: https://juliainterop.github.io/ZMQ.jl/stable

[travis-img]: https://api.travis-ci.org/JuliaInterop/ZMQ.jl.svg
[travis-url]: https://travis-ci.org/JuliaInterop/ZMQ.jl

[appveyor-img]: https://ci.appveyor.com/api/projects/status/u1d6dpovaptdqalh?svg=true
[appveyor-url]: https://ci.appveyor.com/project/StevenGJohnson/zmq-jl

[codecov-img]: https://codecov.io/gh/JuliaDocs/Documenter.jl/branch/master/graph/badge.svg
[codecov-url]: https://codecov.io/gh/JuliaDocs/Documenter.jl

[issues-url]: https://github.com/JuliaDocs/Documenter.jl/issues

```@meta
CurrentModule = ZMQ
```

# Changelog

This documents notable changes in ZMQ.jl. The format is based on [Keep a
Changelog](https://keepachangelog.com).

## Unreleased

### Added
- Support for creating [`Message`](@ref)'s from the new `Memory` type in Julia
  1.11 ([#244]).

## [v1.2.6] - 2024-06-13

### Added

- [`lib_version()`](@ref) to get the libzmq version ([#240]).

### Fixed

- Fixed a precompilation bug that would cause creating a sysimage with
  PackageCompiler.jl on Julia 1.6 to fail ([#242]).

## [v1.2.5] - 2024-05-28

### Fixed

- Fixed support for Julia 1.3 in the precompilation workload ([#237]).

## [v1.2.4] - 2024-05-27

### Changed

- Refactored the internals to use the public `FileWatching.FDWatcher` instead of
  `FileWatching._FDWatcher` ([#215]).

### Fixed

- Docstrings to inner constructors are now assigned properly ([#227]).
- [`Socket`](@ref) now holds a reference to its [`Context`](@ref) to prevent it from
  being garbage collected accidentally ([#229]).
- Changed the precompilation workload to use any available port to avoid port
  conflicts ([#234]).

## [v1.2.3] - 2024-05-12

### Added

- Support for setting `ZMQ_IMMEDIATE` and `ZMQ_CONFLATE` on sockets ([#209],
  [#222]).
- Overloads for [`Message`](@ref) to allow deserializing them with MsgPack.jl
  ([#214]).
- A precompilation workload to improve TTFX ([#224]).

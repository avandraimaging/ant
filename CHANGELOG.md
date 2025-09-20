# Changelog

## [0.1.0]

### Added

- Ability to set uniqueness constraints to prevent duplicate job creation

### Changed

- Queue updates worker's status to `running` before spawning a new process to address [race condition issue](https://github.com/MikeAndrianov/ant/pull/5)

## [0.0.3]

### Fixed

- Prevented GenServer crash on retry when exception lacks a `:message` key

## [0.0.2]

### Fixed

- Improved handling of worker completion states
- Optimized the processing of workers in queues.

### Added
- Added better error handling for worker processing states
- Added support for proper worker prioritization in the queue system

## [0.0.1]
### Added
- Initial release
- Basic queue functionality
- Worker processing system
- Mnesia adapter for persistence

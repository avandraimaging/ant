# Changelog


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
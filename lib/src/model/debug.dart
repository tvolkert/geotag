/// Whether to use real isolates when running in debug mode.
///
/// Setting this to false allows tests to skip isolates, which not only
/// simplifies tests (eliminates the need for [runAsync]), but it allows
/// things like [MemoryFileSystem] to be mutated within workers and for those
/// mutations to be visible to the main isolate.
bool debugUseRealIsolates = true;

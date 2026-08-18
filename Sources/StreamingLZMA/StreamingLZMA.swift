// StreamingLZMA
// A Swift library for LZMA compression and decompression using Apple's Compression framework.

// Public API is provided through:
// - LZMAConfiguration: Configuration options for buffer size
// - LZMAError: Error types for compression/decompression failures
// - LZMACompressor: Actor for streaming compression
// - LZMADecompressor: Actor for streaming decompression
// - LZMAFileHeader: LZMA file format header parsing/writing
// - LZMAFileFormat: File format constants
// - Data extensions: One-shot compression/decompression
// - FileHandle extensions: File streaming
// - InputStream extensions: Stream-based processing
// - AsyncSequence extensions: Async sequence integration

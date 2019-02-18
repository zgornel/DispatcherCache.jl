COMPRESSIONS = ["bz2", "bzip2", "gz", "gzip", "none", "unknown"]
KNOWN_COMPRESSIONS = ["bz2", "bzip2", "gz", "gzip", "none"]
ACTIONS = ["compress", "decompress", "unknown"]
KNOWN_ACTIONS = ["compress", "decompress"]

using DispatcherCache: get_compressor

@testset "Compression" begin
    mktempdir() do dir
        value = "some value"
        for (compression, action) in Iterators.product(COMPRESSIONS, ACTIONS)
            file = joinpath(abspath(dir), join("tmp", ".", compression))

            compression in ["bz2", "bzip2"] && action=="compress" && begin
                compressor = get_compressor(compression, action)
                @test compressor == Bzip2CompressorStream
                @test open(compressor, file, "w") do fid
                    write(fid, value)
                end > 0
            end

            compression in ["bz2", "bzip2"] && action=="decompress" && begin
                compressor = get_compressor(compression, action)
                @test compressor == Bzip2DecompressorStream
                @test open(compressor, file, "r") do fid
                    read(fid, typeof(value))
                end == value
            end

            compression in ["gz", "gzip"] && action=="compress" && begin
                compressor = get_compressor(compression, action)
                @test compressor == GzipCompressorStream
                @test open(compressor, file, "w") do fid
                    write(fid, value)
                end > 0
            end
            compression in ["gz", "gzip"] && action=="decompress" && begin
                compressor = get_compressor(compression, action)
                @test compressor == GzipDecompressorStream
                @test open(compressor, file, "r") do fid
                    read(fid, typeof(value))
                end == value
            end

            compression == "none"  && action in ["compress", "decompress"] &&
                @test get_compressor(compression, action) == NoopStream
                # No need to test reading/writing

            !(compression in KNOWN_COMPRESSIONS) || !(action in KNOWN_ACTIONS) &&
                @test_throws ErrorException get_compressor(compression, action)
        end
    end
end

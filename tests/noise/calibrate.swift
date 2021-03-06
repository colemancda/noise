import Noise
import MaxPNG

func grayscale_noise_png(noise:Noise, width:Int, height:Int, value_offset:Double, path:String)
{
    let byte_count:Int = width * height
    let pixbytes = UnsafeMutableBufferPointer<UInt8>(start: UnsafeMutablePointer<UInt8>.allocate(capacity: byte_count), count: byte_count)
    defer
    {
        pixbytes.baseAddress?.deallocate(capacity: pixbytes.count)
    }

    for (i, (x, y)) in Domain2D(-2 ... 2, -2 ... 2, samples_x: width, samples_y: height).enumerated()
    {
        pixbytes[i] = UInt8(clamping: noise.evaluate(x, y) + value_offset)
    }

    write_png(  path: path,
                width: width,
                height: height,
                pixbytes: UnsafeBufferPointer<UInt8>(start: pixbytes.baseAddress, count: pixbytes.count),
                color: .grayscale)
}

public
func calibrate_noise(width:Int, height:Int, seed:Int = 0)
{
    grayscale_noise_png(noise: DistortedNoise(FBM(ClassicNoise3D(amplitude: 0.5*255, frequency: 2, seed: seed), octaves: 4), strength: 0.003),
                        width: width,
                        height: height,
                        value_offset: 0.5*255,
                        path: "tests/calibrate_classic-distortion.png")

    grayscale_noise_png(noise: GradientNoise2D(amplitude: 0.5*255, frequency: 4, seed: seed),
                        width: width,
                        height: height,
                        value_offset: 0.5*255,
                        path: "tests/calibrate_gradient2d.png")

    grayscale_noise_png(noise: GradientNoise3D(amplitude: 0.5*255, frequency: 4, seed: seed),
                        width: width,
                        height: height,
                        value_offset: 0.5*255,
                        path: "tests/calibrate_gradient3d.png")

    grayscale_noise_png(noise: CellNoise2D(amplitude: 255, frequency: 4, seed: seed),
                        width: width,
                        height: height,
                        value_offset: 0,
                        path: "tests/calibrate_cell2d.png")

    grayscale_noise_png(noise: CellNoise3D(amplitude: 255, frequency: 4, seed: seed),
                        width: width,
                        height: height,
                        value_offset: 0,
                        path: "tests/calibrate_cell3d.png")
}

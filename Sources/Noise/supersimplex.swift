import func Glibc.sin
import func Glibc.cos

struct SuperSimplex:HashedNoiseGenerator
{
    struct LatticePoint2D
    {
        let u:Int,
            v:Int,
            dx:Double,
            dy:Double

        init(u:Int, v:Int)
        {
            let stretch_offset:Double = Double(u + v) * SQUISH_2D
            self.u = u
            self.v = v
            self.dx = Double(u) + stretch_offset
            self.dy = Double(v) + stretch_offset
        }
    }

    static let n_hashes_2d:Int = 16
    static let gradient_table_2d:[(Double, Double)] = (0 ..< SuperSimplex.n_hashes_2d).lazy.map
    { Double($0) * 2 * Double.pi/Double(SuperSimplex.n_hashes_2d) }.map
    {
        let x:Double = 10*cos($0),
            y:Double = 10*sin($0)
        return (x, y)
    }

    static let points_2d:[LatticePoint2D] =
    [
        ((-1,  0), ( 0, -1)),
        (( 0,  1), ( 1,  0)),
        (( 1,  0), ( 0, -1)),
        (( 2,  1), ( 1,  0)),
        ((-1,  0), ( 0,  1)),
        (( 0,  1), ( 1,  2)),
        (( 1,  0), ( 0,  1)),
        (( 2,  1), ( 1,  2)),
    ].map
    {
        return [LatticePoint2D(u:    0, v:    0),
                LatticePoint2D(u:    1, v:    1),
                LatticePoint2D(u: $0.0, v: $0.1),
                LatticePoint2D(u: $1.0, v: $1.1)]
    }.flatMap{ $0 }

    static let radius:Double = 2/3

    let perm:[Int],
        perm2d:[Int],
        amplitude:Double,
        frequency:Double

    init(amplitude:Double, frequency:Double, seed:Int = 0)
    {
        self.amplitude = amplitude
        self.frequency = frequency
        (self.perm, self.perm2d) = table(seed: seed, hashes_2d: SuperSimplex.n_hashes_2d)
    }

    func evaluate(_ x:Double, _ y:Double) -> Double
    {
        let x:Double = x * self.frequency,
            y:Double = y * self.frequency
        // transform our (x, y) coordinate to (u, v) space
        let stretch_offset:Double = (x + y) * STRETCH_2D,
            u:Double = x + stretch_offset,
            v:Double = y + stretch_offset

        //         (0, 0) ----- (1, 0)
        //           / \    A    /
        //         /     \     /                ← (x, y) coordinates
        //       /    B    \ /
        //    (0, 1) ----- (1, 1)

        //             (-1, 0)
        //                | \
        //                |    \
        //                |   C   \
        //  (0, -1) -- (0, 0) -- (1, 0)
        //       \   D   | \   A   | \
        //          \    |    \    |    \       ← (u, v) coordinates
        //             \ |   B   \ |   E   \
        //            (0, 1) -- (1, 1) -- (2, 1)
        //                  \   F   |
        //                     \    |
        //                        \ |
        //                       (1, 2)

        // use the (u, v) coordinates to bin the triangle
        let ub:Int = floor(u),
            vb:Int = floor(v)

        // get relative offsets from the top-left corner of the square (in (u, v) space)
        let du0:Double = u - Double(ub),
            dv0:Double = v - Double(vb)

        let a:Int = du0 + dv0 > 1 ? 1 : 0
        let vertex_index:Int = a << 2 |
            Int((2*du0 - dv0 - Double(a))*0.5 + 1) << 3 |
            Int((2*dv0 - du0 - Double(a))*0.5 + 1) << 4
        /*
            This bit of code deserves some explanation. OpenSimplex/SuperSimplex
            always samples four vertices. Which four depends on what part of the A–B
            square our (x, y) → (u, v) sample coordinate lands in. Think of each
            triangular slice of that square as being further subdivided into three
            smaller triangles.

            ************************
            **  *           a     **
            *  * *     *       *   *
            *   *   *      *       *
            *    *    *   b   *  c *
            *     *   e  *     *   *
            *  d   *       *    *  *
            *    *      *    *   * *
            *  *            *  *  **
            **        f           **
            ************************

            Obviously we’re running up against the bounds on what can be explained
            with an ASCII art comment. Hopefully you get the idea. We have 6 regions,
            counter-clockwise in the upper-right triangle from the top, regions a, b,
            and c, and clockwise in the lower-left triangle from the left, regions
            d, e, and f.

            Region a borders region C, so it gets the extra vertices (-1, 0) and (1, 0)
            in addition to (0, 0), and (1, 1), which every region samples. Region c
            borders region E, so it gets the extra vertices (1, 0) and (2, 1). Region b
            doesn’t border any exterior region, so it just gets the other two vertices
            of the square, (0, 1) and (1, 0). Regions d and f are the same as a and c,
            except they border D and F, respectively. Region e is essentially the same
            as region b.

            This means that we effectively have five different vertex selection outcomes.
            That means we need no less than three bits of information, i.e., three tests
            to determine where we are. Two such tests could be:

            (0, 0) -------------- (1, 0)
                | \        \       |
                |  \        \      |
                |   \        \     |
                |    \        \    |
                |     \        \   |
                |      \        \  |
                |       \        \ |
            (1, 0) -------------- (1, 1)
                       v = 2u    v = 2u - 1

            and

            (0, 0) -------------- (1, 0)
                |   -              |
                |       -          |
                |           -      |
                |               -  |
    u = 2v - 1  |   -              |  u = 2v
                |       -          |
                |           -      |
            (1, 0) -------------- (1, 1)

            Each test has two lines. How do we pick which one? We use a third test:

            (0, 0) -------------- (1, 0)
                |              /   |
                |            /     |
                |          /       |
                |        /         |
                |      /           |
                |    /  u + v = 1  |
                |  /               |
            (1, 0) -------------- (1, 1)

            If we’re in the top left, we use the lines without the offsets, otherwise
            we use the ones with the -1 offset. That’s where the `- Double(a)` term
            comes from.
        */

        // get the relative offset from (0, 0)
        let squish_offset:Double = (du0 + dv0) * SQUISH_2D,
            dx0:Double = du0 + squish_offset,
            dy0:Double = dv0 + squish_offset

        var z:Double = 0
        for point in SuperSimplex.points_2d[vertex_index ..< vertex_index + 4]
        {
            // get the relative offset from *that* particular point
            let dx:Double = dx0 - point.dx,
                dy:Double = dy0 - point.dy
            z += self.gradient(u: ub + point.u, v: vb + point.v, dx: dx, dy: dy)
        }
        return self.amplitude * z
    }
}

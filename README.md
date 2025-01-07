# slick

**slick** is a simple two-dimensional swept collision library with support for polygons inspired by the simplicity and robustness of [bump.lua](https://github.com/kikito/bump.lua).

* Supports polygon-polygon, circle-polygon, and circle-circle collisions.
* All shapes are swept, meaning tunneling isn't possible.
* Allows combining multiple shapes for one entity.
* Simple "polygon mesh" shape that takes pretty much any contour data (including degenerate contour data) and produces a valid series of polygon shapes.
* "Game-istic" collision handling and response instead of realistic, physics-based collision handling and response.
* Rectangle, line segment, ray, circle, and point queries against the world.

There are no dependencies (other than the demo and debug drawing code using LÖVE). It can be used from any Lua 5.1-compatible environment. There are certain optimizations available when using LuaJIT, but fallbacks are used in vanilla Lua environments.

**slick** is good for platformers, top-down, and any other sort of game where you need rotated objects and circles/polygons for collision. If you're making a Mario game or Zelda game where everything is an axis-aligned rectangle, then `bump` is probably better.

**slick** is **not** good for games that need realistic physics responses. The library has no concepts of physical properties like acceleration, mass, or angular velocity. If you need more realistic physics, then try Box2D or something.

## Example

```lua
local slick = require("slick")

local w, h = 800, 600
local world = slick.newWorld(w, h)

local player = { type = "player" }
local level = { type = "level" }

world:add(player, w / 2, h / 2, slick.newBoxShape(0, 0, 32, 32))
world:add(level, 0, 0, slick.newShapeGroup(
    -- Boxes surrounding the map
    slick.newBoxShape(0, 0, w, 8), -- top
    slick.newBoxShape(0, 0, 8, h), -- left
    slick.newBoxShape(w - 8, 0, 8, h), -- right
    slick.newBoxShape(0, h - 8, w, 8), -- bottom
    -- Triangles in corners
    slick.newPolygonShape({ 8, h - h / 8, w / 4, h - 8, 8, h - 8 }),
    slick.newPolygonShape({ w - w / 4, h, w - 8, h / 2, w - 8, h }),
    -- Convex shape
    slick.newPolygonMeshShape({ w / 2 + w / 4, h / 4, w / 2 + w / 4 + w / 8, h / 4 + h / 8, w / 2 + w / 4, h / 4 + h / 4, w / 2 + w / 4 + w / 16, h / 4 + h / 8 })
))

local goalX, goalY = w / 2, -1000
local actualX, actualY, cols, len = world:move(player, goalX, goalY)

-- Prints "Attempted to move to 300, -1000 but ended up at 300, 8 with 1 collision(s).
if len > 0 then
    print(string.format("Attempted to move to %d, %d but ended up at %d, %d with %d collision(s)", goalX, goalY, actualX, actualY, len))
else
    print(string.format("Moved to %d, %d.", actualX, actualY))
end

-- Prints "Collision with level."
for i = 1, len do
    print("Collision with %s.", cols[i].other.type)
end

world:remove(player)
world:remove(level)
```

## Introduction

### Adding & removing items
First, require **slick**:

```lua
local slick = require("slick") -- or wherever you put it; e.g., if you put it in `./libs/slick` then use `require("libs.slick")`
```

Next, create a new world:

```lua
-- width & height are suggestions but try and be as close as possible to the world size
-- slick uses a quad tree, and the better fitting the quad tree the faster collisions will be.
-- by default, the top left of the world is (0, 0) but this can be changed (see documentation for `slick.newWorld`)
-- The quad tree dimensions will expand if an entity goes outside the world by default, but it might create a one-sided quad tree.
local world = slick.newWorld(width, height)
```

Then, add an item to the world:

```lua
world:add(item, x, y, shape)

-- OR
world:add(item, transform, shape)
```

* `item` can be any value but ideally is a table representing the entity
* `x` and `y` are the location of `item` in the world, **or** `transform` is a `slick.geometry.transform` object with position, rotation, scale, and offset components
* `shape` is a `slick.collision.shapelike` object created by functions like `slick.newPolygonShape`, `slick.newBoxShape`, `slick.newCircleShape`, etc

If `item` already exists in the world, you will receive an error. You can use `slick.world.has` to check if the world already contains `item`.

`slick.world.add` returns a `slick.entity` for advanced usage. Please see `slick.entity` documentation for more. **Entity** will refer to an `item` that is located in the world.

To remove an item from the world at some point:

```lua
world:remove(item)
```

To update the position and shape of an entity:

```lua
-- `shape` is optional in both overloads

world:update(item, x, y, shape)

-- OR
world:update(item, transform, shape)
```

Be warned: this will instantly teleport an entity to the position or change its shape without any collision checks.

To move an entity:

```lua
local actualX, actualY, collisions, count = world:move(item, goalX, goalY, function(item, other, shape, otherShape)
    return "slide"
end)
```

This method will attempt to move the entity from its current position to `(goalX, goalY)`. It will perform a swept collision and iteratively resolve collisions until there are no more collisions or a max "bounce" count has been reached (see documentation for `slick.newWorld`). The `(actualX, actualY)` return values are the position of the entity in the world after the movement attempt.

The (optional) filter function can change the behavior of the built-in collision responses. You can return a collision response handler based on `item`, `other`, or even the collision shapes `shape` and `otherShape`. By default, collisions are treated as `"slide"` if no filter function is provided.

There are currently three built-in collision responses:

* `"slide"`: "slides" along other entities
* `"touch"`: stops moving as soon as a collision between entities occurs
* `"cross"`: goes through another entity as if it the moving entity is a ghost

`collisions` is a list of `slick.worldQueryResponse` of all the collisions that were handled during the movement and `count` is equal to `#collisions`. Some fields of note are:

* `item`, `entity`, `shape`: The item, entity, and shape of the moving entity.
* `other`, `otherEntity`, `otherShape`: The item, entity, and shape of the entity we collided with.
* `normal.x. normal.y`: The surface normal of the collision.
* `depth`: The penetration depth. Usually this is 0 since collisions are swept, but other methods that return `slick.worldQueryResponse` for overlapping objects might have a `depth` value greater than zero.
* `offset.x, offset.y`: The offset from the current position to the new position.
* `touch.x, touch.y`: This is the sum of the current position before impact and `offset.x, offset.y`
* `contactPoint.x, contactPoint.y`: The contact point closest to the center of the entity. For all contact points, use the `contactPoints` array.

See `slick.worldQueryResponse` documentation for more

**Note:** unlike `bump.lua`, since an entity can be composed of multiple shapes, there might be multiple pairs of (`item`, `other`) during a movement where the `shape`/`otherShape` is different.

For an example player movement method, try this:

```lua
local function movePlayer(player, dt)
  local goalX, goalY = player.x + dt * player.velocityX, player.y + dt * player.velocityY
  player.x, player.y = world:move(player, goalX, goalY)
end
```

For more advanced documentation about these methods, see below.

## Documentation

Below is an API reference for **slick**.

### `slick.world`

* `slick.newWorld(width: number, height: number, options: slick.options?): slick.world`
  
  Creates a new `slick.world`. `width` and `height` are the width and height of the world. By default, the upper left corner of the world is (0, 0) and the bottom right corner is (`width`, `height`).

  `options` is an optional table with the following fields:
    * `maxBounces`: The max number of bounces to perform during a movement. The higher, the more accurate crowded areas might be. The default should be good games using pixels as units.
    * `quadTreeX`, `quadTreeY`: The upper-left corner of the quad tree. Defaults to (0, 0).
    * `quadTreeMaxLevels`: The maximum depth of the quad tree. Note: this value will automatically go up if the quad tree expands.
    * `quadTreeMaxData`: The maximum amount of leaf nodes.
    * `quadTreeExpand`: Expand the quad tree as objects exceed the current boundaries. This defaults to true. If false and an object is outside the quad tree, an error will be raised.
    * `epsilon`: the "precision" of certain calculations. The default precision is good for games with pixels as units. This defaults to `slick.util.math.EPSILON`.
    * `sharedCache`: This is an optional `slick.cache` to use for this world. This is a very advanced feature and is only useful if you have multiple `slick.world` objects and need to share things like the triangulator between them. To create a cache
    * `debug`: slows down certain things but ensures robustness of simulation. This is `false` by default. **Only should be enabled if trying to submit a detailed bug report or doing development on slick.**
  
  There is no one-size-fits-all for the quad tree options. You will have to tweak the values on a per-game, and perhaps even per-level, basis, for maximum performance.

* `slick.world:add(item, x: number, y: number, shape: slick.collision.shapelike): slick.entity` **or** `slick.world:add(item, transform: slick.geometry.transform, shape: slick.collision.shapelike): slick.entity`

  Adds a new entity to the world with `item` as the handle at the provided location (either (`x`, `y`) or `transform`). If `item` already exists, this method will raise an error. For valid shapes, see `slick.collision.shapelike` below. For `transform` properties, see `slick.geometry.transform` below.

* `slick.world:has(item): boolean`
  
  Returns true if `item` exists in the world; false otherwise. Remember: it is an error to `remove` an item that is **not** in the world and it is an error to `add` an item that already exists in the world.

* `slick.world:get(item): slick.entity`

  Gets the `slick.entity` represented by `item`. Will return `nil` if no entity is represented by `item` (i.e., `item` **was not** added to the world). See `slick.entity` for usage and properties.

* `slick.world:update(item, x: number, y: number, shape: slick.collision.shapelike?): number, number` **or** `slick.world:update(item, transform: slick.geometry.transform, shape: slick.collision.shapelike?): number, number`

  Instantly moves the entity represented by `item` to the provided location or transforms the entity by the provided transform. Optionally you can change the shape of the entity by passing in a `slick.collision.shapelike`. The shape does not change if no `shape` is provided.

* `slick.world:move(item, goalX: number, goalY: number, filter: slick.worldFilterQueryFunc?, query: slick.worldQuery?): number, number, slick.worldQueryResponse[], number, slick.worldQuery`
  
  Attempts to move the entity represented by `item` to the provided location. If there is anything blocking movement at some point, then the returned (`actualX`, `actualY`) will be different from the goal. Returns the actual location; an array of collision responses; the length of said collision response array; and the `slick.worldQuery` used during the movement.
  
  **For advanced usage**, by passing in a `slick.worldQuery`, you can save on garbage creation. You can create a `slick.worldQuery` using `slick.newWorldQuery(world)` and re-use it between calls that accept a `query`. Keep in mind **any** collision responses or other query properties from the previous usage of the query **will** be invalidated. This includes point fields like `touch`.

  `slick.world.move` is essentially a wrapper around `slick.world.check` and `slick.world.update`. First, the method attempts a movement, and then moves to the last safe position given the goal.

* `slick.world:check(item, goalX: number, goalY: number, filter: slick.worldFilterQueryFunc?, query: slick.worldQuery?): number, number, slick.worldQueryResponse[], number, slick.worldQuery`

  Performs a collision movement check, but does not update the location of the entity represented by `item` in the world. This method is otherwise identical to `slick.world.move`.

  For advanced usage with the `query` parameter, see `slick.world.move` above.

* `slick.world:project(item, x: number, y: number, goalX: number, goalY: number, filter: slick.worldFilterQueryFunc?, query: slick.worldQuery?): slick.worldQueryResponse[], number, slick.worldQuery`

  Projects `item` as if it is currently at (`x`, `y`) and is moving towards (`goalX`, `goalY`). Returns all potential collisions, sorted by time of collision.

  For advanced usage with the `query` parameter, see `slick.world.move` above.

  This can be used to build custom collision response handlers and other advanced functionality.

* `slick.world:push(item, filter: slick.worldFilterQueryFunc?, x: number, y: number, shape: slick.collision.shapelike): number, number`

  Attempts to "push" the entity represented by `item` out of any other entities filtered by `filter`. This can be used, for example, when placing items in the world. Normally, if an entity is **not** overlapping another entity currently, it will **never** overlap another entity. But if you're placing an item due to a mouse click, you might want to use this (or use a query and prevent placing an entity if it doesn't fit!).

  The entity will **never** overlap another entity filtered by `filter` **but** it might go somewhere you wouldn't expect! If you place an entity inside a wall, it will try and take the shortest route out, but this is not guaranteed bases on the location of the object and the other entities.

* `slick.world:rotate(item, angle: number, rotateFilter: slick.worldFilterQueryFunc, pushFilter: slick.worldFilterQueryFunc, query: slick.worldQuery?)`

  This method will instantly rotate an object to `angle` (in radians) and then attempt to push all filtered entites **out** of the way. **There is no swept collisions for rotations!** So if rotations are massive, call this method multiple times in increments of the rotation.

  `rotateFilter` is used to filter all entities that will be pushed (via `slick.world.push`) out of the way of the rotating `item`. `pushFilter` is used to determine what entities, when pushing via `slick.world.push`, will affect the push. You might want all items of type `thing` to be affected by the rotation of `item`; but then only have the `thing` items by pushed by level geometry (and, probably, the rotating `item`).

  See the `moveGear` function in the demo for an example usage of this.

* `slick.world:queryPoint(x: number, y: number, filter: slick.defaultWorldShapeFilterQueryFunc?, query: slick.worldQuery): slick.worldQueryResponse[], number, slick.worldQuery`

  Finds all entities that the point (`x`, `y`) is inside.

* `slick.world:queryRay(x: number, y: number, directionX: number, directionY: number, filter: slick.defaultWorldShapeFilterQueryFunc?, query: slick.worldQuery): slick.worldQueryResponse[], number, slick.worldQuery`

  Finds all entities that the ray intersects.

* `slick.world:querySegment(x1: number, y1: number, x2: number, y2: number, filter: slick.defaultWorldShapeFilterQueryFunc?, query: slick.worldQuery): slick.worldQueryResponse[], number, slick.worldQuery`

  Finds all entities that the line segment intersects.

* `slick.world:queryRectangle(x: number, y: number, width: number, height: number, filter: slick.defaultWorldShapeFilterQueryFunc?, query: slick.worldQuery): slick.worldQueryResponse[], number, slick.worldQuery`

  Finds all entities that the rectangle intersects.

* `slick.world:queryCircle(x: number, y: number, radius: number, filter: slick.defaultWorldShapeFilterQueryFunc?, query: slick.worldQuery): slick.worldQueryResponse[], number, slick.worldQuery`
  
  Finds all entities that the circle intersects.

* `slick.worldFilterQueryFunc`

  This type represents a function (or table with a `__call` metatable method) that is used for `slick.world.project`, `slick.world.move`, etc to filter entities.

  The signature of this function is:

  `fun(item: any, other: any, shape: slick.collision.shape, otherShape: slick.collision.shape): string | slick.worldVisitFunc | boolean`

    * `item`: the entity being moved, projected, etc.
    * `other`: the entity `item` may potentially collide with.
    * `shape`: the shape of the entity potentially colliding with `otherShape`.
    * `otherShape`: the shape of `other` that might be colliding with `shape`.

  This method can return **one of** three values:

    * `string`: a name of a collision response handler (e.g., `"slide"`)
    * `slick.worldVisitFunc`: **Advanced usage.** A method that will be called if `item` and `other` collide. See `slick.worldVisitFunc` for usage.
    * `boolean`: false to prevent a collision between `item` and `other`; true to use the default collision response handler (`"slide"`)

* `slick.worldShapeFilterQueryFunc`

  This type represents a function (or table with a `__call` metatable method) that is used for the query methods (like `slick.world.queryPoint` and `slick.world.queryRay`) to filter entities.

  The signature of this function is:

  `fun(item: any, shape: slick.collision.shape): boolean`

  * `item`: the potentially overlapping item with the query shape.
  * `shape`: the potentially overlapping shape of the entity represented by `item`

* `slick.worldVisitFunc`

  This represents a "visitor" function (or table with a `__call` metatable method) that is called when two entities collide, but before the collision response happens.
  
  The signature of this function is:
  
  `fun(item: any, world: slick.world, query: slick.worldQuery, response: slick.worldQueryResponse, x: number, y: number, goalX: number, goalY: number): string`

  The return value is expected to be a collision response handler; if nothing is returned, this defaults to `slide`.

  Be aware that, e.g., during a `move`, the same `shape` and `otherShape` might be visited more than once to resolve a collision.

* `slick.worldQuery`
  
  This represents a query against the world. It has a single field, `results`, which is an array of `slick.worldQueryResponse`. `results` will be sorted by first time of collision to last time of collision.

  When re-using a `slick.worldQuery`, **all data from the previous usage will be considered invalid**. This is because `slick.worldQuery` re-uses the previous `slick.worldQueryResponse` objects.

* `slick.worldQueryResponse`:
  
  This represents a single collision of two shapes from two different entities.

  This object has the following fields:

    * `item`, `entity`, `shape`: The item, entity, and shape of the moving entity.
    * `other`, `otherEntity`, `otherShape`: The item, entity, and shape of the entity we collided with.
    * `normal.x. normal.y`: The surface normal of the collision.
    * `depth`: The penetration depth. Usually this is 0 since collisions are swept, but other methods that return `slick.worldQueryResponse` for overlapping objects might have a `depth` value greater than zero.
    * `offset.x, offset.y`: The offset from the current position to the new position.
    * `touch.x, touch.y`: This is the sum of the current position before impact and `offset.x, offset.y`
    * `contactPoint.x, contactPoint.y`: The contact point closest to the center of the entity. For all contact points, use the `contactPoints` array.
    * `segment.a, segment.b`: The points of the segment that was collided with.


### `slick.collision.shapelike` and shape definitions

A `slick.collision.shapelike` can be a polygon, circle, box, or shape group. An entity can have multiple shapes via shape groups.

When adding or updating an `item` to the world, you can provide a `slick.collision.shapeDefinition`. The complete list of of shape definitions are:

* `slick.newBoxShape(x: number, y: number, w: number, h: number)`

  A rectangle with its top-left corner relative to the entity at (`x`, `y`). The rectangle will have a width of `w` and a height of `h`.

  For example, if an entity is at `100, 150` and the box is created at `10, 10`, then the box will be at `110, 160` in the world.

* `slick.newCircleShape(x: number, y: number, radius: number)`

  A rectangle with its center relative to the entity at (`x`, `y`). The rectangle will have a radius of `radius`.

* `slick.newPolygonShape(vertices: number[])`

  Creates a polygon from a list of vertices. The vertices are in the order `{ x1, y1, x2, y2, x3, y3, ..., xn, yn }`.

  The polygon **must** be a valid convex polygon. This means no self-intersections; all interior angles are less than 180 degrees; no holes; and no duplicate points. To create a polygon that might self-intersect, have holes, or be concave, use `slick.newPolygonMeshShape`.

* `slick.newPolygonMeshShape(...contours: number[])`

  Creates a polygon mesh from a variable number of contours. The contours are in the form `{ x1, y1, x2, y2, x3, y3, ..., xn, yn }`.
  
  By default, **slick** will clean up the input data and try to produce a valid polygonization no matter how bad the data is. If the data does not result in a valid polygonization, then an empty shape is returned.

  Polygons can self-intersect; be concave; have holes; have duplicate points; have collinear edges; etc. However, the worse the quality of the input data, the longer the polygonization will take. Similarly, the more contours / points in the contour data, the longer the triangulation/polygonization will take.

* `slick.newShapeGroup(...shapes: slick.collision.shapeDefinition)`
  
  Create a group of shapes. Useful to put all level geometry in one entity, for example, or make a "capsule" shape for a player out of two circle and a box (or things of that nature).

### `slick.geometry.transform`

A `slick.geometry.transform` stores position, rotation, scale, and an offset. In methods that take a transform, you can usually pass in a position tuple or a transform unless otherwise noted.

* **position**: the location of the transform in world space.
* **rotation**: the rotation of the transform.
* **scale:** how much to scale the entity by.
* **offset:** sets the origin of the transform; e.g., if your entity is a shape with at (0, 0) with a size of (32, 32), then setting origin to (16, 16) will make the box  centered around the position.

To create a transform:

* `slick.newTransform(x: number?, y: number? = 0, rotation: number? = 0, scaleX: number? = 1, scaleY: number? = 1, offsetX: number? = 0, offsetY: number? = 0)`

  Creates a transform. Any values not provided will use the defaults.

To update an existing transform object:

* `slick.geometry.transform:setTransform(x: number?, y: number?, rotation: number?, scaleX: number?, scaleY: number?, offsetX: number?, offsetY: number?)`

  Updates the transform. Any values not provided will use the existing values.

To transform a point:

* `slick.geometry.transform:transformPoint(x: number, y: number): number, number` and `slick.geometry.transform:transformPoint(x: number, y: number): number, number`
  
  Transforms a point into or out of the transform's coordinate system.

* `slick.geometry.transform:transformNormal(x: number, y: number): number, number`
  
  Transforms a normal by **only** the rotation and scaling portions of the transform.

### Advanced Usage

#### `slick.geometry.triangulation.delaunay`

**slick** comes with a constrained 2D Delaunay triangulator. This triangulator can also clean-up input data and polygonize the output data.

* `slick.geometry.triangulation.delaunay.new(options: slick.geometry.triangulation.delaunayOptions?)`

  Creates a new Delaunay triangulator with the provided options. `options` is optional and sensible defaults are used, but you can provide:

  * `epsilon: number`: an epsilon precision value used for comparisons. The default value works for games using pixels as units. The default value is `slick.util.math.EPSILON`.
  * `debug: boolean`: run expensive debugging logic. The default is false. Only need this for development or error reports.

* `slick.geometry.triangulation.delaunay:cleanup(points: number[], edges: number[], userdata: any[], options: slick.geometry.triangulation.delaunayCleanupOptions?, outPoints: number[]?, outEdges: number[]?, outUserdata: any[]): number[], number[], outUserdata: any[]`

  Cleans up input point/edge data. This dissolves duplicate points/edges and also splits intersecting edges/dissolves collinear edges.

  * `points`: expected to be in the format `{ x1, y1, x2, y2, x3, y3, ..., xn, yn }`
  * `edges`: expected to be in the format `{ a1, b1, a2, b2, ... an, bn }`, indexing into `points`. Can be empty.
  * `userdata`: option userdata mapping to `points`; used by `dissolve` and `intersect` callbacks.
  * `options`: allows customizing cleanup and providing callbacks (`dissolve` and `intersect`; see below) when dissolving points or splitting edges (and thus creating new points).
  * `outPoints`, `outEdges`, `outUserdata`: **optional** arrays to store the resulting clean point, edge, and userdata in. If not provided, will create new arrays. **Keep in mind these arrays will be cleared!**

  Returns, in order, the cleaned up `points`, `edges`, and (optionally) `userdata`. If `outPoints`, `outEdges`, and/or `outUserdata` were provided, those will be returned instead.

  You can provide a `dissolve` and `intersect` method to handle splitting edges and dissolving vertices.

  ##### Dissolve

  `dissolve` is called when a point is dissolved due to duplications. It is a function in the form:

  `fun(dissolve: slick.geometry.triangulation.dissolve)`

  The instance of `slick.geometry.triangulation.dissolve` passed in has the following properties:

  * `point.x, point.y`: the location of the point
  * `index`: the index of the point in the points array (might point to a new point outside the bounds of the original array; see `intersect`)
  * `userdata`: the userdata associated with the point being dissolved (optional)

  ##### Intersect

  `intersect` is called when an edge is split by another edge. (**note:** an edge that is split by a collinear point does invoke `intersect`). It is a function in the form:

  `fun(dissolve: slick.geometry.triangulation.intersection)`

  The instance of `slick.geometry.triangulation.intersection` passed in has the following properties:

  * `a1.x, a1.y` and `b1.x, b1.y`: points that form the first edge.
  * `a1Userdata` and `b1Userdata`: the userdata associated with points `a1` and `b1`
  * `a1Index` and `b1Index`: indices of points that form the first edge
  * `delta1`: the delta of intersection for the `a1 -> b1` segment.
  * `a2.x, a2.y` and `b2.x, b2.y`: points that form the second edge.
  * `a2Userdata` and `b2Userdata`: the userdata associated with points `a2` and `b2`
  * `a2Index` and `b2Index`: indices of points that form the second edge
  * `delta2`: the delta of intersection for the `a2 -> b2` segment.
  * `result`: the resulting point of intersection
  * `resultIndex`: the new index of the point of intersection
  * `resultUserdata`: any userdata generated from the intersection (assign a new value to automatically store in the resulting `outUserdata`)

  You can use this data to create userdata for the new point. For example, if points have a color userdata, you can use the color calculated from the intersections of the edges using the existing userdata and `delta1`/`delta2` values to interpolate the existing colors (e.g., using bilinear interpolation).

* `slick.geometry.triangulation.delaunay:triangulate(points: number[], edges: number, options: slick.geometry.triangulation.delaunay?, result: number[][], polygons: number[][]: number[][], number, number[][], number`

  Performs a constrained Delaunay triangulation of the provided points and edges. Edges must not intersect and there must not be any duplicate points. Use `slick.geometry.triangulation.delaunay.clean` to clean up untrusted data (e.g., a drawing from a user).

  * `points`: expected to be in the format `{ x1, y1, x2, y2, x3, y3, ..., xn, yn }`
  * `edges`: expected to be in the format `{ a1, b1, a2, b2, ... an, bn }`, indexing into `points`. Can be empty; if empty, will just be a Delaunay triangulation (i.e., not constrained).
  * `options`: a table of options, with the following values and defaults:
    * `refine: boolean = true`: perform a Delaunay triangulation; without this, the triangulation might not be suitable for physics, rendering, etc, but it will be faster.
    * `interior: boolean = true`: materialize interior edges. The even-odd fill rule is used by the triangulator. Interior edges are those defined by odd winding numbers.
    * `exterior: boolean = false`: materialize exterior edges. Like for `interior`, the even-odd fill rule is used by the triangulator. Exterior edges are those with even winding numbers.
    * `polygonization: boolean = true`: generates an optimistic (but not necessarily ideal) polygonization of the triangles. Each polygon produced is guaranteed to be convex.
  * `result`: the resulting array of triangles. If an existing array of triangles is used, existing triangles will be re-used. If more triangles are necessary, then they will be added to the end of the array. The actual number of triangles generated is returned by this method.
  * `polygons`: the resulting array of polygons. See `result` for behavior.

  Returns, in order, the array of triangles; the number of triangles generated; the array of polygons (if the `polygonization` option is true); and the number of polygons generated.

##### Example

Given this data:

```lua
local inputPoints = {
    -- Exterior points
    0, 0,
    200, 0,
    200, 200,
    0, 200,

    -- Interior points
    50, 50,
    150, 50,
    150, 150,
    50, 150,

    -- Duplicate point
    0, 0
}

local inputEdges = {
    -- Exterior edge
    1, 2,
    2, 3,
    3, 4,
    4, 1,

    -- Interior edge
    5, 6,
    6, 7,
    7, 8,
    8, 5,

    -- Duplicate edge
    1, 2,

    -- Invalid edge
    5, 5
}
```

You can clean it up and triangulate it like so:

```lua
local slick = require("slick")
local triangulator = slick.geometry.triangulation.delaunay.new()
local cleanPoints, cleanEdges = triangulator:clean(inputPoints, inputEdges)
local triangles, triangleCount = triangulator:triangulate(cleanPoints, cleanEdges)

for i = 1, triangleCount do
  local triangle = triangles[i]

  -- Convert the triangle index into a point index
  local a = (triangle[1] - 1) * 2 + 1
  local b = (triangle[2] - 1) * 2 + 1
  local c = (triangle[3] - 1) * 2 + 1

  love.graphics.polygon("line", cleanPoints[a], cleanPoints[a + 1], cleanPoints[b], cleanPoints[b + 1], cleanPoints[c], cleanPoints[c + 1])
end
```

## License

**slick** is licensed under the MPL. See the `LICENSE` file. This means you can use it in your projects pretty much however you want, but any modifications to **slick** source files must be returned to the community.
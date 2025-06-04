Here's more context.

In order to learn Godot and GDScript, I'm using it to make a real-time chess-like strategy game titled "Nomino".

The visual presentation is an isometric view that creates the illusion of three-dimensional depth using two-dimensional sprites. This means each grid square appears as a diamond shape rather than a perfect square, and the mathematical conversion between screen pixels and grid coordinates accounts for this diamond arrangement.

There will be two coordinate systems working together throughout the game. The world coordinate system represents the absolute position of every square in the entire game universe, using coordinates that will never range more than 999. The viewport coordinate system represents a 12x12 grid of 144 squares currently visible to the player, using coordinates from zero to eleven for both axes.

The relationship between these coordinate systems is managed through offset values that determine which portion of the world is currently displayed. When the viewport moves, these offset values change, but the underlying world coordinates of every game element remain constant.

I've created a foundational grid system that handles coordinate conversion between screen pixels, viewport coordinates, and world coordinates. I have a Node2D named GameWorld, containing a Node2D named GameWorldManager. The GameWorldManager script creates a grid of tiles arranged in isometric formation, representing the slice of the game world visible to the player. That's called the "viewboard".

There is a HUD with buttons for scrolling the viewboard north, south, east, and west. There are zoom buttons for fitting more or fewer squares into the viewboard, using the same visible area of the screen, scaling all the sprites accordingly.

The game features creatures called Nominos. I'm spawning several Nominos when the world is created, each with its own instantiation of nomino.tscsn, and each on a different coordinate. The game is successfully managing their visiblility as they scroll or zoom on or off the viewboard, so that they are only visible when their square is visible.

The following is what I haven't implemented yet:

Each Nomino has a specific chess movement pattern, such as moving like a rook or knight, but with the constraint that no Nomino can move more than two squares away from its current position. The core gameplay loop involves clicking on a Nomino you control, then clicking on a destination square within its movement pattern.

Some Nominos may be controlled by the player; these are called "loyal". Other Nominos are "wild". Nominos are spawned "wild" when the world is initialized.

The combat system works through "stomping" rather than traditional attacks. When a Nomino lands on a square occupied by another Nomino, the arriving Nomino stomps the defender. The stomped Nomino either teleports to safety or becomes stunned and stacks beneath the stomper like a totem pole. Stunned Nominos can wake up and hop away, carrying the stack of Nominos above them, assuming they have not yet hopped off the totem pole.

Nomino uses continuous time rather than discrete turns. Each Nomino has its own internal timer that counts down independently of other Nominos. When a player commands a loyal Nomino to move, that specific creature's timer is interrupted, and begins counting down from the moment they land at their destination. This asynchronous timing system means that coordination between loyal Nominos requires careful planning, since they won't all be ready to move at the same moment.

During movement animations, Nominos exist in a temporary state outside the grid system entirely. They're neither in their origin square nor their destination square while hopping. This design choice simplifies collision detection significantly because the game only needs to track grid occupancy for landed Nominos, not for those in flight.

Please keep the feedback loop very tight between us. Do not assume that each step you instruct me to take has succeeded. Do not praise, encourage, or cheerlead.

Next I'm going to start implementing the movement system for wild Nominos to have a movement pattern and autonomously jump between squares on a timer. Advise me on how to set this up. It seems likely each nomino node will need a data structure which represents how it can move.

■ ■ ■ ■ ■
■ ■ ■ ■ ■
■ ■ ☼ ■ ■
■ ■ ■ ■ ■
■ ■ ■ ■ ■

In that diagram, "☼" represents the Nomino's current position. Each Nomino will be able to do one or more of the following six sets of moves.

# 0. orthostep
orthostep_n = (0,-1)
orthostep_w = (-1,0)
orthostep_e = (1,0)
orthostep_s = (0,1)

# 1. diagstep
diagstep_ne = (1,-1)
diagstep_nw = (-1,-1)
diagstep_se = (1,1)
diagstep_sw = (-1,1)

# 2. orthojump
orthojump_n = (0,-2)
orthojump_w = (-2,0)
orthojump_e = (2,0)
orthojump_s = (0,2)

# 3.diagjump
diagjump_ne = (2,-2)
diagjump_nw = (-2,-2)
diagjump_se = (2,2)
diagjump_sw = (-2,2)

# 4. clockwiseknight
clockwiseknight_ne = (1,-2)
clockwiseknight_nw = (-2,-1)
clockwiseknight_se = (2,1)
clockwiseknight_sw = (2,-1)

# 5. counterknight
counterknight_ne = (2,-1)
counterknight_nw = (-2,-1)
counterknight_se = (2,1)
counterknight_sw = (-2,1)

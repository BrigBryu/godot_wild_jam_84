class_name GameConstants
extends Resource

## Global game constants to eliminate magic numbers
## All values are properly documented and typed

# === SCREEN AND BOUNDARIES === [WIDE BEACH - FIXED: more sand AND water]
const SCREEN_WIDTH: float = 10240.0  # 8x width - wide beach to explore
const SCREEN_HEIGHT: float = 4320.0  # 6x height - double sand & water areas
const SHORE_Y: float = 3000.0  # Shore line moved DOWN - more sand area above (0-3000)
const OCEAN_EDGE_Y: float = 3200.0  # Ocean barrier - water area below shore (3000-3200)
const BOUNDARY_BUFFER: float = 80.0  # Buffer from screen edges

# === PLAYER PHYSICS === [SCALED 8x for large world]
const PLAYER_SPEED: float = 1600.0  # 8x from 200.0
const PLAYER_ACCELERATION: float = 10.0  # Keep unchanged (lerp factor)
const PLAYER_FRICTION: float = 10.0  # Keep unchanged (lerp factor)
const PLAYER_WAVE_INFLUENCE: float = 1.8  # Keep unchanged (multiplier)
const PLAYER_INTERACTION_DISTANCE: float = 240.0  # 8x from 30.0
const SOFT_BOUNDARY_DISTANCE: float = 160.0  # 8x from 20.0
const RESISTANCE_FORCE: float = 800.0  # 8x from 100.0

# === WAVE PHYSICS === [SCALED for wide beach world]
const DEFAULT_SURGE_DISTANCE: float = 300.0  # Moderate wave run-up for compact beach
const DEFAULT_WAVE_SPEED: float = 400.0  # Reasonable wave speed for wide world
const DEFAULT_WAVE_HEIGHT: float = 200.0  # Modest wave height for beach interaction
const WAVE_PAUSE_DURATION: float = 0.5  # Keep unchanged (time in seconds)
const WAVE_RETREAT_DURATION: float = 4.0  # Keep unchanged (time in seconds)
const SURGE_DECELERATION: float = 600.0  # Moderate deceleration
const SURGE_FORCE: float = -1200.0  # Reasonable upward push force
const RETREAT_FORCE: float = 1000.0  # Reasonable downward pull force

# === WAVE VISUALS === [SCALED 8x for large world]
const FOAM_EDGE_WIDTH: float = 96.0  # 8x from 12.0 - Width of foam texture edge (pixels)
const FOAM_CREST_OFFSET: float = 56.0  # 8x from 7.0 - Foam position offset from wave crest (pixels)
const SPAWN_EDGE_PADDING: float = 160.0  # 8x from 20.0 - Padding from screen edges for spawning (pixels)
const WAVE_SPEED_MIN_MULTIPLIER: float = 0.7  # Minimum wave speed multiplier
const WAVE_SPEED_MAX_MULTIPLIER: float = 1.5  # Maximum wave speed multiplier
const WAVE_FOAM_FADE_MIN: float = 0.3  # Minimum foam fade value
const WAVE_FOAM_FADE_MAX: float = 1.0  # Maximum foam fade value
const WAVE_FOAM_ANIMATION_SPEED: float = 3.0  # Speed of foam animation

# === ORGANISM DEFAULTS === [INDIVIDUAL SCALING]
const DEFAULT_SPAWN_SCALE: float = 0.3  # Base spawn scale (each organism can override)
const DEFAULT_COLLECTION_VALUE: int = 10  # Default points when collected
const OUTLINE_WIDTH: float = 4.0  # 2x from 2.0 - Highlight outline width

# === ORGANISM PHYSICS ===
const ORGANISM_SIZE_FACTOR_MIN: float = 0.5  # Minimum organism size factor for wave physics
const ORGANISM_SIZE_FACTOR_MAX: float = 1.5  # Maximum organism size factor for wave physics
const ORGANISM_FORCE_MULTIPLIER: float = 400.0  # 4x from 100.0 - Force multiplier for organism physics

# === COLLECTION ANIMATIONS ===
const COLLECTION_SCALE_TARGET: Vector2 = Vector2(1.5, 1.5)  # Target scale for collection animation
const COLLECTION_SCALE_TIME: float = 0.2  # Duration of scale animation
const COLLECTION_FADE_TIME: float = 0.3  # Duration of fade animation

# === TIMING ===
const FIRST_WAVE_DELAY: float = 3.0  # Seconds before first wave
const WAVE_INTERVAL: float = 8.0  # Seconds between waves
const GAME_TIMER_START_DELAY: float = 0.5  # Delay before game timer starts
const RIGID_BODY_UNFREEZE_TIME: float = 0.2  # Time to keep rigid body unfrozen after wave force

# === DEBUG THRESHOLDS ===
const POSITION_JUMP_THRESHOLD: float = 200.0  # 4x from 50.0 - Detect position jumps greater than this
const COLLISION_SIZE_CHANGE_THRESHOLD: float = 100.0  # Detect abnormal size changes
const DEBUG_CHECK_INTERVAL: int = 120  # Frames between debug checks

# === WAVE STATE MACHINE ===
enum WavePhase {
	CALM,       # No wave activity - waiting for next wave
	TRAVELING,  # Wave moving toward shore
	SURGING,    # Wave running up beach
	PAUSING,    # Wave paused at apex
	RETREATING  # Wave pulling back to ocean
}

# === SCORING MULTIPLIERS ===
const UNCOMMON_MULTIPLIER: float = 1.5
const RARE_MULTIPLIER: float = 2.0
const LEGENDARY_MULTIPLIER: float = 3.0
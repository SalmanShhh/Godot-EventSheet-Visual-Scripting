class_name ObjectPoolingDemo
extends Node2D
## [b]Object Pooling[/b] - a fountain throws about a hundred and twenty sparks a second, and each spark lives a little over a second. Press Space to switch pooling on and off and watch the strip at the foot of the screen: with pooling on, the first second makes about a hundred and fifty sparks and every spark after that is one that expired a moment ago, so nodes made stops climbing; with pooling off, every spark is a new node that is freed when it expires, so nodes made climbs for as long as you watch. A reused spark is put back to a fresh one by its own reset function, which the pool calls on every spawn. In your own project the Object Pool pack is the ObjectPool autoload, so the rows read ObjectPool.spawn(); here it sits as a child node of the same name, so they read $ObjectPool.spawn(), and an expired spark is handed back with Retire, which returns it to the pool that made it wherever that pool sits and frees a spark that was built new.

# Nodes this sheet calls, declared once with their type.
@onready var object_pool: ObjectPoolAddon = $ObjectPool

## True while sparks come from the pool; false while every spark is a new node that is freed when it expires.
var pooling: bool = true
## Sparks asked for since pooling was last switched.
var sparks_spawned: int = 0
## Sparks that had to be built new since pooling was last switched; the rest were given out again.
var nodes_made: int = 0
## How many sparks the fountain throws on every physics frame.
@export_range(0, 10, 1) var spark_burst: int = 2
## Seconds the fountain has been sweeping, which is where along the floor it stands.
var fountain_time: float = 0.0

## The spark scene, used to build a new spark when pooling is off.
const SPARK_SCENE: PackedScene = preload("res://demo/showcase/object_pooling/spark.tscn")

func _ready() -> void:
	object_pool.create_pool("sparks", "res://demo/showcase/object_pooling/spark.tscn", 0)

func _physics_process(delta: float) -> void:
	fountain_time += delta
	$Fountain.position = Vector2(576.0 + sin(fountain_time) * 320.0, 540.0)
	for _i: int in spark_burst:
		spawn_spark()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"ui_accept"):
		pooling = not pooling
		sparks_spawned = 0
		nodes_made = 0
	$HUD/Info.text = "pooling %s    sparks spawned %d    nodes made %d    nodes reused %d    nodes in the game %d" % ["ON" if pooling else "OFF", sparks_spawned, nodes_made, sparks_spawned - nodes_made, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))]

# @ace_hidden
func spawn_spark() -> void:
	var spark: PoolSpark
	sparks_spawned += 1
	if pooling:
		# An empty stash is the one case where Spawn has to build a new node.
		if object_pool.free_count("sparks") == 0:
			nodes_made += 1
		spark = object_pool.spawn("sparks") as PoolSpark
	else:
		nodes_made += 1
		spark = SPARK_SCENE.instantiate() as PoolSpark
		add_child(spark)
	spark.position = $Fountain.position
	spark.drift = Vector2(randf_range(-140.0, 140.0), randf_range(-520.0, -300.0))
	# A pooled spark keeps its connections between lives, so connect only if it is not already.
	if not spark.expired.is_connected(retire_spark):
		spark.expired.connect(retire_spark)

# @ace_hidden
func retire_spark(spark: PoolSpark) -> void:
	EventForgePooledNodes.retire(spark)

# Godot EventSheets - the bundled editor translations cover the shipped vocabulary.
#
# The l10n sweep is the step a vocabulary wave forgets, because nothing breaks when it is skipped:
# EventSheetL10n.translate falls back to its English argument, so an untranslated verb looks fine in
# English and silently stays English in all eight bundled languages. This test is that gate.
#
# What it proves, in the order the failures actually happen:
#   1. LOCKSTEP. Every file under addons/eventsheet/translations/ carries the SAME keys in the SAME
#      order, and every language cell is filled (TEMPLATE.csv is the ready-to-fill copy, so its
#      second column is empty BY DESIGN and is checked for keys only).
#   2. COVERAGE. Every user-facing string of the value/text/table/resource wave - display name,
#      description, category, display template, parameter label, parameter description and dropdown
#      option label - is a key in every bundled language.
#   3. IT ACTUALLY TRANSLATES. A handful of strings are switched through and their exact translated
#      VALUE is pinned, so a catalog that loads but resolves nothing would still fail.
#   4. THE MENUS. Every label a context menu shows is keyed in every bundled language. A wave that
#      adds vocabulary usually remembers the CSVs; a wave that adds a MENU COMMAND forgets, and the
#      new item is then the one English line in an otherwise translated menu. Read straight out of
#      dock/context_menus.gd, so a command added tomorrow is swept the moment it is declared.
#
# Coverage is checked against the CSV KEY SET rather than against translate()'s output, and that is
# load-bearing: a translation may legitimately equal its English source ("JSON" in every language,
# "Code" in German and French), so a "translated != English" test would report those as missing and
# would ALSO pass for a key whose cell was filled with the English text by accident. Key presence is
# the question; the value pins in step 3 are what prove the catalog is live.
#
# Modules are loaded BY PATH, never by class_name, so the test does not depend on the editor class
# cache having been regenerated for a newly added module.
@tool
class_name VocabularyL10nTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TRANSLATIONS_DIR := "res://addons/eventsheet/translations"
const TEMPLATE_FILE := "TEMPLATE.csv"

## Where the vocabulary modules live, for the coverage ratchet below.
const MODULES_DIR := "res://addons/eventforge/registration/modules"

## The bundled languages. English is the source, so it is not a file.
const LOCALES: Array[String] = ["de", "es", "fr", "it", "ja", "ko", "ru", "zh_CN"]

## The l10n obligation - which modules and which verbs owe a translated word - is declared once,
## in the harvester that WRITES a missing row, and read here by the gate that FAILS on one. Two
## copies of that table would be two answers waiting to disagree.
const HARVEST := preload("res://tools/harvest_translations.gd")


## One pinned translation per language, chosen from a string whose translation differs from its
## English source in every one of them - the proof that the catalog is loaded and resolving.
const PINNED: Dictionary = {
	"de": "Freigabecode für",
	"es": "Código para compartir de",
	"fr": "Code de partage pour",
	"it": "Codice di condivisione per",
	"ja": "共有コード",
	"ko": "공유 코드",
	"ru": "Код обмена для",
	"zh_CN": "分享码",
}

const PINNED_KEY := "Share Code For"

## Where the editor's context-menu commands are declared, and the calls that declare one.
const CONTEXT_MENUS_FILE := "res://addons/eventsheet/editor/dock/context_menus.gd"
const MENU_ITEM_PATTERN := "add_(?:item|check_item|radio_check_item|submenu_item|icon_item)\\(\"([^\"]+)\""


static func run() -> bool:
	var passed: bool = true
	passed = _test_files_are_in_lockstep() and passed
	passed = _test_every_language_cell_is_filled() and passed
	passed = _test_wave_vocabulary_has_keys() and passed
	passed = _test_covered_modules_stay_covered() and passed
	passed = _test_menu_commands_have_keys() and passed
	passed = _test_the_catalog_actually_translates() and passed
	passed = _test_two_words_stay_two_words() and passed
	return passed


# ── 1. Lockstep ──


static func _test_files_are_in_lockstep() -> bool:
	var passed: bool = true
	var reference: PackedStringArray = _read_keys(TEMPLATE_FILE)
	passed = _check("TEMPLATE.csv carries keys", reference.is_empty(), false) and passed
	for locale: String in LOCALES:
		var keys: PackedStringArray = _read_keys("%s.csv" % locale)
		var drift: String = _first_difference(reference, keys)
		passed = _check("%s.csv matches TEMPLATE key for key" % locale, drift, "") and passed
	return passed


## The first place two key lists disagree, as a sentence - a diff a maintainer can act on, rather
## than a count that only says "something moved".
static func _first_difference(expected: PackedStringArray, actual: PackedStringArray) -> String:
	for index: int in mini(expected.size(), actual.size()):
		if expected[index] != actual[index]:
			return "row %d is \"%s\", expected \"%s\"" % [index + 1, actual[index], expected[index]]
	if expected.size() != actual.size():
		return "has %d keys, expected %d" % [actual.size(), expected.size()]
	return ""


# ── 2. No blank cells ──


static func _test_every_language_cell_is_filled() -> bool:
	var passed: bool = true
	for locale: String in LOCALES:
		var blanks: PackedStringArray = PackedStringArray()
		for row: PackedStringArray in _read_rows("%s.csv" % locale):
			if row.size() < 2 or row[1].strip_edges().is_empty():
				blanks.append(row[0])
		if not blanks.is_empty():
			print("  %s.csv blank cells: %s" % [locale, ", ".join(blanks)])
		passed = _check("%s.csv has no blank cells" % locale, blanks.size(), 0) and passed
	return passed


# ── 3. Coverage ──


static func _test_wave_vocabulary_has_keys() -> bool:
	var strings: PackedStringArray = _wave_strings()
	var passed: bool = _check("the wave contributes strings to sweep", strings.is_empty(), false)
	for locale: String in LOCALES:
		var keys: Dictionary = {}
		for key: String in _read_keys("%s.csv" % locale):
			keys[key] = true
		var missing: PackedStringArray = PackedStringArray()
		for text: String in strings:
			if not keys.has(text):
				missing.append(text)
		if not missing.is_empty():
			print("  %s.csv is missing %d wave strings, first: \"%s\"" % [locale, missing.size(), missing[0]])
		passed = _check("%s.csv covers the wave vocabulary" % locale, missing.size(), 0) and passed
	return passed


## Every string the obligation owes a user: the seven roles the editor routes through the
## translation layer, from the modules and verbs the shared obligation names. Ids, templates and
## hints never translate and are not collected.
static func _wave_strings() -> PackedStringArray:
	return HARVEST.owed_vocabulary().keys


## The seven roles ONE verb routes through the translation layer. The harvester that writes a
## missing row asks a descriptor the same question, so it is asked in one place.
static func _collect_descriptor(descriptor: ACEDescriptor, seen: Dictionary, strings: PackedStringArray) -> void:
	HARVEST.collect_descriptor(descriptor, seen, strings)


# ── 3b. The ratchet: a verb that is wholly keyed stays wholly keyed ──


## The VERBS whose every user-facing string - display name, description, category, reads-as sentence,
## parameter label, parameter description and dropdown option label - is a key today. MEASURED, not
## declared: the check below computes the set and compares it to this list, so the list can only ever
## be edited in two directions, and both are deliberate. A verb that gains an untranslated word drops
## OUT and fails here, naming itself; a verb that becomes covered turns up as a surplus and is added,
## which is the moment the wave list above stops needing hand-editing.
##
## THE UNIT IS THE VERB, NOT THE FILE IT LIVES IN, and that is what the length of this list buys. A
## ratchet held per module file says "these files are covered", which is a statement about where
## vocabulary happens to be STORED rather than about the vocabulary - so moving a covered verb into a
## file that is not covered failed this test with nothing translated and nothing untranslated, and a
## refactor stood blocked by a gate measuring the wrong thing. Held per verb, that move is silent,
## because the same verbs are covered on both sides of it. An `ace_id` is unique across every module
## (nothing else would register), so the id alone names the verb.
##
## The rest of the vocabulary is not keyed yet (about three in ten of the shipped sentences are), and
## a floor on a PERCENTAGE would not notice a new sentence added to a covered verb - which is the
## regression that actually happens. This is that gate.
const FULLY_KEYED_ACES: Array[String] = [
	"AcceptPlayer", "AddBottomPanel", "AddCommandPaletteCommand", "AddEditorWindow",
	"AddLayoutOnTop", "AddMissionTime", "AddNodeUndoable", "AddVisibilityFilter",
	"AimAtMovingTarget", "AimedFloorObject", "AimedFloorPoint", "AimedFloorSlope", "AlignLeft",
	"AlignRight", "AlignToGroundSlope3D", "AngleReflected", "AnimationIsBetween",
	"AnimationPastMarker", "ApplyPresetToNode", "ApplyRadialImpulse", "ArrayDeepDuplicate",
	"AsDuration", "AsPercentText", "AsSentenceText", "AsTitleText", "AskForAFileToOpen",
	"AskWhereToSave", "AtMostEvery", "AudioSetHearingDistance3D", "AudioSetLoudnessFalloff",
	"BeOnLayer", "BeOnLayer3D", "BossPhaseStarts", "BounceOffSurface", "BufferInput",
	"BufferInputFrames", "CallLater", "CanvasCentre", "CanvasX2D", "CanvasX3D", "CanvasY2D",
	"CanvasY3D", "CellDistance", "CellOfPoint", "CellsInLine", "CellsInRadius", "CellsInRectangle",
	"CenterInWidth", "CenterOfCell", "ClearMeasurements", "ClearPoke", "ClearTrail",
	"ClipboardHasImage", "ClipboardHasText", "ClipboardImage", "ClipboardTextIs", "CloneInto",
	"CollideWithLayer", "CollideWithLayer3D", "ConsumeBufferedInput", "ConsumeBufferedInputFrames",
	"ContainsAllOf", "ContainsAnyOf", "ContainsNoneOf", "CopyPlaceTo", "CopyResourceDeep",
	"CopyResourceShallow", "CopyShareCode", "CopyValuesFrom", "CountResourcesInFolder",
	"CreateAroundCircle", "CrowdCount", "CrowdIsDownToThisOne", "CursorIsOverObject3D",
	"DarknessFade", "DarknessSet", "DataAsset", "DataFolderIsValid", "DataFolderProblems",
	"DataIsOlderThanVersion", "Despawn", "DestroyAfterSeconds", "DestroyNow", "DictDeepDuplicate",
	"DoAfterFrame", "DrainMeter", "DuplicateNodeChoosing", "EditorIcon", "EditorMainScreen",
	"EditorPreference", "EventActionStrength", "EventIsAction", "EventIsActionPressed",
	"EventIsActionPressedRepeating", "EventIsActionReleased", "ExplainJsonProblem",
	"ExplainTableProblem", "FaceAlongVelocity", "FaceDirectionOfMovement", "FaceObject",
	"FaceTargetAtSpeed", "FacingAlong3D", "FadeOutAndDestroy", "FadeOutAndRetire",
	"FadeOutAndRetire3D", "FalloffAtDistance", "FileTable",
	"FillBlanksFrom", "FillMeter", "FirstToFinish", "ForEachCellInRadius", "ForEachChildOf",
	"ForEachLineInFile", "ForEachLineInText", "ForEachNodeThatCan", "ForEachPartInText",
	"ForEachResourceInFolder", "ForgetOnceFor", "ForgetRemembered", "FpsBelowFor", "FrameOverBudget",
	"FrameRecovered", "FrameRunningLong", "FreeFilePath", "GiveAuthority", "GoBackMode", "GoToMode",
	"GoToState", "HasAnimation", "HasBeenQuiet", "HasRemembered", "HasService", "HasSomething",
	"HideFromPlayer", "HierarchyAddChild", "HierarchyRemoveFromParent", "HostGame",
	"HostGameAdvanced", "InMode", "InState", "InStateForOver", "IsBehindCamera3D",
	"IsBehindObject3D", "IsCellInBounds", "IsConnected", "IsFlippedAnimatedSprite2D",
	"IsFlippedSprite2D", "IsFlippedSprite3D", "IsFlippedTextureRect", "IsHost",
	"IsInFrontOfObject3D", "IsInputBuffered", "IsInputBufferedFrames", "IsMirroredAnimatedSprite2D",
	"IsMirroredControl", "IsMirroredObject", "IsMirroredSpatial", "IsMirroredSprite2D",
	"IsMirroredSprite3D", "IsMirroredTextureRect", "IsNothing", "IsPointOnScreen",
	"IsSetToCollideWithLayer", "IsSetToCollideWithLayer3D", "IsStillHere", "IsTheFirstOneIn",
	"IsTheFirstOneIn3D", "IsToTheLeftOfObject3D", "IsToTheRightOfObject3D", "IsTouchingGroup",
	"IsTouchingGroup3D", "IsWithinAngleOfFacing3D", "IsWithinConeOf", "JitterValue", "JoinGame",
	"JoinGameAdvanced", "JustLanded", "JustLanded3D", "JustLeftTheGround", "JustLeftTheGround3D",
	"KeepBetween", "KeepUpright", "KickPlayer", "LaunchAngleForArc", "LayoutIsOnTop", "LeaveGame",
	"LeaveLayer", "LeaveLayer3D", "LightBrightness", "LightBrightness3D", "LightColour",
	"LightColour3D", "LightConeAngle", "LightFadeBrightness", "LightFadeBrightness3D", "LightIsLit",
	"LightIsLit3D", "LightIsShadows", "LightIsShadows3D", "LightLit3DOff", "LightLit3DOn",
	"LightLitOff", "LightLitOn", "LightReach", "LightReachOmni", "LightReachSpot",
	"LightSetBrightness", "LightSetBrightness3D", "LightSetColour", "LightSetColour3D",
	"LightSetConeAngle", "LightSetReach", "LightSetReachOmni", "LightSetReachSpot",
	"LightShadows3DOff", "LightShadows3DOn", "LightShadowsOff", "LightShadowsOn", "ListOr",
	"LoadImageFile", "LoadResourceOrDefault", "LoadSoundFile", "LogMeasurements", "LogTrail",
	"LookAtFlat", "LookAtSafeUp", "MakeNewCopy", "MakeNoise", "MarkerAngleToward",
	"MatchesPropertiesOf", "MaterialBlend", "MaterialBlending",
	"MaterialColour", "MaterialFadeColour",
	"MaterialFadeGlow", "MaterialFadeMetal", "MaterialFadeRoughness", "MaterialFadeSeeThrough",
	"MaterialGlow", "MaterialLayerOverSurface", "MaterialLightResponse",
	"MaterialMetal", "MaterialRemoveSurfaceLayer",
	"MaterialRoughness", "MaterialSeeThrough", "MaterialSetBlend", "MaterialSetBlending",
	"MaterialSetColour", "MaterialSetGlow", "MaterialSetLightResponse", "MaterialSetMetal",
	"MaterialSetRoughness",
	"MaterialSetSeeThrough", "MaterialSetSides", "MaterialSetSurfaceMaterial", "MaterialSetTexture",
	"MaterialSetTransparency",
	"MaterialSides", "MaterialSurfaceMaterial", "MaterialTexture", "MaterialTransparency",
	"MeasuredAverage", "MeasuredLast", "MeasuredPeak", "MenuAddItem",
	"MirrorPath", "MirrorTheView", "MirrorViewportView", "MissingFields", "MissionTimeLeft",
	"MouseFloorObject", "MouseFloorPoint", "MouseFloorSlope", "MoveChild", "MoveForwardOwnFacing",
	"MoveInDirection3D", "MoveTheWorldsWay", "MoveTowardEachTick", "MyPeerId", "NeighboursOfCell",
	"NextRawPacket", "NumberFromText", "NumberInText", "NumberOr", "ObjectUnderCursor2D",
	"OnAnimationEvent", "OnAnimationFrame", "OnAskCancelled", "OnAuthenticationFailed",
	"OnChildEnteredTree", "OnChildExitingTree", "OnCollisionWithGroup", "OnCollisionWithGroup3D",
	"OnControlInput", "OnDespawned", "OnEnteringMode", "OnEnteringState", "OnFileChosen",
	"OnFilesDropped", "OnFirstOverlap", "OnFirstOverlap3D", "OnJoinFailed", "OnJoinedTheHost",
	"OnLanded", "OnLanded3D", "OnLastOfCrowdDestroyed", "OnLastOverlapEnded", "OnLastOverlapEnded3D",
	"OnLeavingMode", "OnLeavingState", "OnLeftTheGround", "OnLeftTheGround3D", "OnMenuItemChosen",
	"OnNodeJoinsGroup", "OnNodeLeavesGroup", "OnNoiseHeard", "OnNotification:NOTIFICATION_PAUSED",
	"OnNotification:NOTIFICATION_PREDELETE", "OnNotification:NOTIFICATION_UNPAUSED",
	"OnNotification:NOTIFICATION_WM_CLOSE_REQUEST", "OnObjectClicked3D", "OnOverlapEndedWithGroup",
	"OnOverlapEndedWithGroup3D", "OnOverlapWithGroup", "OnOverlapWithGroup3D",
	"OnPlayerAuthenticating", "OnPlayerJoined", "OnPlayerLeft", "OnPreferencesChanged",
	"OnProjectFilesChanged", "OnRetired", "OnSomethingWentWrong", "OnSpawnSkipped", "OnSpawned",
	"OnStoppedCollidingWithGroup",
	"OnStoppedCollidingWithGroup3D", "OnSynchronized", "OnTheHostLeft", "OnUnpackFinished",
	"OnUnpackProgress", "OnUnpackRefused", "OnceThisFrame", "OnlyOncePerName", "OnlyOncePerNode",
	"OnlyOnceThisSceneLoad", "OpenScriptAtLine", "OpenUserDataFolder", "OwnerOf", "OwnsThisObject",
	"PackFolderIntoZip", "PartOf", "PauseAnimationFor", "PickNearestToCanvasPoint", "PlaceAlongPath",
	"PlaceAroundNode3D", "PlaceAtNode", "PlaceAtNode3D", "PlaceAtScreenEdge", "PlaceInFreeSpot",
	"PlaceInFreeSpot3D", "PlaceInsideBox3D",
	"PlaceInsideShape", "PlaceInsideSphere3D", "PlaceOnGround3D", "PlayThenQueue", "PlayerCount",
	"Players", "PointAtAngle", "Poke", "ProjectSetting", "ProjectToScreen3D", "PushGroupAwayFrom",
	"PushMode", "PushOutOfSurface", "QueueAnimation", "QueueFreeNode", "RandomDirection2D",
	"RandomDirection3D", "RandomPointAround", "RandomPointInBox", "RandomPointInCircle",
	"RandomPointInCone", "RandomPointInRectangle", "RandomPointInRing", "RandomPointInSphere",
	"RandomPointOnCircle", "RandomPointOnScreenEdge", "ReadTextFileOr", "RecordOr",
	"RegisterAsService", "RejectPlayer", "ReloadDataAsset", "RememberInTrail", "RememberValueAs",
	"RememberedValue", "RemoveBottomPanel", "RemoveChild", "RemoveLayoutOnTop", "RemoveNodeUndoable",
	"RenameField", "RenderingDrawInFrontOf", "RenderingIsOnScreen", "RenderingShowOnlyTo",
	"ReparentToChoosing", "ReportFailure", "ReportSuccess", "RescaleInto", "ResourceInFolder",
	"ResourcesInFolder", "RestoreValueInto", "Retire", "RetireAfterSeconds", "RetriesExhausted",
	"RetryAttemptNumber",
	"RetryUpTo",
	"Roll3D", "RotateClockwise3D", "RotatePitch3D", "RotateToward3DFacing", "SafeFileName",
	"SaveBranchAsSceneFile", "SaveDataAsset", "SaveProjectSettings", "SaveTrailCsv",
	"SceneFileIsDataOnly", "ScreenEdgePositionFor", "ScreenPointToWorld", "SendAuth",
	"SendMessageToEveryone", "SendMessageToHost", "SendMessageToPeer", "SendRawBytes", "Sender",
	"ServiceNamed", "SetAmbientLight", "SetAmbientOcclusion", "SetAnimationTime",
	"SetCameraDistance", "SetCompression", "SetFaceTheCamera", "SetFlippedAnimatedSprite2D",
	"SetFlippedSprite3D", "SetFlippedTextureRect", "SetFog", "SetFogColour", "SetFogDensity",
	"SetGlow", "SetGlowStrength", "SetIgnoreParentMovement", "SetInvulnerableFor", "SetLayerTint",
	"SetLightColour", "SetLightColour3D", "SetLightEnabled", "SetLightEnergy", "SetLightEnergy3D",
	"SetLightShadows", "SetMirroredControl", "SetMirroredLabel3D", "SetMirroredObject",
	"SetMirroredSpatial", "SetMirroredSprite2D", "SetMirroredSprite3D", "SetMirroredTextureRect",
	"SetPartOf", "SetPositionToObject3D", "SetProjectSetting", "SetPropertyDeferred",
	"SetPropertyUndoable", "SetRelay", "SetSceneOwner", "SetSeeThrough", "SetShadowsOff3D",
	"SetShadowsOn3D", "SetSkyRotation", "SetSurfaceRedraw", "SetTextTranslatedPattern",
	"SetTileFlipped", "SetVisibleRange", "SetWorldSize", "ShareCodeFor", "ShareCodeIsValid",
	"ShortenToFit", "ShortenToWholeWords", "ShowInFileManager", "ShowInProjectBar", "ShowToEveryone",
	"ShowToPlayer", "SlideAlongSurface", "SlopeSteeperThan", "SnapPointToGrid", "SnapPointToGrid3D",
	"Spawn", "SpawnCopyOfSelf", "SpawnCopyOfSelf3D", "SpawnFacingAndMoving",
	"SpawnFacingAndMoving3D", "SpawnFormation", "SpawnFormation3D", "SpawnInFreeSpot",
	"SpawnInFreeSpot3D", "SpawnIntoCrowd",
	"SpawnIntoCrowdOldestFirst",
	"SpawnIntoCrowdUnlessFull",
	"SpawnIsAlive", "SpawnNewCopy", "SpawnNewCopy3D", "SpawnNewCopyDeferred",
	"SpawnNewCopyDeferred3D", "SpawnReplicatedScene", "SpawnSceneAs", "SplitKeepingQuotes",
	"SpriteAnimationFrameIs", "StampDataVersion", "StartMeasuring", "StartMissionTimer", "StartedAs",
	"StopAcceptingPlayers", "StopCollidingWithLayer", "StopCollidingWithLayer3D", "StopCopyingPlace",
	"StopMeasuring", "StopRetrying", "StoreAsAngleAndDistance", "StrengthToward", "SwingOnHinge",
	"SwitchToWorkspace", "TableColumn", "TableFromFile", "TableFromText", "TableRowWhere",
	"TextAfter", "TextBefore", "TextBetween", "TextIsANumber", "TextIsAWholeNumber", "TextOr",
	"TheSpawned", "TileUnderCursor", "TimeToReach", "TrailAverage", "TrailHighest", "TrailLength",
	"TrailLowest", "TrailNewest", "TrailValues", "TranslatedTextFromPattern", "TurnAround",
	"TurnAroundPoint", "UnpackZipIntoFolder", "ValidateDataFolder", "ValueFromShareCode", "ValueOr",
	"VisibleWorldRect", "WaitBeforeNextTry", "WaitForAllOf", "WaitForAnyOf", "WaitSucceeded",
	"WaitTimedOut", "WaitUntil", "WasInState", "WasTheLastOneOut", "WasTheLastOneOut3D",
	"WatchDataFile", "WholeNumberFromText", "WithThousandsSeparators", "WorldFadeGlow",
	"WorldFogOff", "WorldFogOn", "WorldGlowOff", "WorldGlowOn", "WorldOwnEnvironment",
	"WorldPointToScreen", "WorldSetAmbientLight", "WorldSetFogThickness", "WrapAround",
	"WrapInsideView3D", "WriteFileTable", "WriteTextFileInFolder", "signal:data_file_changed",
	"signal:scene_spawned", "signal:verb_failed", "signal:verb_succeeded",
	# The camera wave: the rest of both camera shelves, the views, the layers with both parallax
	# nodes, and the eight rendering rows that wave added to a module older than it. Appended as a
	# group rather than merged into the sort above, so a wave landing beside this one adds its own
	# group without either rewrapping the other's lines. The assertion sorts, so order is free.
	"CameraDriftMargins", "CameraFollowTightly", "CameraSnapToTarget", "CameraSmoothTurns",
	"CameraViewRect", "IsInsideCameraView", "CameraFitLimits", "TiledArea", "CurrentCamera2D",
	"CameraLookAtOverSeconds", "CameraSwitchToPerspective", "CameraSwitchToOrthogonal",
	"CameraSetClipRange", "CurrentCamera3D", "CameraCursorOverSomething", "CameraPointUnderCursor",
	"ViewSetSize", "ViewShareWorld2D", "ViewShareWorld3D", "ViewSaveStill", "ViewMousePosition",
	"LayerStayFixedOnScreen", "LayerMoveWithTheWorld", "LayerDrawAbove", "LayerDrawBelow",
	"LayerOffset", "ParallaxScrollAt", "ParallaxRepeatEvery", "ParallaxDrift",
	"ParallaxScrollOffset", "ParallaxLayerScrollAt", "ParallaxLayerRepeatEvery",
	"RenderingRender3DAt", "RenderingUpscaleWith", "RenderingSmoothEdgesWith", "RenderingSetTaa",
	"RenderingScaleTheGame", "RenderingFitTheShape", "RenderingKeepPixelsSharp",
	"RenderingPixelSize", "RenderingRendererIs",
	# How two pictures meet: the two rows that make what a node draws the shape its children draw
	# inside. Its own group for the same reason the one above is - a wave appends rather than
	# rewrapping the lines of the wave beside it.
	"ClipMyChildren", "StopClipping",
	# The world's own look and the sky behind it, plus the one blend word a 2D light gained
	# beside them. They landed keyed and uncounted: the modules joined the l10n obligation and
	# the nine files were filled, and this ratchet was the one reader nobody told.
	"EnvSaturation", "EnvSetSaturation", "EnvFadeSaturation", "EnvContrast", "EnvSetContrast",
	"EnvFadeContrast", "EnvPictureBrightness", "EnvSetPictureBrightness", "EnvFadePictureBrightness",
	"EnvExposure", "EnvSetExposure", "EnvFadeExposure", "EnvGlowBloom", "EnvSetGlowBloom",
	"EnvFadeGlowBloom", "EnvGlowThreshold", "EnvSetGlowThreshold", "EnvGlowBlend", "EnvSetGlowBlend",
	"EnvSetGlowLevel", "EnvSetGlowLevels", "EnvColourGrade", "EnvSetColourGrade", "EnvToneMap",
	"EnvSetToneMap", "EnvBackdrop", "EnvSetBackdrop", "EnvFogFloor", "EnvSetFogFloor",
	"EnvFogFloorThickness", "EnvSetFogFloorThickness", "EnvFadeFogFloorThickness",
	"EnvAerialPerspective", "EnvSetAerialPerspective", "EnvFadeAerialPerspective", "EnvFogSunGlow",
	"EnvSetFogSunGlow", "EnvFadeFogSunGlow", "EnvVolumetricThickness", "EnvSetVolumetricThickness",
	"EnvFadeVolumetricThickness", "EnvVolumetricColour", "EnvSetVolumetricColour",
	"EnvFadeVolumetricColour", "EnvVolumetricReach", "EnvSetVolumetricReach",
	"EnvFadeVolumetricReach", "EnvVolumetricFogOn", "EnvVolumetricFogOff", "EnvIsVolumetricFog",
	"EnvReflectionsOn", "EnvReflectionsOff", "EnvIsReflections", "EnvIndirectLightOn",
	"EnvIndirectLightOff", "EnvIsIndirectLight", "EnvGlobalIlluminationOn",
	"EnvGlobalIlluminationOff", "EnvIsGlobalIllumination", "EnvTurnOcclusionOnAtQuality",
	"EnvTurnOcclusionOff", "EnvIsOcclusionOn", "EnvTurnIndirectLightOnAtQuality",
	"EnvTurnGlobalIlluminationOnAtQuality", "EnvTurnReflectionsOnAtQuality", "SkySkyTop",
	"SkySetSkyTop", "SkyFadeSkyTop", "SkySkyHorizon", "SkySetSkyHorizon", "SkyFadeSkyHorizon",
	"SkySkyGround", "SkySetSkyGround", "SkyFadeSkyGround", "SkySunSize", "SkySetSunSize",
	"SkyFadeSunSize", "SkySkyEnergy", "SkySetSkyEnergy", "SkyFadeSkyEnergy", "SkyUseProcedural",
	"SkyUsePanorama", "LightSetBlend", "LightBlend",
	# The lens, the look worn as a file, and the seven particle words on both emitters. Their
	# own group for the same reason every group above has one - a wave appends rather than
	# rewrapping the lines of the wave beside it.
	"CamSetExposure", "CamExposure", "CamFadeExposure", "CamAutoExposureOn", "CamAutoExposureOff",
	"CamIsAutoExposureOn", "CamSetExposureWorld", "CamExposureWorld", "CamFadeExposureWorld",
	"CamAutoExposureWorldOn", "CamAutoExposureWorldOff", "CamIsAutoExposureWorldOn", "CamFocusOn",
	"CamFocusEverywhere", "CamFocusDistance", "WorldUseLook", "WorldBlendToLook", "WorldCurrentLook",
	"OnWorldLookBlended", "ParticleSetGravity", "ParticleGravity", "ParticleFadeGravity",
	"ParticleSetSpread", "ParticleSpread", "ParticleFadeSpread", "ParticleSetSpeed", "ParticleSpeed",
	"ParticleSpeedMost", "ParticleFadeSpeed", "ParticleSetSize", "ParticleSize", "ParticleSizeMost",
	"ParticleFadeSize", "ParticleSetColour", "ParticleColour", "ParticleFadeColour",
	"ParticleSetLifetime", "ParticleLifetime", "ParticleFadeLifetime", "ParticleSetAmount",
	"ParticleAmount", "ParticleSetGravity3D", "ParticleGravity3D", "ParticleFadeGravity3D",
	"ParticleSetSpread3D", "ParticleSpread3D", "ParticleFadeSpread3D", "ParticleSetSpeed3D",
	"ParticleSpeed3D", "ParticleSpeedMost3D", "ParticleFadeSpeed3D", "ParticleSetSize3D",
	"ParticleSize3D", "ParticleSizeMost3D", "ParticleFadeSize3D", "ParticleSetColour3D",
	"ParticleColour3D", "ParticleFadeColour3D", "ParticleSetLifetime3D", "ParticleLifetime3D",
	"ParticleFadeLifetime3D", "ParticleSetAmount3D", "ParticleAmount3D",
	"PutOnCooldown", "IsOffCooldown", "CooldownSecondsLeft", "CooldownFraction",
	"ReduceCooldownBy", "ClearCooldown", "signal:cooldown_ready", "StartCountdown", "ScheduleAt",
	"CountdownSecondsLeft", "CountdownText", "CountdownIsRunning", "PauseCountdown",
	"ResumeCountdown", "signal:countdown_finished", "StartStopwatch", "RecordLap",
	"StopwatchSeconds", "StopwatchText", "LapSeconds", "LapText", "FirstTimeInSave",
	"HasSeenInSave", "MarkSeenInSave", "ForgetSeenInSave",
	# Who made this: the two rows that write the one owner key, the two that read the chain, and
	# the three that compare its far end.
	"Claim", "Disown", "ClaimedBy", "RootOwnerOf", "IsOwnedBy", "IsMine", "HitIsNotMyOwner",
]


static func _test_covered_modules_stay_covered() -> bool:
	var keys: Dictionary = {}
	for key: String in _read_keys(TEMPLATE_FILE):
		keys[key] = true
	var covered: Array[String] = []
	for path: String in _module_paths():
		var script: GDScript = load(path)
		if script == null:
			continue
		for descriptor: ACEDescriptor in script.get_descriptors():
			var seen: Dictionary = {}
			var strings: PackedStringArray = PackedStringArray()
			_collect_descriptor(descriptor, seen, strings)
			if strings.is_empty():
				continue
			var missing: int = 0
			for text: String in strings:
				if not keys.has(text):
					missing += 1
			if missing == 0:
				covered.append(descriptor.ace_id)
	covered.sort()
	var expected: Array[String] = FULLY_KEYED_ACES.duplicate()
	expected.sort()
	return _check("the verbs whose every word is keyed", covered, expected)


## Every vocabulary module, found by scanning rather than listed, so a module added tomorrow is
## measured the day it exists.
static func _module_paths() -> PackedStringArray:
	var paths: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(MODULES_DIR)
	if dir == null:
		return paths
	for file_name: String in dir.get_files():
		var name: String = file_name.trim_suffix(".remap")
		if name.ends_with(".gd"):
			paths.append("%s/%s" % [MODULES_DIR, name])
	paths.sort()
	return paths


# ── 4. Menu commands ──


static func _test_menu_commands_have_keys() -> bool:
	var labels: PackedStringArray = _menu_labels()
	var passed: bool = _check("context_menus.gd declares menu labels", labels.is_empty(), false)
	for locale: String in LOCALES:
		var keys: Dictionary = {}
		for key: String in _read_keys("%s.csv" % locale):
			keys[key] = true
		var missing: PackedStringArray = PackedStringArray()
		for label: String in labels:
			if not keys.has(label):
				missing.append(label)
		if not missing.is_empty():
			print("  %s.csv is missing %d menu label(s): %s" % [locale, missing.size(), ", ".join(missing)])
		passed = _check("%s.csv covers every context-menu command" % locale, missing.size(), 0) and passed
	return passed


## Every literal label the context menus put in front of a user. PopupMenu item text is
## auto-translated through the plugin's translation domain, so a label with no CSV key renders in
## English inside an otherwise translated menu - the failure this reads the source to prevent.
static func _menu_labels() -> PackedStringArray:
	var labels: PackedStringArray = PackedStringArray()
	var source: String = FileAccess.get_file_as_string(CONTEXT_MENUS_FILE)
	if source.is_empty():
		return labels
	var pattern: RegEx = RegEx.create_from_string(MENU_ITEM_PATTERN)
	if pattern == null:
		return labels
	for found: RegExMatch in pattern.search_all(source):
		var label: String = found.get_string(1)
		if not labels.has(label):
			labels.append(label)
	return labels


# ── 5. The catalog is live ──


static func _test_the_catalog_actually_translates() -> bool:
	var passed: bool = true
	EventSheetL10n.rescan()
	for locale: String in LOCALES:
		EventSheetL10n.set_locale(locale)
		passed = _check("%s translates a wave verb" % locale,
			EventSheetL10n.translate(PINNED_KEY), str(PINNED[locale])) and passed
	# The catalogs are static session state: leave English behind for the rest of the suite.
	EventSheetL10n.set_locale("en")
	EventSheetL10n.rescan()
	passed = _check("English is restored", EventSheetL10n.translate(PINNED_KEY), PINNED_KEY) and passed
	return passed


# ── Reading the CSVs ──


# ── 7. Two words stay two words ──


## TWO ROWS THAT MEAN DIFFERENT THINGS MUST NOT READ THE SAME. Lockstep and coverage both pass on a
## file where two neighbouring keys were handed one word, and that is the failure a translated picker
## actually shows: two rows on the same shelf, spelled identically, and no way to tell from the sheet
## which one is which. The English pairs below are the ones a locale has already collapsed once - a
## surface's blend against a sprite's blend mode, and a per-instance see-through AMOUNT against the
## material's transparency MODE.
##
## The pairs are English keys, so this reads as a question about the CATALOG rather than about any
## one language's taste: whatever two words a locale picks, they have to be two.
const DISTINCT_PAIRS: Array[Array] = [
	["Set Blend", "Set Blending"],
	["Set blend to {value}", "Set blending to {value}"],
	["Blend", "Blending"],
	["blend", "blending"]
]


static func _test_two_words_stay_two_words() -> bool:
	var passed: bool = true
	for locale: String in LOCALES:
		var cells: Dictionary = _cells_by_key("%s.csv" % locale)
		var collapsed: Array[String] = []
		for pair: Array in DISTINCT_PAIRS:
			var left: String = str(cells.get(pair[0], ""))
			var right: String = str(cells.get(pair[1], ""))
			if left == right:
				collapsed.append("%s = %s = \"%s\"" % [pair[0], pair[1], left])
		passed = _check("%s tells the pairs apart" % locale, collapsed,
			PackedStringArray() as Array[String]) and passed
	return passed


## The catalog as key -> translated cell, for a question that is about one row rather than the file.
static func _cells_by_key(file_name: String) -> Dictionary:
	var cells: Dictionary = {}
	for row: PackedStringArray in _read_rows(file_name):
		if row.size() > 1 and not cells.has(row[0]):
			cells[row[0]] = row[1]
	return cells


static func _read_rows(file_name: String) -> Array:
	var rows: Array = []
	var file: FileAccess = FileAccess.open("%s/%s" % [TRANSLATIONS_DIR, file_name], FileAccess.READ)
	if file == null:
		return rows
	var header: bool = true
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() == 1 and row[0].is_empty():
			continue
		if header:
			header = false
			continue
		rows.append(row)
	file.close()
	return rows


static func _read_keys(file_name: String) -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray()
	for row: PackedStringArray in _read_rows(file_name):
		keys.append(row[0])
	return keys


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("vocabulary_l10n_test", label, actual, expected)

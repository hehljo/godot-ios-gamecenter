#include "register_types.h"

#include <godot_cpp/godot.hpp>

using namespace godot;

// Apple builds register the GameKit singleton. Linux and Windows editor builds
// are deliberate empty stubs: without a library for the running OS, Godot
// prints "No GDExtension library found" on every start, which breaks headless
// test gates that treat engine errors as failures. GameCenterBridge then sees
// no singleton and answers with failure signals.
#ifdef __APPLE__
#include "game_center_kit.h"

#include <godot_cpp/classes/engine.hpp>

static GameCenterKit *gamecenter_singleton = nullptr;
#endif

void initialize_gamecenter_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
#ifdef __APPLE__
	GDREGISTER_CLASS(GameCenterKit);
	gamecenter_singleton = memnew(GameCenterKit);
	Engine::get_singleton()->register_singleton("GameCenterKit", gamecenter_singleton);
#endif
}

void uninitialize_gamecenter_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
#ifdef __APPLE__
	Engine::get_singleton()->unregister_singleton("GameCenterKit");
	memdelete(gamecenter_singleton);
	gamecenter_singleton = nullptr;
#endif
}

extern "C" GDExtensionBool GDE_EXPORT gamecenter_library_init(
		GDExtensionInterfaceGetProcAddress p_get_proc_address,
		const GDExtensionClassLibraryPtr p_library,
		GDExtensionInitialization *r_initialization) {
	godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
	init_obj.register_initializer(initialize_gamecenter_module);
	init_obj.register_terminator(uninitialize_gamecenter_module);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return init_obj.init();
}

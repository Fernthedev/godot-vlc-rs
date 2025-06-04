#![feature(c_variadic)]
#![feature(stmt_expr_attributes)]
use godot::{classes::Engine, prelude::*};

pub use vlc::sys as vlc;


mod vlc_instance;
mod video_stream_vlc;

struct GodotVLCExtension;

#[gdextension]
unsafe impl ExtensionLibrary for GodotVLCExtension {
    fn on_level_init(level: InitLevel) {
        if level == InitLevel::Scene {
            Engine::singleton().register_singleton(
                "VLCInstance",
                &vlc_instance::VLCInstance::new_alloc()
            );
        }
    }

    fn on_level_deinit(level: InitLevel) {
        if level == InitLevel::Scene {
            let mut engine = Engine::singleton();
            let singleton_name = "VLCInstance";
            
            if let Some(singleton) = engine.get_singleton(singleton_name) {
                engine.unregister_singleton(singleton_name);
                singleton.free();
            } else {
                godot_error!("Singleton not found: {singleton_name}")
            }
        }
    }
}
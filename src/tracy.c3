module tracy;

const TRACY_ENABLE @builtin = 1;

enum PlotFormat
{
    NUMBER,
    MEMORY,
    PERCENTAGE,
    WATT
}

extern fn void ___tracy_set_thread_name(ZString name);

macro setThreadName(ZString name) { ___tracy_set_thread_name(name); }

struct ___Tracy_source_location_data
{
    ZString name;
    ZString function;
    ZString file;
    uint line;
    uint color;
}

struct ___Tracy_c_zone_context
{
    uint id;
    int active;
}

struct ___Tracy_gpu_time_data
{
    long gpuTime;
    ushort queryId;
    char context;
}

struct ___Tracy_gpu_zone_begin_data
{
    ulong srcloc;
    ushort queryId;
    char context;
}

struct ___Tracy_gpu_zone_begin_callstack_data
{
    ulong srcloc;
    int depth;
    ushort queryId;
    char context;
}

struct ___Tracy_gpu_zone_end_data
{
    ushort queryId;
    char context;
}

struct ___Tracy_gpu_new_context_data
{
    long gpuTime;
    float period;
    char context;
    char flags;
    char type;
}

struct ___Tracy_gpu_context_name_data
{
    char context;
    ZString name;
    ushort len;
}

struct ___Tracy_gpu_calibration_data
{
    long gpuTime;
    long cpuDelta;
    char context;
}

struct ___Tracy_gpu_time_sync_data
{
    long gpuTime;
    char context;
}

def __Tracy_lockable_context_data = void;

// Some containers don't support storing const types.
// This struct, as visible to user, is immutable, so treat it as if const was declared here.
def /*const*/ ZoneCtx = ___Tracy_c_zone_context;

def LockCtx = __Tracy_lockable_context_data*;

// #ifdef TRACY_MANUAL_LIFETIME
extern fn void ___tracy_startup_profiler() @if($defined(TRACY_MANUAL_LIFETIME));
extern fn void ___tracy_shutdown_profiler() @if($defined(TRACY_MANUAL_LIFETIME));
extern fn int ___tracy_profiler_started() @if($defined(TRACY_MANUAL_LIFETIME));

macro int isStarted()
{
    $if $defined(TRACY_MANUAL_LIFETIME):
        return ___tracy_profiler_started();
    $endif
    return 1;
}

extern fn ulong ___tracy_alloc_srcloc(uint line, ZString source, usz sourceSz, ZString function, usz functionSz, uint color);
extern fn ulong ___tracy_alloc_srcloc_name(uint line, ZString source, usz sourceSz, ZString function, usz functionSz, ZString name, usz nameSz, uint color);

extern fn ZoneCtx ___tracy_emit_zone_begin(___Tracy_source_location_data* srcloc, int active);
extern fn ZoneCtx ___tracy_emit_zone_begin_callstack(___Tracy_source_location_data* srcloc, int depth, int active);
extern fn ZoneCtx ___tracy_emit_zone_begin_alloc(ulong srcloc, int active);
extern fn ZoneCtx ___tracy_emit_zone_begin_alloc_callstack(ulong srcloc, int depth, int active);
extern fn void ___tracy_emit_zone_end(ZoneCtx ctx);
extern fn void ___tracy_emit_zone_text(ZoneCtx ctx, ZString txt, usz size);
extern fn void ___tracy_emit_zone_name(ZoneCtx ctx, ZString txt, usz size);
extern fn void ___tracy_emit_zone_color(ZoneCtx ctx, uint color);
extern fn void ___tracy_emit_zone_value(ZoneCtx ctx, ulong value);

extern fn void ___tracy_emit_gpu_zone_begin(___Tracy_gpu_zone_begin_data);
extern fn void ___tracy_emit_gpu_zone_begin_callstack(___Tracy_gpu_zone_begin_callstack_data);
extern fn void ___tracy_emit_gpu_zone_begin_alloc(___Tracy_gpu_zone_begin_data);
extern fn void ___tracy_emit_gpu_zone_begin_alloc_callstack(___Tracy_gpu_zone_begin_callstack_data);
extern fn void ___tracy_emit_gpu_zone_end(___Tracy_gpu_zone_end_data data);
extern fn void ___tracy_emit_gpu_time(___Tracy_gpu_time_data);
extern fn void ___tracy_emit_gpu_new_context(___Tracy_gpu_new_context_data);
extern fn void ___tracy_emit_gpu_context_name(___Tracy_gpu_context_name_data);
extern fn void ___tracy_emit_gpu_calibration(___Tracy_gpu_calibration_data);
extern fn void ___tracy_emit_gpu_time_sync(___Tracy_gpu_time_sync_data);

extern fn void ___tracy_emit_gpu_zone_begin_serial(___Tracy_gpu_zone_begin_data);
extern fn void ___tracy_emit_gpu_zone_begin_callstack_serial(___Tracy_gpu_zone_begin_callstack_data);
extern fn void ___tracy_emit_gpu_zone_begin_alloc_serial(___Tracy_gpu_zone_begin_data);
extern fn void ___tracy_emit_gpu_zone_begin_alloc_callstack_serial(___Tracy_gpu_zone_begin_callstack_data);
extern fn void ___tracy_emit_gpu_zone_end_serial(___Tracy_gpu_zone_end_data data);
extern fn void ___tracy_emit_gpu_time_serial(___Tracy_gpu_time_data);
extern fn void ___tracy_emit_gpu_new_context_serial(___Tracy_gpu_new_context_data);
extern fn void ___tracy_emit_gpu_context_name_serial(___Tracy_gpu_context_name_data);
extern fn void ___tracy_emit_gpu_calibration_serial(___Tracy_gpu_calibration_data);
extern fn void ___tracy_emit_gpu_time_sync_serial(___Tracy_gpu_time_sync_data);

extern fn int ___tracy_connected();

macro int isConnected()
{
    return ___tracy_connected();
}

macro ZoneCtx zone(int active = 1, ZString name = null, uint color = 0)
{
    ___Tracy_source_location_data source = { name, $$FUNC, $$FILEPATH, $$LINE, color };
    return ___tracy_emit_zone_begin(&source, active);
}
macro zoneEnd(ZoneCtx ctx)
{
    ___tracy_emit_zone_end(ctx);
}

macro zoneText(ZoneCtx ctx, ZString txt, usz size) { ___tracy_emit_zone_text(ctx, txt, size); }
macro zoneName(ZoneCtx ctx, ZString txt, usz size) { ___tracy_emit_zone_name(ctx, txt, size); }
macro zoneColor(ZoneCtx ctx, uint color)           { ___tracy_emit_zone_color(ctx, color);    }
macro zoneValue(ZoneCtx ctx, ulong value)          { ___tracy_emit_zone_value(ctx, value);    }


extern fn void ___tracy_emit_memory_alloc(void* ptr, usz size, int secure);
extern fn void ___tracy_emit_memory_alloc_callstack(void* ptr, usz size, int depth, int secure);
extern fn void ___tracy_emit_memory_free(void* ptr, int secure);
extern fn void ___tracy_emit_memory_free_callstack(void* ptr, int depth, int secure);
extern fn void ___tracy_emit_memory_alloc_named(void* ptr, usz size, int secure, ZString name);
extern fn void ___tracy_emit_memory_alloc_callstack_named(void* ptr, usz size, int depth, int secure, ZString name);
extern fn void ___tracy_emit_memory_free_named(void* ptr, int secure, ZString name);
extern fn void ___tracy_emit_memory_free_callstack_named(void* ptr, int depth, int secure, ZString name);
extern fn void ___tracy_emit_memory_discard(ZString name, int secure);
extern fn void ___tracy_emit_memory_discard_callstack(ZString name, int secure, int depth);

extern fn void ___tracy_emit_message(ZString txt, usz size, int callstack_depth);
extern fn void ___tracy_emit_messageL(ZString txt, int callstack_depth);
extern fn void ___tracy_emit_messageC(ZString txt, usz size, uint color, int callstack_depth);
extern fn void ___tracy_emit_messageLC(ZString txt, uint color, int callstack_depth);

macro message(ZString txt, usz size)
{
    ___tracy_emit_message(txt, size, TRACY_CALLSTACK);
}
macro messageL(ZString txt)
{
    ___tracy_emit_messageL(txt, TRACY_CALLSTACK);
}
macro messageC(ZString txt, usz size, uint color)
{
    ___tracy_emit_messageC(txt, size, color, TRACY_CALLSTACK);
}
macro messageLC(ZString txt, uint color)
{
    ___tracy_emit_messageLC(txt, color, TRACY_CALLSTACK);
}


extern fn void ___tracy_emit_frame_mark(ZString name);
extern fn void ___tracy_emit_frame_mark_start(ZString name);
extern fn void ___tracy_emit_frame_mark_end(ZString name);
extern fn void ___tracy_emit_frame_image(void* image, ushort w, ushort h, char offset, int flip);

macro frameMark()
{
    ___tracy_emit_frame_mark(null);
}
macro frameMarkNamed(ZString name)
{
    ___tracy_emit_frame_mark(name);
}
macro frameMarkStart(ZString name)
{
    ___tracy_emit_frame_mark_start(name);
}
macro frameMarkEnd(ZString name)
{
    ___tracy_emit_frame_mark_end(name);
}
macro frameMarkImage(void* image, ushort w, ushort h, char offset, int flip)
{
    ___tracy_emit_frame_mark_image(image, w, h, offset, flip);
}


extern fn void ___tracy_emit_plot(ZString name, double val);
extern fn void ___tracy_emit_plot_float(ZString name, float val);
extern fn void ___tracy_emit_plot_int(ZString name, long val);
extern fn void ___tracy_emit_plot_config(ZString name, int type, int step, int fill, uint color);
extern fn void ___tracy_emit_message_appinfo(ZString txt, usz size);

macro plot(ZString name, double val)
{
    ___tracy_emit_plot(name, val);
}
macro plotF(ZString name, float val)
{
    ___tracy_emit_plot_float(name, val);
}
macro plotI(ZString name, int val)
{
    ___tracy_emit_plot_int(name, val);
}
macro plotConfig(ZString name, int type, int step, int fill, uint color)
{
    ___tracy_emit_plot_config(name, type, step, fill, color);
}
macro appInfo(ZString txt, usz size)
{
    ___tracy_emit_message_appinfo(txt, size);
}


extern fn __Tracy_lockable_context_data* ___tracy_announce_lockable_ctx(___Tracy_source_location_data* srcloc);
extern fn void ___tracy_terminate_lockable_ctx(__Tracy_lockable_context_data* lockdata);
extern fn int ___tracy_before_lock_lockable_ctx(__Tracy_lockable_context_data* lockdata);
extern fn void ___tracy_after_lock_lockable_ctx(__Tracy_lockable_context_data* lockdata);
extern fn void ___tracy_after_unlock_lockable_ctx(__Tracy_lockable_context_data* lockdata);
extern fn void ___tracy_after_try_lock_lockable_ctx(__Tracy_lockable_context_data* lockdata, int acquired);
extern fn void ___tracy_mark_lockable_ctx(__Tracy_lockable_context_data* lockdata, ___Tracy_source_location_data* srcloc);
extern fn void ___tracy_custom_name_lockable_ctx(__Tracy_lockable_context_data* lockdata, ZString name, usz nameSz);

macro @lockAnnounce(#lock)
{
    ___Tracy_source_location_data source = { null, $$FUNC, $$FILEPATH, $$LINE, 0 };
    #lock = ___tracy_announce_lockable_ctx(&source);
}
macro lockTerminate(__Tracy_lockable_context_data* lock)
{
    ___tracy_terminate_lockable_ctx(lock);
}
macro beforeLock(__Tracy_lockable_context_data* lock)
{
    ___tracy_before_lock_lockable_ctx(lock);
}
macro afterLock(__Tracy_lockable_context_data* lock)
{
    ___tracy_after_lock_lockable_ctx(lock);
}
macro afterUnlock(__Tracy_lockable_context_data* lock)
{
    ___tracy_after_unlock_lockable_ctx(lock);
}
macro afterTryLock(__Tracy_lockable_context_data* lock)
{
    ___tracy_after_try_lock_lockable_ctx(lock);
}
macro lockMark(__Tracy_lockable_context_data* lock)
{
    ___Tracy_source_location_data source = { null, $$FUNC, $$FILEPATH, $$LINE, 0 };
    ___tracy_mark_lockable_ctx(lock, &source);
}
macro lockCustomName(__Tracy_lockable_context_data* lock, ZString name, usz nameSz)
{
    ___tracy_custom_name_lockable_ctx(lock, name, nameSz);
}

extern fn void ___tracy_fiber_enter(ZString fiber) @if($defined(TRACY_FIBERS));
extern fn void ___tracy_fiber_leave() @if($defined(TRACY_FIBERS));

macro fiberEnter(ZString fiber) @if($defined(TRACY_FIBERS))
{
    ___tracy_fiber_enter(fiber);
}
macro fiberLeave() @if($defined(TRACY_FIBERS))
{
    ___tracy_fiber_leave();
}


module tracy::mem;

import std::core::mem;

macro malloc(usz size, int secure = 0)
{
    void* ptr = core::mem::malloc(size);
    tracy::___tracy_emit_memory_alloc(ptr, size, secure);
    return ptr;
}
macro new($Type, int secure = 0)
{
    $Type* ptr = core::mem::new($Type);
    tracy::___tracy_emit_memory_alloc(ptr, $Type.sizeof, secure);
    return ptr;
}
macro new_array($Type, usz elements, int secure = 0)
{
    $Type[] ptr = core::mem::new_array($Type, elements);
    tracy::___tracy_emit_memory_alloc(ptr, elements * $Type.sizeof, secure);
    return ptr;
}
macro free(void* ptr, int secure = 0)
{
    core::mem::free(ptr);
    tracy::___tracy_emit_memory_free(ptr, secure);
}
macro memoryDiscard(ZString name, int secure = 0)
{
    tracy::___tracy_emit_memory_discard(name, secure);
}

macro alloc_named(usz size, int secure = 0, ZString name)
{
    void* ptr = core::mem::malloc(size);
    tracy::___tracy_emit_memory_alloc_named(ptr, size, secure, name);
    return ptr;
}
macro free_named(void* ptr, int secure = 0, ZString name)
{
    core::mem::free(ptr);
    tracy::___tracy_emit_memory_free_named(ptr, secure, name);
}

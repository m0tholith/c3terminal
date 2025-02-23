module remotery;


const RMT_ENABLED @if(!$defined(RMT_ENABLED)) @builtin = 1;

// Help performance of the server sending data to the client by marking this machine as little-endian 
const RMT_ASSUME_LITTLE_ENDIAN @if(!$defined(RMT_ASSUME_LITTLE_ENDIAN)) @builtin = 0;

// Used by the Celtoys TinyCRT library (not released yet)
const RMT_USE_TINYCRT @if(!$defined(RMT_USE_TINYCRT)) @builtin = 0;

// Assuming CUDA headers/libs are setup, allow CUDA profiling
const RMT_USE_CUDA @if(!$defined(RMT_USE_CUDA)) @builtin = 0;

// Assuming Direct3D 11 headers/libs are setup, allow D3D11 profiling
const RMT_USE_D3D11 @if(!$defined(RMT_USE_D3D11)) @builtin = 0;

// Allow D3D12 profiling
const RMT_USE_D3D12 @if(!$defined(RMT_USE_D3D12)) @builtin = 0;

// Allow OpenGL profiling
const RMT_USE_OPENGL @if(!$defined(RMT_USE_OPENGL)) @builtin = 1;

// Allow Metal profiling
const RMT_USE_METAL @if(!$defined(RMT_USE_METAL)) @builtin = 0;

// Allow Vulkan profiling
const RMT_USE_VULKAN @if(!$defined(RMT_USE_VULKAN)) @builtin = 0;

// Initially use POSIX thread names to name threads instead of Thread0, 1, ...
const RMT_USE_POSIX_THREADNAMES @if(!$defined(RMT_USE_POSIX_THREADNAMES)) @builtin = 0;

// How many times we spin data back and forth between CPU & GPU
// to calculate average RTT (Roundtrip Time). Cannot be 0.
// Affects OpenGL & D3D11
const RMT_GPU_CPU_SYNC_NUM_ITERATIONS @if(!$defined(RMT_GPU_CPU_SYNC_NUM_ITERATIONS)) @builtin = 16;

// Time in seconds between each resync to compensate for drifting between GPU & CPU timers,
// effects of power saving, etc. Resyncs can cause stutter, lag spikes, stalls.
// Set to 0 for never.
// Affects OpenGL & D3D11
const RMT_GPU_CPU_SYNC_SECONDS @if(!$defined(RMT_GPU_CPU_SYNC_SECONDS)) @builtin = 30;

// Whether we should automatically resync if we detect a timer disjoint (e.g.
// changed from AC power to battery, GPU is overheating, or throttling up/down
// due to laptop savings events). Set it to 0 to avoid resync in such events.
// Useful if for some odd reason a driver reports a lot of disjoints.
// Affects D3D11
const RMT_D3D11_RESYNC_ON_DISJOINT @if(!$defined(RMT_D3D11_RESYNC_ON_DISJOINT)) @builtin = 1;

// If RMT_USE_INTERNAL_HASH_FUNCTION is defined to 1, the internal hash function for strings is used.
// This is the default setting.
// If you set RMT_USE_INTERNAL_HASH_FUNCTION to 0, you must implement rmt_HashString32 yourself.
const RMT_USE_INTERNAL_HASH_FUNCTION @if(!$defined(RMT_USE_INTERNAL_HASH_FUNCTION)) @builtin = 1;

// If RMT_USE_LEGACY_ATOMICS is defined to 1, the implementation will use the legacy fallback atomic functions
// The default setting is 0
const RMT_USE_LEGACY_ATOMICS @if(!$defined(RMT_USE_LEGACY_ATOMICS)) @builtin = 0;

/*--------------------------------------------------------------------------------------------------------------------------------
   Compiler/Platform Detection and Preprocessor Utilities
---------------------------------------------------------------------------------------------------------------------------------*/


// Platform identification
const RMT_PLATFORM_WINDOWS @if(env::WIN32) @builtin = 1;
const RMT_PLATFORM_LINUX @if(env::LINUX || env::FREEBSD || env::OPENBSD) @builtin = 1;
const RMT_PLATFORM_MACOS @if(env::DARWIN) @builtin = 1;
const RMT_PLATFORM_POSIX @if(env::DARWIN || env::LINUX || env::FREEBSD || env::OPENBSD) @builtin = 1;

// Architecture identification
const RMT_ARCH_64BIT @if(env::ARCH_64_BIT) @builtin = 1;
const RMT_ARCH_32BIT @if(env::ARCH_32_BIT) @builtin = 1;

// Allows macros to be written that can work around the inability to do: #define(x) #ifdef x
// with the C preprocessor.
macro @ifdef_rmt_enabled(#t, #f = EMPTY_MACRO_SLOT) @local
{
    $if $defined(RMT_ENABLED) && RMT_ENABLED == 1:
        return #t;
    $endif
    return #f;
}
macro @ifdef_rmt_use_cuda(#t, #f = EMPTY_MACRO_SLOT) @local
{
    $if $defined(RMT_ENABLED) && RMT_ENABLED == 1:
        $if $defined(RMT_USE_CUDA) && RMT_USE_CUDA == 1:
            return #t;
        $endif
    $endif
    return #f;
}
macro @ifdef_rmt_use_d3d11(#t, #f = EMPTY_MACRO_SLOT) @local
{
    $if $defined(RMT_ENABLED) && RMT_ENABLED == 1:
        $if $defined(RMT_USE_D3D11) && RMT_USE_D3D11 == 1:
            return #t;
        $endif
    $endif
    return #f;
}
macro @ifdef_rmt_use_d3d12(#t, #f = EMPTY_MACRO_SLOT) @local
{
    $if $defined(RMT_ENABLED) && RMT_ENABLED == 1:
        $if $defined(RMT_USE_D3D12) && RMT_USE_D3D12 == 1:
            return #t;
        $endif
    $endif
    return #f;
}
macro @ifdef_rmt_use_opengl(#t, #f = EMPTY_MACRO_SLOT) @local
{
    $if $defined(RMT_ENABLED) && RMT_ENABLED == 1:
        $if $defined(RMT_USE_OPENGL) && RMT_USE_OPENGL == 1:
            return #t;
        $endif
    $endif
    return #f;
}
macro @ifdef_rmt_use_metal(#t, #f = EMPTY_MACRO_SLOT) @local
{
    $if $defined(RMT_ENABLED) && RMT_ENABLED == 1:
        $if $defined(RMT_USE_METAL) && RMT_USE_METAL == 1:
            return #t;
        $endif
    $endif
    return #f;
}
macro @ifdef_rmt_use_vulkan(#t, #f = EMPTY_MACRO_SLOT) @local
{
    $if $defined(RMT_ENABLED) && RMT_ENABLED == 1:
        $if $defined(RMT_USE_VULKAN) && RMT_USE_VULKAN == 1:
            return #t;
        $endif
    $endif
    return #f;
}


/*--------------------------------------------------------------------------------------------------------------------------------
   Types
--------------------------------------------------------------------------------------------------------------------------------*/

// Boolean
def RmtBool = uint;
const RmtBool RMT_TRUE  = 1;
const RmtBool RMT_FALSE = 0;

// Unsigned integer types
def RmtU8  = char;
def RmtU16 = ushort;
def RmtU32 = uint;
def RmtU64 = ulong;

// Signed integer types
def RmtS8 = ichar;
def RmtS16 = short;
def RmtS32 = int;
def RmtS64 = long;

// Float types
def RmtF32 = float;
def RmtF64 = double;

// Const, null-terminated string pointer
def RmtPStr = ZString;

// Opaque pointer for a sample graph tree
def RmtSampleTree = void;

// Opaque pointer to a node in the sample graph tree
def RmtSample = void;

// Handle to the main remotery instance
def Remotery = void;

enum RmtSampleType
{
    CPU,
    CUDA,
    D3D11,
    D3D12,
    OPENGL,
    METAL,
    VULKAN,
    COUNT,
}

// All possible error codes
enum RmtError
{
    NONE,
    RECURSIVE_SAMPLE,                 // Not an error but an internal message to calling code
    UNKNOWN,                          // An error with a message yet to be defined, only for internal error handling
    INVALID_INPUT,                    // An invalid input to a function call was provided
    RESOURCE_CREATE_FAIL,             // Creation of an internal resource failed
    RESOURCE_ACCESS_FAIL,             // Access of an internal resource failed
    TIMEOUT,                          // Internal system timeout

    // System errors
    MALLOC_FAIL,                      // Malloc call within remotery failed
    TLS_ALLOC_FAIL,                   // Attempt to allocate thread local storage failed
    VIRTUAL_MEMORY_BUFFER_FAIL,       // Failed to create a virtual memory mirror buffer
    CREATE_THREAD_FAIL,               // Failed to create a thread for the server
    OPEN_THREAD_HANDLE_FAIL,          // Failed to open a thread handle, given a thread id

    // Network TCP/IP socket errors
    SOCKET_INVALID_POLL,              // Poll attempt on an invalid socket
    SOCKET_SELECT_FAIL,               // Server failed to call select on socket
    SOCKET_POLL_ERRORS,               // Poll notified that the socket has errors
    SOCKET_SEND_FAIL,                 // Unrecoverable error occured while client/server tried to send data
    SOCKET_RECV_NO_DATA,              // No data available when attempting a receive
    SOCKET_RECV_TIMEOUT,              // Timed out trying to receive data
    SOCKET_RECV_FAILED,               // Unrecoverable error occured while client/server tried to receive data

    // WebSocket errors
    WEBSOCKET_HANDSHAKE_NOT_GET,      // WebSocket server handshake failed, not HTTP GET
    WEBSOCKET_HANDSHAKE_NO_VERSION,   // WebSocket server handshake failed, can't locate WebSocket version
    WEBSOCKET_HANDSHAKE_BAD_VERSION,  // WebSocket server handshake failed, unsupported WebSocket version
    WEBSOCKET_HANDSHAKE_NO_HOST,      // WebSocket server handshake failed, can't locate host
    WEBSOCKET_HANDSHAKE_BAD_HOST,     // WebSocket server handshake failed, host is not allowed to connect
    WEBSOCKET_HANDSHAKE_NO_KEY,       // WebSocket server handshake failed, can't locate WebSocket key
    WEBSOCKET_HANDSHAKE_BAD_KEY,      // WebSocket server handshake failed, WebSocket key is ill-formed
    WEBSOCKET_HANDSHAKE_STRING_FAIL,  // WebSocket server handshake failed, internal error, bad string code
    WEBSOCKET_DISCONNECTED,           // WebSocket server received a disconnect request and closed the socket
    WEBSOCKET_BAD_FRAME_HEADER,       // Couldn't parse WebSocket frame header
    WEBSOCKET_BAD_FRAME_HEADER_SIZE,  // Partially received wide frame header size
    WEBSOCKET_BAD_FRAME_HEADER_MASK,  // Partially received frame header data mask
    WEBSOCKET_RECEIVE_TIMEOUT,        // Timeout receiving frame header

    REMOTERY_NOT_CREATED,             // Remotery object has not been created
    SEND_ON_INCOMPLETE_PROFILE,       // An attempt was made to send an incomplete profile tree to the client

    // CUDA error messages
    CUDA_DEINITIALIZED,               // This indicates that the CUDA driver is in the process of shutting down
    CUDA_NOT_INITIALIZED,             // This indicates that the CUDA driver has not been initialized with cuInit() or that initialization has failed
    CUDA_INVALID_CONTEXT,             // This most frequently indicates that there is no context bound to the current thread
    CUDA_INVALID_VALUE,               // This indicates that one or more of the parameters passed to the API call is not within an acceptable range of values
    CUDA_INVALID_HANDLE,              // This indicates that a resource handle passed to the API call was not valid
    CUDA_OUT_OF_MEMORY,               // The API call failed because it was unable to allocate enough memory to perform the requested operation
    ERROR_NOT_READY,                  // This indicates that a resource handle passed to the API call was not valid

    // Direct3D 11 error messages
    D3D11_FAILED_TO_CREATE_QUERY,     // Failed to create query for sample

    // OpenGL error messages
    OPENGL_ERROR,                     // Generic OpenGL error, no need to expose detail since app will need an OpenGL error callback registered

    CUDA_UNKNOWN,
}

// Gets the last error message issued on the calling thread
extern fn RmtPStr getLastErrorMessage() @extern("rmt_GetLastErrorMessage");


/*--------------------------------------------------------------------------------------------------------------------------------
   Runtime Settings
--------------------------------------------------------------------------------------------------------------------------------*/


// Callback function pointer types
def RmtMallocPtr = fn void*(void* mm_context, uint size);
def RmtReallocPtr = fn void*(void* mm_context, void* ptr, uint size);
def RmtFreePtr = fn void(void* mm_context, void* ptr);
def RmtInputHandlerPtr = fn void(ZString text, void* context);
def RmtSampleTreeHandlerPtr = fn void(void* cbk_context, RmtSampleTree* sample_tree);
def RmtPropertyHandlerPtr = fn void(void* cbk_context, RmtProperty* root);

// Struture to fill in to modify Remotery default settings
struct RmtSettings
{
    // Which port to listen for incoming connections on
    RmtU16 port;

    // When this server exits it can leave the port open in TIME_WAIT state for a while. This forces
    // subsequent server bind attempts to fail when restarting. If you find restarts fail repeatedly
    // with bind attempts, set this to true to forcibly reuse the open port.
    RmtBool reuse_open_port;

    // Only allow connections on localhost?
    // For dev builds you may want to access your game from other devices but if
    // you distribute a game to your players with Remotery active, probably best
    // to limit connections to localhost.
    RmtBool  limit_connections_to_localhost;

    // Whether to enable runtime thread sampling that discovers which processors a thread is running
    // on. This will suspend and resume threads from outside repeatdly and inject code into each
    // thread that automatically instruments the processor.
    // Default: Enabled
    RmtBool enableThreadSampler;

    // How long to sleep between server updates, hopefully trying to give
    // a little CPU back to other threads.
    RmtU32 msSleepBetweenServerUpdates;

    // Size of the internal message queues Remotery uses
    // Will be rounded to page granularity of 64k
    RmtU32 messageQueueSizeInBytes;

    // If the user continuously pushes to the message queue, the server network
    // code won't get a chance to update unless there's an upper-limit on how
    // many messages can be consumed per loop.
    RmtU32 maxNbMessagesPerUpdate;

    // Callback pointers for memory allocation
    RmtMallocPtr malloc;
    RmtReallocPtr realloc;
    RmtFreePtr free;
    void* mm_context;

    // Callback pointer for receiving input from the Remotery console
    RmtInputHandlerPtr input_handler;

    // Callback pointer for traversing the sample tree graph
    RmtSampleTreeHandlerPtr sampletree_handler;
    void* sampletree_context;

    // Callback pointer for traversing the prpperty graph
    RmtPropertyHandlerPtr snapshot_callback;
    void* snapshot_context;

    // Context pointer that gets sent to Remotery console callback function
    void* input_handler_context;

    RmtPStr logPath;
}

// Retrieve and configure the global rmtSettings object; returns `rmtSettings*`.
// This can be done before or after Remotery is initialised, however some fields are only referenced on initialisation.
macro settings()
{
    return @ifdef_rmt_enabled(_rmt_Settings(), null);
}


/*--------------------------------------------------------------------------------------------------------------------------------
   Initialisation/Shutdown
--------------------------------------------------------------------------------------------------------------------------------*/


// Can call remotery functions on a null pointer
// TODO: Can embed extern "C" in these macros?

// Initialises Remotery and sets its internal global instance pointer.
// Parameter is `Remotery**`, returning you the pointer for further use.
macro createGlobalInstance(rmt)
{
    return @ifdef_rmt_enabled(_rmt_CreateGlobalInstance(rmt), RmtError.NONE);
}

// Shutsdown Remotery, requiring its pointer to be passed to ensure you are destroying the correct instance.
macro destroyGlobalInstance(rmt)
{
    @ifdef_rmt_enabled(_rmt_DestroyGlobalInstance(rmt));
}

// For use in the presence of DLLs/SOs if each of them are linking Remotery statically.
// If Remotery is hosted in its own DLL and linked dynamically then there is no need to use this.
// Otherwise, pass the result of `rmt_CreateGlobalInstance` from your main DLL to this in your other DLLs.
macro setGlobalInstance(rmt)
{
    @ifdef_rmt_enabled(_rmt_SetGlobalInstance(rmt));
}

// Get a pointer to the current global Remotery instance.
macro getGlobalInstance(rmt)
{
    @ifdef_rmt_enabled(_rmt_GetGlobalInstance(rmt));
}


/*--------------------------------------------------------------------------------------------------------------------------------
   CPU Sampling
--------------------------------------------------------------------------------------------------------------------------------*/


macro setCurrentThreadName(rmt)
{
    @ifdef_rmt_enabled(_rmt_SetCurrentThreadName(rmt));
}

macro logText(ZString text)
{
    @ifdef_rmt_enabled(_rmt_LogText(text));
}

macro beginCPUSample(ZString name, flags)
{
    uint hashVar = 0;
    @ifdef_rmt_enabled(_rmt_BeginCPUSample(name, flags, &hashVar));
}

macro beginCPUSampleDynamic(ZString name, flags)
{
    @ifdef_rmt_enabled(_rmt_BeginCPUSampleDynamic(name, flags, null));
}

macro endCPUSample()
{
    @ifdef_rmt_enabled(_rmt_EndCPUSample());
}

// Used for both CPU and GPU profiling
// Essential to call this every frame, ever since D3D12/Vulkan support was added
// D3D12/Vulkan Requirements: Don't sample any command lists that begin before this call and end after it
macro markFrame()
{
    return @ifdef_rmt_enabled(_rmt_MarkFrame(), RmtError.NONE);
}


/*--------------------------------------------------------------------------------------------------------------------------------
   GPU Sampling
--------------------------------------------------------------------------------------------------------------------------------*/


// Structure to fill in when binding CUDA to Remotery
struct RmtCUDABind
{
    // The main context that all driver functions apply before each call
    void* context;

    // Driver API function pointers that need to be pointed to
    // Untyped so that the CUDA headers are not required in this file
    // NOTE: These are named differently to the CUDA functions because the CUDA API has a habit of using
    // macros to point function calls to different versions, e.g. cuEventDestroy is a macro for
    // cuEventDestroy_v2.
    void* ctxSetCurrent;
    void* ctxGetCurrent;
    void* eventCreate;
    void* eventDestroy;
    void* eventRecord;
    void* eventQuery;
    void* eventElapsedTime;
}

// Call once after you've initialised CUDA to bind it to Remotery
macro bindCUDA(bind)
{
    @ifdef_rmt_use_cuda(_rmt_BindCUDA(bind));
}

// Mark the beginning of a CUDA sample on the specified asynchronous stream
macro beginCUDASample(ZString name, stream)
{
    uint hashVar = 0;
    @ifdef_rmt_use_cuda(_rmt_BeginCUDASample(name, &hashVar, stream));
}

// Mark the end of a CUDA sample on the specified asynchronous stream
macro endCUDASample(stream)
{
    @ifdef_rmt_use_cuda(_rmt_EndCUDASample(stream));
}


macro bindD3D11(device, context)
{
    @ifdef_rmt_use_d3d11(_rmt_BindD3D11(device, context));
}

macro unbindD3D11()
{
    @ifdef_rmt_use_d3d11(_rmt_UnbindD3D11());
}

macro beginD3D11Sample(ZString name)
{
    uint hashVar = 0;
    @ifdef_rmt_use_d3d11(_rmt_BeginD3D11Sample(name, &hashVar));
}

macro beginD3D11SampleDynamic(ZString name)
{
    @ifdef_rmt_use_d3d11(_rmt_BeginD3D11Sample(name, null));
}

macro endD3D11Sample()
{
    @ifdef_rmt_use_d3d11(_rmt_EndD3D11Sample());
}


struct RmtD3D12Bind
{
    // The main device shared by all threads
    void* device;

    // The queue command lists are executed on for profiling
    void* queue;
}

// Create a D3D12 binding for the given device/queue pair
macro bindD3D12(device, queue, out_bind)
{
    return @ifdef_rmt_use_d3d12(_rmt_BindD3D12(device, queue, out_bind), NULL);
}

macro unbindD3D12()
{
    @ifdef_rmt_use_d3d12(_rmt_UnbindD3D12());
}

macro beginD3D12Sample(bind, command_list, ZString name)
{
    uint hashVar = 0;
    @ifdef_rmt_use_d3d12(_rmt_BeginD3D12Sample(bind, command_list, name, &hashVar));
}

macro beginD3D12SampleDynamic(bind, command_list, ZString name)
{
    @ifdef_rmt_use_d3d12(_rmt_BeginD3D12Sample(bind, command_list, name, null));
}

macro endD3D12Sample()
{
    @ifdef_rmt_use_d3d12(_rmt_EndD3D12Sample());
}


macro bindOpenGL()
{
    @ifdef_rmt_use_opengl(_rmt_BindOpenGL());
}

macro unbindOpenGL()
{
    @ifdef_rmt_use_opengl(_rmt_UnbindOpenGL());
}

macro beginOpenGLSample(ZString name)
{
    uint hashVar = 0;
    @ifdef_rmt_use_opengl(_rmt_BeginOpenGLSample(name, &hashVar));
}

macro beginOpenGLSampleDynamic(ZString name)
{
    @ifdef_rmt_use_opengl(_rmt_BeginOpenGLSample(name, null));
}

macro endOpenGLSample()
{
    @ifdef_rmt_use_opengl(_rmt_EndOpenGLSample());
}


macro bindMetal(command_buffer)
{
    @ifdef_rmt_use_metal(_rmt_BindMetal(command_buffer));
}

macro unbindMetal()
{
    @ifdef_rmt_use_metal(_rmt_UnbindMetal());
}

macro beginMetalSample(ZString name)
{
    uint hashVar = 0;
    @ifdef_rmt_use_metal(_rmt_BeginMetalSample(name, &hashVar));
}

macro beginMetalSampleDynamic(ZString name)
{
    @ifdef_rmt_use_metal(_rmt_BeginMetalSample(name, null));
}

macro endMetalSample()
{
    @ifdef_rmt_use_metal(_rmt_EndMetalSample());
}


struct RmtVulkanFunctions
{
    // Function pointers to Vulkan functions
    // Untyped so that the Vulkan headers are not required in this file

    // Instance functions
    void* vkGetPhysicalDeviceProperties;

    // Device functions
    void* vkQueueSubmit;
    void* vkQueueWaitIdle;
    void* vkCreateQueryPool;
    void* vkDestroyQueryPool;
    void* vkResetQueryPool; // vkResetQueryPool (Vulkan 1.2+ with hostQueryReset) or vkResetQueryPoolEXT (VK_EXT_host_query_reset)
    void* vkGetQueryPoolResults;
    void* vkCmdWriteTimestamp;
    void* vkCreateSemaphore;
    void* vkDestroySemaphore;
    void* vkSignalSemaphore; // vkSignalSemaphore (Vulkan 1.2+ with timelineSemaphore) or vkSignalSemaphoreKHR (VK_KHR_timeline_semaphore)
    void* vkGetSemaphoreCounterValue; // vkGetSemaphoreCounterValue (Vulkan 1.2+ with timelineSemaphore) or vkGetSemaphoreCounterValueKHR (VK_KHR_timeline_semaphore)
    void* vkGetCalibratedTimestampsEXT; // vkGetCalibratedTimestampsKHR (VK_KHR_calibrated_timestamps) or vkGetCalibratedTimestampsEXT (VK_EXT_calibrated_timestamps)

}

struct RmtVulkanBind
{
    // The physical Vulkan device, of type VkPhysicalDevice
    void* physical_device;

    // The logical Vulkan device, of type VkDevice
    void* device;

    // The queue command buffers are executed on for profiling, of type VkQueue
    void* queue;
}

// Create a Vulkan binding for the given device/queue pair
macro bindVulkan(instance, physical_device, device, queue, funcs, out_bind)
{
    return @ifdef_rmt_use_vulkan(_rmt_BindVulkan(instance, physical_device, device, queue, funcs, out_bind), RMT_ERROR_NONE);
}

macro unbindVulkan(bind)
{
    @ifdef_rmt_use_vulkan(_rmt_UnbindVulkan(bind));
}

macro beginVulkanSample(bind, command_buffer, ZString name)
{
    uint hashVar = 0;
    @ifdef_rmt_use_vulkan(_rmt_BeginVulkanSample(bind, command_buffer, name, &hashVar));
}

macro beginVulkanSampleDynamic(bind, command_buffer, ZString name)
{
    @ifdef_rmt_use_vulkan(_rmt_BeginVulkanSample(bind, command_buffer, name, null));
}

macro endVulkanSample()
{
    @ifdef_rmt_use_vulkan(_rmt_EndVulkanSample());
}


/*--------------------------------------------------------------------------------------------------------------------------------
   Runtime Properties
--------------------------------------------------------------------------------------------------------------------------------*/


/* --- Public API --------------------------------------------------------------------------------------------------------------*/


// Flags that control property behaviour
enum RmtPropertyFlags
{
    NOFLAGS,

    // Reset property back to its default value on each new frame
    FRAMERESET,
}

// All possible property types that can be recorded and sent to the viewer
enum RmtPropertyType
{
    GROUP,
    BOOL,
    S32,
    U32,
    F32,
    S64,
    U64,
    F64,
}

// A property value as a union of all its possible types
union RmtPropertyValue
{
    RmtBool boolean;
    RmtS32  s32;
    RmtU32  u32;
    RmtF32  f32;
    RmtS64  s64;
    RmtU64  u64;
    RmtF64  f64;
}

// Definition of a property that should be stored globally
// Note:
//  Use the callback api and the rmt_PropertyGetxxx accessors to traverse this structure
struct RmtProperty
{
    // Gets set to RMT_TRUE after a property has been modified, when it gets initialised for the first time
    RmtBool initialised;

    // Runtime description
    RmtPropertyType type;
    RmtPropertyFlags flags;

    // Current value
    RmtPropertyValue value;

    // Last frame value to see if previous value needs to be updated
    RmtPropertyValue lastFrameValue;
    
    // Previous value only if it's different from the current value, and when it changed
    RmtPropertyValue prevValue;
    RmtU32 prevValueFrame;

    // Text description
    ZString name;
    ZString description;

    // Default value for Reset calls
    RmtPropertyValue defaultValue;

    // Parent link specifically placed after default value so that variadic macro can initialise it
    RmtProperty* parent;

    // Links within the property tree
    RmtProperty* firstChild;
    RmtProperty* lastChild;
    RmtProperty* nextSibling;

    // Hash for efficient sending of properties to the viewer
    RmtU32 nameHash;

    // Unique, persistent ID among all properties
    RmtU32 uniqueID;
}

// Define properties of different types at global scope:
//
//    * Never define properties in a header file that gets included multiple times.
//    * The property gets defined exactly as `name` in the global scope.
//    * `flag` is specified without the `RMT_PropertyFlags_` prefix.
//    * Property parents are optional and can be specified as the last parameter, referencing `&name`.
//
// NOTE FROM THE GUY WHO WROTE THIS BINDING: declaration is not possible in c3
macro @propertyDefine_Group(#name, desc, ...)                       
{
    return { RMT_FALSE, RmtPropertyType.GROUP, RmtPropertyFlags.NOFLAGS, { .boolean = 0 }, { .boolean = 0 }, 0, { .boolean = 0 }, $stringify(#name), desc, { .boolean = 0 }, $vasplat };
}
macro @propertyDefine_Bool (#name, default_value, flag, desc, ...)
{
    return { RMT_FALSE, RmtPropertyType.BOOL, flag, default_value, default_value, default_value, 0, $stringify(#name), desc, default_value, $vasplat };
}
macro @propertyDefine_S32(#name, default_value, flag, desc, ...)
{
    return { RMT_FALSE, RmtPropertyType.S32, flag, default_value, default_value, default_value, 0, $stringify(#name), desc, default_value, $vasplat };
}
macro @propertyDefine_U32(#name, default_value, flag, desc, ...)
{
    return { RMT_FALSE, RmtPropertyType.U32, flag, default_value, default_value, default_value, 0, $stringify(#name), desc, default_value, $vasplat };
}
macro @propertyDefine_F32(#name, default_value, flag, desc, ...)
{
    return { RMT_FALSE, RmtPropertyType.F32, flag, default_value, default_value, default_value, 0, $stringify(#name), desc, default_value, $vasplat };
}
macro @propertyDefine_S64(#name, default_value, flag, desc, ...)
{
    return { RMT_FALSE, RmtPropertyType.S64, flag, default_value, default_value, default_value, 0, $stringify(#name), desc, default_value, $vasplat };
}
macro @propertyDefine_U64(#name, default_value, flag, desc, ...)
{
    return { RMT_FALSE, RmtPropertyType.U64, flag, default_value, default_value, default_value, 0, $stringify(#name), desc, default_value, $vasplat };
}
macro @propertyDefine_F64(#name, default_value, flag, desc, ...)
{
    return { RMT_FALSE, RmtPropertyType.F64, flag, default_value, default_value, default_value, 0, $stringify(#name), desc, default_value, $vasplat };
}

// As properties need to be defined at global scope outside header files, use this to declare properties in header files to be
// modified in other translation units.
//
// If you don't want to include Remotery.h in your shared header you can forward declare the `rmtProperty` type and then forward
// declare the property name yourself.
// NOTE FROM GUY WHO PORTED THIS: this is not possible in c3
// #define rmt_PropertyExtern(name) extern rmtProperty name;

// Set properties to the given value
macro @propertySet_Bool(#name, set_value)
{
    #name.value.boolean = set_value;
    _rmt_PropertySetValue(&#name);
}
macro @propertySet_S32(#name, set_value)
{
    #name.value.s32 = set_value;
    _rmt_PropertySetValue(&#name);
}
macro @propertySet_U32(#name, set_value)
{
    #name.value.u32 = set_value;
    _rmt_PropertySetValue(&#name);
}
macro @propertySet_F32(#name, set_value)
{
    #name.value.f32 = set_value;
    _rmt_PropertySetValue(&#name);
}
macro @propertySet_S64(#name, set_value)
{
    #name.value.s64 = set_value;
    _rmt_PropertySetValue(&#name);
}
macro @propertySet_U64(#name, set_value)
{
    #name.value.u64 = set_value;
    _rmt_PropertySetValue(&#name);
}
macro @propertySet_F64(#name, set_value)
{
    #name.value.f64 = set_value;
    _rmt_PropertySetValue(&#name);
}

// Add the given value to properties
macro @propertyAdd_S32(#name, add_value)
{
    #name.value.s32 += add_value;
    RmtPropertyValue delta_value = { .s32 = add_value };
    _rmt_PropertyAddValue(&#name, delta_value);
}
macro @propertyAdd_U32(#name, add_value)
{
    #name.value.u32 += add_value;
    RmtPropertyValue delta_value = { .u32 = add_value };
    _rmt_PropertyAddValue(&#name, delta_value);
}
macro @propertyAdd_f32(#name, add_value)
{
    #name.value.f32 += add_value;
    RmtPropertyValue delta_value = { .f32 = add_value };
    _rmt_PropertyAddValue(&#name, delta_value);
}
macro @propertyAdd_S64(#name, add_value)
{
    #name.value.s64 += add_value;
    RmtPropertyValue delta_value = { .s64 = add_value };
    _rmt_PropertyAddValue(&#name, delta_value);
}
macro @propertyAdd_U64(#name, add_value)
{
    #name.value.f64 += add_value;
    RmtPropertyValue delta_value = { .f64 = add_value };
    _rmt_PropertyAddValue(&#name, delta_value);
}
macro @propertyAdd_F64(#name, add_value)
{
    #name.value.f64 += add_value;
    RmtPropertyValue delta_value = { .f64 = add_value };
    _rmt_PropertyAddValue(&#name, delta_value);
}

// Reset properties to their default value
macro @propertyReset(#name)
{
    #name.value = #name.defaultValue;
    _rmt_PropertySetValue(&#name);
}

// Send all properties and their values to the viewer and log to file
macro propertySnapshotAll() { _rmt_PropertySnapshotAll(); }

// Reset all RMT_PropertyFlags_FrameReset properties to their default value
macro propertyFrameResetAll() { _rmt_PropertyFrameResetAll(); }

/* --- Private Details ---------------------------------------------------------------------------------------------------------*/


extern fn void _rmt_PropertySetValue(RmtProperty* property) @local;
extern fn void _rmt_PropertyAddValue(RmtProperty* property, RmtPropertyValue add_value) @local;
extern fn RmtError _rmt_PropertySnapshotAll() @local;
extern fn void _rmt_PropertyFrameResetAll() @local;
extern fn RmtU32 _rmt_HashString32(ZString s, int len, RmtU32 seed) @local;


/*--------------------------------------------------------------------------------------------------------------------------------
   Sample Tree API for walking `rmtSampleTree` Objects in the Sample Tree Handler.
--------------------------------------------------------------------------------------------------------------------------------*/


distinct RmtSampleFlags = int;
// Default behaviour
const RmtSampleFlags RMTSF_NONE @builtin = 0;
// Search parent for same-named samples and merge timing instead of adding a new sample
const RmtSampleFlags RMTSF_AGGREGATE @builtin = 1;
// Merge sample with parent if it's the same sample
const RmtSampleFlags RMTSF_RECURSIVE @builtin = 2;
// Set this flag on any of your root samples so that Remotery will assert if it ends up *not* being the root sample.
// This will quickly allow you to detect Begin/End mismatches causing a sample tree imbalance.
const RmtSampleFlags RMTSF_ROOT @builtin = 4;
// Mainly for platforms other than Windows that don't support the thread sampler and can't detect stalling samples.
// Where you have a non-root sample that stays open indefinitely and never sends its contents to log/viewer.
// Send this sample to log/viewer when it closes.
// You can not have more than one sample open with this flag on the same thread at a time.
// This flag will be removed in a future version when all platforms support stalling samples.
const RmtSampleFlags RMTSF_SENDONCLOSE @builtin = 8;

// Struct to hold iterator info
struct RmtSampleIterator
{
// public
    RmtSample* sample;
// private
    RmtSample* initial;
}

macro iterateChildren(iter, sample)
{
    @ifdef_rmt_enabled(_rmt_IterateChildren(iter, sample));
}

macro iterateNext(iter)
{
    return @ifdef_rmt_enabled(_rmt_IterateNext(iter), RMT_FALSE);
}

macro sampleTreeGetThreadName(sample_tree)
{
    return @ifdef_rmt_enabled(_rmt_SampleTreeGetThreadName(sample_tree), null);
}

macro sampleTreeGetRootName(sample_tree)
{
    return @ifdef_rmt_enabled(_rmt_SampleTreeGetRootName(sample_tree), null);
}

// Should only called from within the sample tree callback,
// when the internal string lookup table is valid (i.e. on the main Remotery thread)
macro sampleGetName(sample)
{
    return @ifdef_rmt_enabled(_rmt_SampleGetName(sample), null);
}

macro sampleGetNameHash(sample)
{
    return @ifdef_rmt_enabled(_rmt_SampleGetNameHash(sample), 0U);
}

macro sampleGetCallCount(sample)
{
    return @ifdef_rmt_enabled(_rmt_SampleGetCallCount(sample), 0U);
}

macro sampleGetStart(sample)
{
    return @ifdef_rmt_enabled(_rmt_SampleGetStart(sample), 0U);
}

macro sampleGetTime(sample)
{
    return @ifdef_rmt_enabled(_rmt_SampleGetTime(sample), 0U);
}

macro sampleGetSelfTime(sample)
{
    return @ifdef_rmt_enabled(_rmt_SampleGetSelfTime(sample), 0U);
}

macro sampleGetColour(sample, r, g, b)
{
    @ifdef_rmt_enabled(_rmt_SampleGetColour(sample, r, g, b));
}

macro sampleGetType(sample)
{
    return @ifdef_rmt_enabled(_rmt_SampleGetType(sample), RmtSampleType.COUNT);
}


// Struct to hold iterator info
struct RmtPropertyIterator
{
// public
    RmtProperty* property;
// private
    RmtProperty* initial;
}

macro propertyIterateChildren(iter, property)
{
    @ifdef_rmt_enabled(_rmt_PropertyIterateChildren(iter, property));
}

macro rmt_PropertyIterateNext(iter)
{
    return @ifdef_rmt_enabled(_rmt_PropertyIterate(iter), RMT_FALSE);
}

// Should only called from within the property callback,
// when the internal string lookup table is valid (i.e. on the main Remotery thread)

macro propertyGetType(property)
{
    return @ifdef_rmt_enabled(_rmt_PropertyGetType(property), Rmt_PropertyType.COUNT);
}

macro propertyGetName(property)
{
    return @ifdef_rmt_enabled(_rmt_PropertyGetName(property), null);
}

macro propertyGetDescription(property)
{
    return @ifdef_rmt_enabled(_rmt_PropertyGetDescription(property), 0U);
}

macro propertyGetValue(property)
{
    return @ifdef_rmt_enabled(_rmt_PropertyGetValue(property), 0U);
}



/*--------------------------------------------------------------------------------------------------------------------------------
   C++ Public Interface Extensions
--------------------------------------------------------------------------------------------------------------------------------*/



/*--------------------------------------------------------------------------------------------------------------------------------
   Private Interface - don't directly call these
--------------------------------------------------------------------------------------------------------------------------------*/


extern fn RmtSettings* _rmt_Settings() @local;
extern fn RmtError _rmt_CreateGlobalInstance(Remotery** remotery) @local;
extern fn void _rmt_DestroyGlobalInstance(Remotery* remotery) @local;
extern fn void _rmt_SetGlobalInstance(Remotery* remotery) @local;
extern fn Remotery* _rmt_GetGlobalInstance() @local;
extern fn void _rmt_SetCurrentThreadName(RmtPStr thread_name) @local;
extern fn void _rmt_LogText(RmtPStr text) @local;
extern fn void _rmt_BeginCPUSample(RmtPStr name, RmtU32 flags, RmtU32* hash_cache) @local;
extern fn void _rmt_EndCPUSample() @local;
extern fn RmtError _rmt_MarkFrame() @local;

extern fn void _rmt_BindCUDA(RmtCUDABind* bind) @local;
extern fn void _rmt_BeginCUDASample(RmtPStr name, RmtU32* hash_cache, void* stream) @local;
extern fn void _rmt_EndCUDASample(void* stream) @local;

extern fn void _rmt_BindD3D11(void* device, void* context) @local;
extern fn void _rmt_UnbindD3D11() @local;
extern fn void _rmt_BeginD3D11Sample(RmtPStr name, RmtU32* hash_cache) @local;
extern fn void _rmt_EndD3D11Sample() @local;

extern fn RmtError _rmt_BindD3D12(void* device, void* queue, RmtD3D12Bind** out_bind) @local;
extern fn void _rmt_UnbindD3D12(RmtD3D12Bind* bind) @local;
extern fn void _rmt_BeginD3D12Sample(RmtD3D12Bind* bind, void* command_list, RmtPStr name, RmtU32* hash_cache) @local;
extern fn void _rmt_EndD3D12Sample() @local;

extern fn void _rmt_BindOpenGL() @local;
extern fn void _rmt_UnbindOpenGL() @local;
extern fn void _rmt_BeginOpenGLSample(RmtPStr name, RmtU32* hash_cache) @local;
extern fn void _rmt_EndOpenGLSample() @local;

extern fn RmtError _rmt_BeginMetalSample(RmtPStr name, RmtU32* hash_cache) @local;
extern fn void _rmt_EndMetalSample() @local;

extern fn RmtError _rmt_BindVulkan(void* instance, void* physical_device, void* device, void* queue, RmtVulkanFunctions* funcs, RmtVulkanBind** out_bind) @local;
extern fn void _rmt_UnbindVulkan(RmtVulkanBind* bind) @local;
extern fn void _rmt_BeginVulkanSample(RmtVulkanBind* bind, void* command_buffer, RmtPStr name, RmtU32* hash_cache) @local;
extern fn void _rmt_EndVulkanSample() @local;

// Sample iterator
extern fn void             _rmt_IterateChildren(RmtSampleIterator* iter, RmtSample* sample) @local;
extern fn RmtBool          _rmt_IterateNext(RmtSampleIterator* iter) @local;

// SampleTree accessors
extern fn ZString          _rmt_SampleTreeGetThreadName(RmtSampleTree* sample_tree) @local;
extern fn RmtSample*       _rmt_SampleTreeGetRootSample(RmtSampleTree* sample_tree) @local;

// Sample accessors
extern fn ZString          _rmt_SampleGetName(RmtSample* sample) @local;
extern fn RmtU32           _rmt_SampleGetNameHash(RmtSample* sample) @local;
extern fn RmtU32           _rmt_SampleGetCallCount(RmtSample* sample) @local;
extern fn RmtU64           _rmt_SampleGetStart(RmtSample* sample) @local;
extern fn RmtU64           _rmt_SampleGetTime(RmtSample* sample) @local;
extern fn RmtU64           _rmt_SampleGetSelfTime(RmtSample* sample) @local;
extern fn void             _rmt_SampleGetColour(RmtSample* sample, RmtU8* r, RmtU8* g, RmtU8* b) @local;
extern fn RmtSampleType    _rmt_SampleGetType(RmtSample* sample) @local;

// Property iterator
extern fn void             _rmt_PropertyIterateChildren(RmtPropertyIterator* iter, RmtProperty* property) @local;
extern fn RmtBool          _rmt_PropertyIterateNext(RmtPropertyIterator* iter) @local;

// Property accessors
extern fn RmtPropertyType  _rmt_PropertyGetType(RmtProperty* property) @local;
extern fn RmtU32           _rmt_PropertyGetNameHash(RmtProperty* property) @local;
extern fn ZString          _rmt_PropertyGetName(RmtProperty* property) @local;
extern fn ZString          _rmt_PropertyGetDescription(RmtProperty* property) @local;
extern fn RmtPropertyValue _rmt_PropertyGetValue(RmtProperty* property) @local;

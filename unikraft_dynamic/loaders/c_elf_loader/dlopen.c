#include <stdio.h>
#include <dlfcn.h>
#include <stdlib.h>

static void* openlib(const char* lib){
    void *handle = dlopen(lib, RTLD_LAZY|RTLD_GLOBAL);
    if (!handle) {
        fprintf(stderr, "Error opening library: %s\n", dlerror());
        return NULL;
    }

    // Clear any existing error
    dlerror();
    // Close the library
   return handle;
}

void search_symbol(void*handle, const char* symbol){
     // Get the address of the atoi function from the shared library
    int (*fct_pt)(const char *) = (int (*)(const char *))dlsym(handle, symbol);
    char *error = dlerror();
    if (error != NULL) {
        fprintf(stderr, "Error locating %s: %s\n", symbol, error);
        dlclose(handle);
        return;
    }

    printf("The result of %s %p\n",symbol, fct_pt);
}



int main() {
    const static int N = 48;
    // Open the libc shared library
    void* handles[N];
    const char *libraries[] = {
        "/lib/x86_64-linux-gnu/liblinuxuplat.so", 
        "/lib/x86_64-linux-gnu/libubsan.so",
        "/lib/x86_64-linux-gnu/libukconstructors.so", 
        "/lib/x86_64-linux-gnu/libukalloc.so", 
        "/lib/x86_64-linux-gnu/libukallocbbuddy.so", 
        "/lib/x86_64-linux-gnu/libposix_event.so",
        "/lib/x86_64-linux-gnu/libposix_time.so",
        "/lib/x86_64-linux-gnu/libposix_libdl.so",
        "/lib/x86_64-linux-gnu/libposix_socket.so",
        "/lib/x86_64-linux-gnu/libposix_process.so", 
        "/lib/x86_64-linux-gnu/libposix_time.so", 
        "/lib/x86_64-linux-gnu/libposix_user.so",
        "/lib/x86_64-linux-gnu/libposix_libdl.so",
        "/lib/x86_64-linux-gnu/libposix_environ.so", 
        "/lib/x86_64-linux-gnu/libposix_sysinfo.so", 
        "/lib/x86_64-linux-gnu/libuktimeconv.so",
        "/lib/x86_64-linux-gnu/libposix_futex.so",
        "/lib/x86_64-linux-gnu/libuksched.so",
        "/lib/x86_64-linux-gnu/libukschedcoop.so",
        "/lib/x86_64-linux-gnu/libramfs.so",
        "/lib/x86_64-linux-gnu/libvfscore.so",
        "/lib/x86_64-linux-gnu/libuksignal.so", 
        "/lib/x86_64-linux-gnu/libcontext.so", 
        "/lib/x86_64-linux-gnu/libukargparse.so", 
        "/lib/x86_64-linux-gnu/libuklock.so", 
        "/lib/x86_64-linux-gnu/libukboot_main.so",
        "/lib/x86_64-linux-gnu/libuksglist.so",
        "/lib/x86_64-linux-gnu/libuknetdev.so",
        "/lib/x86_64-linux-gnu/libukmpi.so", 
        "/lib/x86_64-linux-gnu/libukstreambuf.so", 
        "/lib/x86_64-linux-gnu/libukswrand.so", 
        "/lib/x86_64-linux-gnu/libukboot.so", 
        "/lib/x86_64-linux-gnu/libukmmap.so", 
        "/lib/x86_64-linux-gnu/libsyscall_shim.so" , 
        "/lib/x86_64-linux-gnu/libuksched.so" , 
        "/lib/x86_64-linux-gnu/libukdebug.so",
        "/lib/x86_64-linux-gnu/libukmusl.so",
        "/lib/x86_64-linux-gnu/libmuslglue.so",
        "/lib/x86_64-linux-gnu/libdevfs.so",
        "/lib/x86_64-linux-gnu/libukzlib.so",
        "/lib/x86_64-linux-gnu/liblwip.so",
        "/lib/x86_64-linux-gnu/libukcrypto.so",
        "/lib/x86_64-linux-gnu/libukssl.so",
        "/lib/x86_64-linux-gnu/libnginx.so",
        "/lib/x86_64-linux-gnu/libsqlite.so",
        "/lib/x86_64-linux-gnu/libtesthelloworld.so",
        "/lib/x86_64-linux-gnu/libtestsqlite.so",
        "/lib/x86_64-linux-gnu/libtestnginx.so"};
    
    for(int i = 0; i < N; i++){
        handles[i] = openlib(libraries[i]);
    }

    for (int i = 0; i < N; i++){
        if (handles[i]){
            search_symbol(handles[i], "_liblinuxuplat_start");
            break;
        }
    }

    for (int i = 0; i < N; i++){
        if (handles[i])
            dlclose(handles[i]);
    }

    return 0;
}


